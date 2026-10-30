//===- YulToLLVMIRTranslation.cpp - Translate Yul dialect to LLVM IR ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements a translation between the MLIR Yul dialect and LLVM IR.
//
//===----------------------------------------------------------------------===//

#include "mlir/Target/LLVMIR/Dialect/Yul/YulToLLVMIRTranslation.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/Dialect/Yul/EVMAddrSpace.h"
#include "mlir/Dialect/Yul/Yul.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Target/LLVMIR/LLVMTranslationInterface.h"
#include "mlir/Target/LLVMIR/ModuleTranslation.h"
#include "llvm/ADT/TypeSwitch.h"
#include "llvm/IR/DebugInfoMetadata.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InlineAsm.h"
#include "llvm/IR/IntrinsicsEVM.h"
#include <deque>

using namespace mlir;

namespace {

#include "mlir/Dialect/LLVMIR/LLVMConversionEnumsToLLVM.inc"

/// A block the translation of a region op branches to, created by the first
/// branch to it, with a phi per block argument.
struct Dest {
  SmallVector<Type> types;
  SmallVector<Location> locs;
  llvm::BasicBlock *block = nullptr;
  SmallVector<llvm::PHINode *> phis;
};

/// The blocks a `yul.break`, `yul.continue` or `yul.condition` in a loop
/// branches to; `step` is null for a loop without one.
struct LoopTargets {
  Dest *cond;
  Dest *body;
  Dest *step;
  Dest *exit;
};

/// Translates one `yul.object`: its globals, then its functions' declarations,
/// then their bodies.
class ObjectTranslation {
public:
  ObjectTranslation(yul::ObjectOp obj, llvm::IRBuilderBase &builder,
                    LLVM::ModuleTranslation &mt)
      : obj(obj), mt(mt), llvmModule(*mt.getLLVMModule()),
        ctx(llvmModule.getContext()), builder(builder),
        i256Ty(llvm::Type::getIntNTy(ctx, 256)) {}

  /// Translates the object into the LLVM module.
  LogicalResult translate();

private:
  /// Translates `op`, a global of the object's literal pool.
  LogicalResult translateGlobal(LLVM::GlobalOp op);
  /// Declares `func` with its linkage, attributes and subprogram.
  LogicalResult declare(yul::FuncOp func);
  /// Emits the body of the declared `func`.
  LogicalResult translateBody(yul::FuncOp func);

  /// Emits `block` at the end of the insertion block. A yield branches to
  /// `yieldDest`; `yieldBranch` is set to the branch.
  LogicalResult emitBlock(Block &block, Dest *yieldDest,
                          llvm::Instruction **yieldBranch = nullptr);
  /// Places the block of `dest` and emits `region` into it, the region's
  /// arguments being the block's phis.
  LogicalResult emitRegion(Dest &dest, Region &region, Dest *yieldDest,
                           llvm::Instruction **yieldBranch = nullptr);
  /// Emits `op`. `fallsThrough` is cleared when control does not reach the op
  /// after it.
  LogicalResult emitOp(Operation &op, bool &fallsThrough);
  /// Emits an if: a conditional branch to its regions, joined after it.
  LogicalResult emitIf(yul::IfOp op, bool &fallsThrough);
  /// Emits a switch on its argument over its case regions and the default.
  LogicalResult emitSwitch(yul::SwitchOp op, bool &fallsThrough);
  /// Emits a while, do-while or for loop.
  LogicalResult emitLoop(yul::LoopOpInterface op, bool &fallsThrough);
  /// Emits a scope, which `yul.leave_scope` exits.
  LogicalResult emitScope(yul::ScopeOp op, bool &fallsThrough);
  /// Emits a call, unpacking a multi-result call's struct.
  LogicalResult emitCall(yul::FuncCallOp op);
  /// Emits a return, packing several results into the function's struct.
  LogicalResult emitReturn(yul::FuncReturnOp op);
  /// Emits an LLVM dialect op through its own translation.
  LogicalResult emitLLVMOp(Operation &op);
  /// Emits an EVM builtin or a local-variable op.
  LogicalResult emitBuiltin(Operation &op, bool &fallsThrough);

  /// A destination whose block has phis of `types` at `locs`.
  Dest &newDest(TypeRange types, ArrayRef<Location> locs);
  /// A destination whose block has a phi per argument of `block`.
  Dest &newDest(Block &block);
  /// The block of `dest`, created with its phis by the first branch to it.
  llvm::BasicBlock *getBlock(Dest &dest);
  /// Places `block` in the function and moves the insertion point there.
  void place(llvm::BasicBlock *block);
  /// Adds `operands` to the phis of `dest` from the insertion block.
  void addIncoming(Dest &dest, ValueRange operands);
  /// Branches to `dest`, passing `operands`.
  llvm::BranchInst *branch(Dest &dest, ValueRange operands);
  /// Maps `results` to the phis of `dest` and continues emission there.
  void continueAt(Dest &dest, ValueRange results);

  /// The i1 of `cond`: the comparison `cond` extends, else `cond != 0`.
  llvm::Value *genCond(Value cond);

  /// The LLVM value of `value`.
  llvm::Value *lookup(Value value) { return mt.lookupValue(value); }
  /// The LLVM values of `values`.
  SmallVector<llvm::Value *> lookup(ValueRange values) {
    return mt.lookupValues(values);
  }
  /// Sets the debug location of the instructions that follow to `loc`.
  void setLoc(Location loc) {
    builder.SetCurrentDebugLocation(mt.translateLoc(loc, subprogram));
  }
  /// The pointer to `addr` in `addrSpace`.
  llvm::Value *genPtr(Value addr, evm::AddrSpace addrSpace) {
    return builder.CreateIntToPtr(lookup(addr),
                                  llvm::PointerType::get(ctx, addrSpace));
  }
  /// Calls intrinsic `id` with `args`, then each of `metadata` as an MDString.
  llvm::CallInst *genIntrCall(llvm::Intrinsic::ID id,
                              ArrayRef<llvm::Value *> args,
                              ArrayRef<StringRef> metadata = {});
  /// Loads an i256 from `ptr`.
  llvm::Value *genLoad(llvm::Value *ptr, unsigned alignment);
  /// Stores `val` to `ptr`.
  void genStore(llvm::Value *val, llvm::Value *ptr, unsigned alignment);
  /// The module's `llvm.loop.unroll.full` loop node.
  llvm::MDNode *getFullUnrollLoopMetadata();

  yul::ObjectOp obj;
  LLVM::ModuleTranslation &mt;
  llvm::Module &llvmModule;
  llvm::LLVMContext &ctx;
  llvm::IRBuilderBase &builder;
  llvm::IntegerType *i256Ty;
  llvm::MDNode *fullUnrollLoopMetadata = nullptr;
  DenseMap<StringRef, llvm::GlobalVariable *> globals;

  // Per function.
  llvm::Function *fn = nullptr;
  llvm::DISubprogram *subprogram = nullptr;
  std::deque<Dest> dests;
  SmallVector<LoopTargets> loops;
  SmallVector<Dest *> scopes;
};

} // namespace

//===----------------------------------------------------------------------===//
// Arithmetic
//===----------------------------------------------------------------------===//

llvm::Value *ObjectTranslation::genCond(Value cond) {
  llvm::Value *value = lookup(cond);
  // Branches on one comparison share its i1; an icmp per branch changes the
  // optimized code. An i1 Yul type would make this unnecessary.
  if (auto *zext = dyn_cast<llvm::ZExtInst>(value);
      zext && zext->getSrcTy()->isIntegerTy(1))
    return zext->getOperand(0);
  return builder.CreateICmpNE(value, llvm::ConstantInt::get(i256Ty, 0));
}

/// The instruction a binary Yul op translates to.
static std::optional<llvm::Instruction::BinaryOps>
getBinaryOpcode(Operation &op) {
  using llvm::Instruction;
  return TypeSwitch<Operation *, std::optional<Instruction::BinaryOps>>(&op)
      .Case([](yul::AddOp) { return Instruction::Add; })
      .Case([](yul::SubOp) { return Instruction::Sub; })
      .Case([](yul::MulOp) { return Instruction::Mul; })
      .Case([](yul::AndOp) { return Instruction::And; })
      .Case([](yul::OrOp) { return Instruction::Or; })
      .Case([](yul::XOrOp) { return Instruction::Xor; })
      .Case([](yul::ArithShlOp) { return Instruction::Shl; })
      .Case([](yul::ArithShrOp) { return Instruction::LShr; })
      .Case([](yul::ArithSarOp) { return Instruction::AShr; })
      .Case([](yul::ArithDivOp) { return Instruction::UDiv; })
      .Case([](yul::ArithSDivOp) { return Instruction::SDiv; })
      .Case([](yul::ArithModOp) { return Instruction::URem; })
      .Case([](yul::ArithSModOp) { return Instruction::SRem; })
      .Default([](Operation *) { return std::nullopt; });
}

/// The icmp predicate of `pred`.
static llvm::CmpInst::Predicate getPredicate(yul::CmpPredicate pred) {
  switch (pred) {
  case yul::CmpPredicate::eq:
    return llvm::CmpInst::ICMP_EQ;
  case yul::CmpPredicate::ne:
    return llvm::CmpInst::ICMP_NE;
  case yul::CmpPredicate::ult:
    return llvm::CmpInst::ICMP_ULT;
  case yul::CmpPredicate::ule:
    return llvm::CmpInst::ICMP_ULE;
  case yul::CmpPredicate::ugt:
    return llvm::CmpInst::ICMP_UGT;
  case yul::CmpPredicate::uge:
    return llvm::CmpInst::ICMP_UGE;
  case yul::CmpPredicate::slt:
    return llvm::CmpInst::ICMP_SLT;
  case yul::CmpPredicate::sle:
    return llvm::CmpInst::ICMP_SLE;
  case yul::CmpPredicate::sgt:
    return llvm::CmpInst::ICMP_SGT;
  case yul::CmpPredicate::sge:
    return llvm::CmpInst::ICMP_SGE;
  }
  llvm_unreachable("Invalid Yul comparison predicate");
}

//===----------------------------------------------------------------------===//
// Control flow
//===----------------------------------------------------------------------===//

Dest &ObjectTranslation::newDest(TypeRange types, ArrayRef<Location> locs) {
  Dest &dest = dests.emplace_back();
  dest.types.assign(types.begin(), types.end());
  dest.locs.assign(locs.begin(), locs.end());
  return dest;
}

Dest &ObjectTranslation::newDest(Block &block) {
  SmallVector<Location> locs;
  for (BlockArgument arg : block.getArguments())
    locs.push_back(arg.getLoc());
  return newDest(block.getArgumentTypes(), locs);
}

llvm::BasicBlock *ObjectTranslation::getBlock(Dest &dest) {
  if (dest.block)
    return dest.block;
  dest.block = llvm::BasicBlock::Create(ctx);
  for (auto [type, loc] : llvm::zip(dest.types, dest.locs)) {
    auto *phi = llvm::PHINode::Create(mt.convertType(type), 2, "", dest.block);
    phi->setDebugLoc(mt.translateLoc(loc, subprogram));
    dest.phis.push_back(phi);
  }
  return dest.block;
}

void ObjectTranslation::place(llvm::BasicBlock *block) {
  block->insertInto(fn);
  builder.SetInsertPoint(block);
}

void ObjectTranslation::addIncoming(Dest &dest, ValueRange operands) {
  for (auto [phi, operand] : llvm::zip(dest.phis, operands))
    phi->addIncoming(lookup(operand), builder.GetInsertBlock());
}

llvm::BranchInst *ObjectTranslation::branch(Dest &dest, ValueRange operands) {
  llvm::BranchInst *br = builder.CreateBr(getBlock(dest));
  addIncoming(dest, operands);
  return br;
}

void ObjectTranslation::continueAt(Dest &dest, ValueRange results) {
  place(dest.block);
  for (auto [result, phi] : llvm::zip(results, dest.phis))
    mt.mapValue(result, phi);
}

LogicalResult ObjectTranslation::emitBlock(Block &block, Dest *yieldDest,
                                           llvm::Instruction **yieldBranch) {
  for (Operation &op : block) {
    setLoc(op.getLoc());
    if (auto yield = dyn_cast<yul::YieldOp>(op)) {
      if (!yieldDest)
        return yield.emitError("expected a yul.condition");
      llvm::BranchInst *br = branch(*yieldDest, yield.getOperands());
      if (yieldBranch)
        *yieldBranch = br;
      return success();
    }
    bool fallsThrough = true;
    if (failed(emitOp(op, fallsThrough)))
      return failure();
    if (!fallsThrough)
      return success();
  }
  return success();
}

LogicalResult ObjectTranslation::emitRegion(Dest &dest, Region &region,
                                            Dest *yieldDest,
                                            llvm::Instruction **yieldBranch) {
  if (!llvm::hasSingleElement(region))
    return region.getParentOp()->emitError("expected single block regions");
  place(dest.block);
  Block &block = region.front();
  for (auto [arg, phi] : llvm::zip(block.getArguments(), dest.phis))
    mt.mapValue(arg, phi);
  return emitBlock(block, yieldDest, yieldBranch);
}

LogicalResult ObjectTranslation::emitIf(yul::IfOp op, bool &fallsThrough) {
  bool emptyElse = op.getElseRegion().empty();
  if (emptyElse && op->getNumResults() != 0)
    return op.emitError("expected an else region yielding the results");
  llvm::Value *cond = genCond(op.getCond());
  Dest &cont = newDest(op->getResultTypes(),
                       SmallVector<Location>(op->getNumResults(), op.getLoc()));
  Dest &thenDest = newDest({}, {});
  Dest &elseDest = emptyElse ? cont : newDest({}, {});
  builder.CreateCondBr(cond, getBlock(thenDest), getBlock(elseDest));

  if (failed(emitRegion(thenDest, op.getThenRegion(), &cont)))
    return failure();
  if (!emptyElse && failed(emitRegion(elseDest, op.getElseRegion(), &cont)))
    return failure();

  fallsThrough = cont.block;
  if (fallsThrough)
    continueAt(cont, op.getResults());
  return success();
}

LogicalResult ObjectTranslation::emitSwitch(yul::SwitchOp op,
                                            bool &fallsThrough) {
  Dest &cont = newDest(op->getResultTypes(),
                       SmallVector<Location>(op->getNumResults(), op.getLoc()));
  SmallVector<Dest *> caseDests;
  for (size_t i = 0, e = op.getCaseRegions().size(); i < e; ++i)
    caseDests.push_back(&newDest({}, {}));
  Dest &defaultDest = newDest({}, {});

  if (caseDests.empty()) {
    branch(defaultDest, {});
  } else {
    llvm::SwitchInst *switchInst = builder.CreateSwitch(
        lookup(op.getArg()), getBlock(defaultDest), caseDests.size());
    for (auto [val, dest] :
         llvm::zip(op.getCases().getValues<llvm::APInt>(), caseDests))
      switchInst->addCase(llvm::ConstantInt::get(ctx, val), getBlock(*dest));
  }

  for (auto [region, dest] : llvm::zip(op.getCaseRegions(), caseDests))
    if (failed(emitRegion(*dest, region, &cont)))
      return failure();
  if (failed(emitRegion(defaultDest, op.getDefaultRegion(), &cont)))
    return failure();

  fallsThrough = cont.block;
  if (fallsThrough)
    continueAt(cont, op.getResults());
  return success();
}

LogicalResult ObjectTranslation::emitLoop(yul::LoopOpInterface op,
                                          bool &fallsThrough) {
  Region *stepRegion = op.maybeGetStep();
  Dest &cond = newDest(op.getCond().front());
  Dest &body = newDest(op.getBody().front());
  Dest *step = stepRegion ? &newDest(stepRegion->front()) : nullptr;
  Dest &exit = newDest(op->getResultTypes(),
                       SmallVector<Location>(op->getNumResults(), op.getLoc()));
  Dest *next = step ? step : &cond;
  bool isDoWhile = &op.getEntry() == &op.getBody();
  branch(isDoWhile ? body : cond, op->getOperands());

  loops.push_back({&cond, &body, step, &exit});
  if (isDoWhile) {
    if (failed(emitRegion(body, op.getBody(), next)))
      return failure();
    if (cond.block && failed(emitRegion(cond, op.getCond(), nullptr)))
      return failure();
  } else {
    if (failed(emitRegion(cond, op.getCond(), nullptr)))
      return failure();
    if (body.block && failed(emitRegion(body, op.getBody(), next)))
      return failure();
    if (step && step->block) {
      llvm::Instruction *backEdge = nullptr;
      if (failed(emitRegion(*step, *stepRegion, &cond, &backEdge)))
        return failure();
      auto forOp = dyn_cast<yul::ForOp>(*op);
      if (backEdge && forOp && forOp.getFullUnroll())
        backEdge->setMetadata(llvm::LLVMContext::MD_loop,
                              getFullUnrollLoopMetadata());
    }
  }
  loops.pop_back();

  fallsThrough = exit.block;
  if (fallsThrough)
    continueAt(exit, op->getResults());
  return success();
}

LogicalResult ObjectTranslation::emitScope(yul::ScopeOp op,
                                           bool &fallsThrough) {
  Region &region = op.getBodyRegion();
  if (!llvm::hasSingleElement(region))
    return op.emitError("expected single block regions");
  Dest &exit = newDest({}, {});
  scopes.push_back(&exit);
  if (failed(emitBlock(region.front(), &exit)))
    return failure();
  scopes.pop_back();

  fallsThrough = exit.block;
  if (fallsThrough)
    continueAt(exit, {});
  return success();
}

llvm::MDNode *ObjectTranslation::getFullUnrollLoopMetadata() {
  if (!fullUnrollLoopMetadata) {
    auto self = llvm::MDNode::getTemporary(ctx, {});
    llvm::Metadata *full = llvm::MDNode::get(
        ctx, {llvm::MDString::get(ctx, "llvm.loop.unroll.full")});
    fullUnrollLoopMetadata = llvm::MDNode::get(ctx, {self.get(), full});
    fullUnrollLoopMetadata->replaceOperandWith(0, fullUnrollLoopMetadata);
  }
  return fullUnrollLoopMetadata;
}

//===----------------------------------------------------------------------===//
// Ops
//===----------------------------------------------------------------------===//

llvm::CallInst *ObjectTranslation::genIntrCall(llvm::Intrinsic::ID id,
                                               ArrayRef<llvm::Value *> args,
                                               ArrayRef<StringRef> metadata) {
  llvm::Function *callee =
      llvm::Intrinsic::getOrInsertDeclaration(&llvmModule, id);
  SmallVector<llvm::Value *> operands(args);
  for (StringRef name : metadata)
    operands.push_back(llvm::MetadataAsValue::get(
        ctx, llvm::MDNode::get(ctx, {llvm::MDString::get(ctx, name)})));
  return builder.CreateCall(callee, operands);
}

llvm::Value *ObjectTranslation::genLoad(llvm::Value *ptr, unsigned alignment) {
  llvm::LoadInst *load = builder.CreateLoad(i256Ty, ptr);
  load->setAlignment(llvm::Align(alignment));
  return load;
}

void ObjectTranslation::genStore(llvm::Value *val, llvm::Value *ptr,
                                 unsigned alignment) {
  builder.CreateStore(val, ptr)->setAlignment(llvm::Align(alignment));
}

LogicalResult ObjectTranslation::emitCall(yul::FuncCallOp op) {
  llvm::Function *callee = mt.lookupFunction(op.getCallee());
  if (!callee)
    return op.emitError("call to an undeclared function");
  llvm::CallInst *call = builder.CreateCall(callee, lookup(op.getOperands()));
  if (op->getNumResults() == 1) {
    mt.mapValue(op->getResult(0), call);
  } else {
    for (auto [i, result] : llvm::enumerate(op->getResults()))
      mt.mapValue(result, builder.CreateExtractValue(call, i));
  }
  return success();
}

LogicalResult ObjectTranslation::emitReturn(yul::FuncReturnOp op) {
  SmallVector<llvm::Value *> operands = lookup(op.getOperands());
  if (operands.empty()) {
    builder.CreateRetVoid();
  } else if (operands.size() == 1) {
    builder.CreateRet(operands.front());
  } else {
    llvm::Value *packed = llvm::PoisonValue::get(fn->getReturnType());
    for (auto [i, operand] : llvm::enumerate(operands))
      packed = builder.CreateInsertValue(packed, operand, i);
    builder.CreateRet(packed);
  }
  return success();
}

LogicalResult ObjectTranslation::emitLLVMOp(Operation &op) {
  if (auto addressOf = dyn_cast<LLVM::AddressOfOp>(op)) {
    llvm::GlobalVariable *global = globals.lookup(addressOf.getGlobalName());
    if (!global)
      return op.emitError("address of an unknown global");
    mt.mapValue(addressOf.getResult(), global);
    return success();
  }
  const auto *iface =
      op.getDialect()
          ->getRegisteredInterface<LLVMTranslationDialectInterface>();
  if (!iface || failed(iface->convertOperation(&op, builder, mt)))
    return op.emitError("LLVM Translation failed for operation: ")
           << op.getName();
  return success();
}

LogicalResult ObjectTranslation::emitOp(Operation &op, bool &fallsThrough) {
  if (isa<LLVM::LLVMDialect>(op.getDialect()))
    return emitLLVMOp(op);

  if (auto cast = dyn_cast<UnrealizedConversionCastOp>(op)) {
    if (cast->getNumOperands() != 1 || cast->getNumResults() != 1 ||
        !isa<LLVM::LLVMPointerType, yul::PtrType>(
            cast.getInputs()[0].getType()) ||
        !isa<LLVM::LLVMPointerType, yul::PtrType>(cast.getType(0)))
      return op.emitError("unsupported cast");
    mt.mapValue(cast.getResult(0), lookup(cast.getInputs()[0]));
    return success();
  }

  if (std::optional<llvm::Instruction::BinaryOps> opcode =
          getBinaryOpcode(op)) {
    mt.mapValue(op.getResult(0),
                builder.CreateBinOp(*opcode, lookup(op.getOperand(0)),
                                    lookup(op.getOperand(1))));
    return success();
  }

  return TypeSwitch<Operation *, LogicalResult>(&op)
      .Case([&](yul::ConstantOp op) {
        mt.mapValue(op, llvm::ConstantInt::get(ctx, op.getValue()));
        return success();
      })
      .Case([&](yul::NotOp op) {
        mt.mapValue(op, builder.CreateNot(lookup(op.getValue())));
        return success();
      })
      .Case([&](yul::CmpOp op) {
        llvm::Value *cmp =
            builder.CreateICmp(getPredicate(op.getPredicate()),
                               lookup(op.getLhs()), lookup(op.getRhs()));
        mt.mapValue(op, builder.CreateZExt(cmp, i256Ty));
        return success();
      })
      .Case([&](yul::ArithSelectOp op) {
        mt.mapValue(op, builder.CreateSelect(genCond(op.getCondition()),
                                             lookup(op.getTrueValue()),
                                             lookup(op.getFalseValue())));
        return success();
      })
      .Case([&](yul::IfOp op) { return emitIf(op, fallsThrough); })
      .Case([&](yul::SwitchOp op) { return emitSwitch(op, fallsThrough); })
      .Case([&](yul::LoopOpInterface op) { return emitLoop(op, fallsThrough); })
      .Case([&](yul::ScopeOp op) { return emitScope(op, fallsThrough); })
      .Case([&](yul::ConditionOp op) {
        LoopTargets &loop = loops.back();
        llvm::Value *cond = genCond(op.getCondition());
        builder.CreateCondBr(cond, getBlock(*loop.body), getBlock(*loop.exit));
        addIncoming(*loop.body, op.getArgs());
        addIncoming(*loop.exit, op.getArgs());
        fallsThrough = false;
        return success();
      })
      .Case([&](yul::BreakOp op) {
        branch(*loops.back().exit, op->getOperands());
        fallsThrough = false;
        return success();
      })
      .Case([&](yul::ContinueOp op) {
        LoopTargets &loop = loops.back();
        branch(loop.step ? *loop.step : *loop.cond, op->getOperands());
        fallsThrough = false;
        return success();
      })
      .Case([&](yul::LeaveScopeOp op) {
        branch(*scopes.back(), {});
        fallsThrough = false;
        return success();
      })
      .Case([&](yul::FuncCallOp op) { return emitCall(op); })
      .Case([&](yul::FuncReturnOp op) {
        fallsThrough = false;
        return emitReturn(op);
      })
      .Default([&](Operation *op) { return emitBuiltin(*op, fallsThrough); });
}

LogicalResult ObjectTranslation::emitBuiltin(Operation &op,
                                             bool &fallsThrough) {
  using namespace llvm::Intrinsic;
  auto heapPtr = [&](Value addr) { return genPtr(addr, evm::AddrSpace_Heap); };
  auto mapResult = [&](llvm::Value *val) {
    mt.mapValue(op.getResult(0), val);
    return success();
  };
  // A memcpy or memmove to the heap.
  auto genCopy = [&](ID id, Value dst, Value src, evm::AddrSpace srcAddrSpace,
                     Value size) {
    llvm::Value *dstPtr = heapPtr(dst);
    llvm::Value *srcPtr = genPtr(src, srcAddrSpace);
    llvm::Value *len = lookup(size);
    LLVM::detail::createIntrinsicCall(
        builder, id, {dstPtr, srcPtr, len, builder.getInt1(false)},
        {dstPtr->getType(), srcPtr->getType(), len->getType()});
    return success();
  };
  // The intrinsic of an op whose operands are the intrinsic's arguments.
  std::optional<ID> direct =
      TypeSwitch<Operation *, std::optional<ID>>(&op)
          .Case([](yul::DivOp) { return evm_div; })
          .Case([](yul::SDivOp) { return evm_sdiv; })
          .Case([](yul::ModOp) { return evm_mod; })
          .Case([](yul::SModOp) { return evm_smod; })
          .Case([](yul::ShlOp) { return evm_shl; })
          .Case([](yul::ShrOp) { return evm_shr; })
          .Case([](yul::SarOp) { return evm_sar; })
          .Case([](yul::ExpOp) { return evm_exp; })
          .Case([](yul::AddModOp) { return evm_addmod; })
          .Case([](yul::MulModOp) { return evm_mulmod; })
          .Case([](yul::SignExtendOp) { return evm_signextend; })
          .Case([](yul::ByteOp) { return evm_byte; })
          .Case([](yul::AddressOp) { return evm_address; })
          .Case([](yul::BalanceOp) { return evm_balance; })
          .Case([](yul::SelfBalanceOp) { return evm_selfbalance; })
          .Case([](yul::CallerOp) { return evm_caller; })
          .Case([](yul::GasOp) { return evm_gas; })
          .Case([](yul::ChainIdOp) { return evm_chainid; })
          .Case([](yul::BaseFeeOp) { return evm_basefee; })
          .Case([](yul::BlobBaseFeeOp) { return evm_blobbasefee; })
          .Case([](yul::OriginOp) { return evm_origin; })
          .Case([](yul::GasPriceOp) { return evm_gasprice; })
          .Case([](yul::BlockHashOp) { return evm_blockhash; })
          .Case([](yul::BlobHashOp) { return evm_blobhash; })
          .Case([](yul::CoinBaseOp) { return evm_coinbase; })
          .Case([](yul::TimeStampOp) { return evm_timestamp; })
          .Case([](yul::NumberOp) { return evm_number; })
          .Case([](yul::PrevrandaoOp) { return evm_difficulty; })
          .Case([](yul::GasLimitOp) { return evm_gaslimit; })
          .Case([](yul::CallValOp) { return evm_callvalue; })
          .Case([](yul::CallDataSizeOp) { return evm_calldatasize; })
          .Case([](yul::ReturnDataSizeOp) { return evm_returndatasize; })
          .Case([](yul::CodeSizeOp) { return evm_codesize; })
          .Case([](yul::ExtCodeSizeOp) { return evm_extcodesize; })
          .Case([](yul::ExtCodeHashOp) { return evm_extcodehash; })
          .Case([](yul::MSizeOp) { return evm_msize; })
          .Default([](Operation *) { return std::nullopt; });
  if (direct)
    return mapResult(genIntrCall(*direct, lookup(op.getOperands())));

  // A halting op; emitOp has taken the control-flow terminators.
  if (op.hasTrait<OpTrait::IsTerminator>()) {
    TypeSwitch<Operation *>(&op)
        .Case([&](yul::RevertOp op) {
          genIntrCall(evm_revert,
                      {heapPtr(op.getAddr()), lookup(op.getSize())});
        })
        .Case([&](yul::ReturnOp op) {
          genIntrCall(evm_return,
                      {heapPtr(op.getAddr()), lookup(op.getSize())});
        })
        .Case([&](yul::StopOp) { genIntrCall(evm_stop, {}); })
        .Case([&](yul::InvalidOp) { genIntrCall(evm_invalid, {}); })
        .Case([&](yul::SelfDestructOp op) {
          genIntrCall(evm_selfdestruct, {lookup(op.getAddr())});
        })
        // Follows a call that halts; there is no intrinsic to call.
        .Case([](yul::UnreachableOp) {})
        .Default([](Operation *) { llvm_unreachable("unknown halting op"); });
    builder.CreateUnreachable();
    fallsThrough = false;
    return success();
  }

  return TypeSwitch<Operation *, LogicalResult>(&op)
      .Case([&](yul::ClzOp op) {
        // clz(0) == 256, so zero is not poison.
        return mapResult(LLVM::detail::createIntrinsicCall(
            builder, ctlz, {lookup(op.getVal()), builder.getInt1(false)},
            {i256Ty}));
      })
      .Case([&](yul::Keccak256Op op) {
        return mapResult(genIntrCall(
            evm_sha3, {heapPtr(op.getAddr()), lookup(op.getSize())}));
      })
      .Case([&](yul::LogOp op) {
        SmallVector<llvm::Value *> args{heapPtr(op.getAddr()),
                                        lookup(op.getSize())};
        llvm::append_range(args, lookup(op.getTopics()));
        static constexpr ID logs[] = {evm_log0, evm_log1, evm_log2, evm_log3,
                                      evm_log4};
        if (op.getTopics().size() >= std::size(logs))
          return LogicalResult(op.emitError("invalid log op"));
        genIntrCall(logs[op.getTopics().size()], args);
        return success();
      })
      .Case([&](yul::CallDataLoadOp op) {
        return mapResult(genLoad(genPtr(op.getAddr(), evm::AddrSpace_CallData),
                                 evm::getAlignment(evm::AddrSpace_CallData)));
      })
      .Case([&](yul::CallDataCopyOp op) {
        return genCopy(llvm::Intrinsic::memcpy, op.getDst(), op.getSrc(),
                       evm::AddrSpace_CallData, op.getSize());
      })
      .Case([&](yul::ReturnDataCopyOp op) {
        return genCopy(llvm::Intrinsic::memcpy, op.getDst(), op.getSrc(),
                       evm::AddrSpace_ReturnData, op.getSize());
      })
      .Case([&](yul::CodeCopyOp op) {
        return genCopy(llvm::Intrinsic::memcpy, op.getDst(), op.getSrc(),
                       evm::AddrSpace_Code, op.getSize());
      })
      .Case([&](yul::MCopyOp op) {
        return genCopy(llvm::Intrinsic::memmove, op.getDst(), op.getSrc(),
                       evm::AddrSpace_Heap, op.getSize());
      })
      .Case([&](yul::ExtCodeCopyOp op) {
        llvm::Value *addr = lookup(op.getAddr());
        llvm::Value *dst = heapPtr(op.getDst());
        llvm::Value *src = genPtr(op.getSrc(), evm::AddrSpace_Code);
        genIntrCall(evm_extcodecopy, {addr, dst, src, lookup(op.getSize())});
        return success();
      })
      .Case([&](yul::SLoadOp op) {
        return mapResult(genLoad(genPtr(op.getAddr(), evm::AddrSpace_Storage),
                                 evm::getAlignment(evm::AddrSpace_Storage)));
      })
      .Case([&](yul::SStoreOp op) {
        llvm::Value *ptr = genPtr(op.getAddr(), evm::AddrSpace_Storage);
        genStore(lookup(op.getVal()), ptr,
                 evm::getAlignment(evm::AddrSpace_Storage));
        return success();
      })
      .Case([&](yul::TLoadOp op) {
        return mapResult(
            genLoad(genPtr(op.getAddr(), evm::AddrSpace_TransientStorage),
                    evm::getAlignment(evm::AddrSpace_TransientStorage)));
      })
      .Case([&](yul::TStoreOp op) {
        llvm::Value *ptr =
            genPtr(op.getAddr(), evm::AddrSpace_TransientStorage);
        genStore(lookup(op.getVal()), ptr,
                 evm::getAlignment(evm::AddrSpace_TransientStorage));
        return success();
      })
      .Case([&](yul::MLoadOp op) {
        return mapResult(genLoad(heapPtr(op.getAddr()),
                                 evm::getAlignment(evm::AddrSpace_Heap)));
      })
      .Case([&](yul::MStoreOp op) {
        llvm::Value *ptr = heapPtr(op.getAddr());
        genStore(lookup(op.getVal()), ptr,
                 evm::getAlignment(evm::AddrSpace_Heap));
        return success();
      })
      .Case([&](yul::MStore8Op op) {
        genIntrCall(evm_mstore8, {heapPtr(op.getAddr()), lookup(op.getVal())});
        return success();
      })
      .Case([&](yul::CreateOp op) {
        llvm::Value *addr = heapPtr(op.getAddr());
        return mapResult(genIntrCall(
            evm_create, {lookup(op.getVal()), addr, lookup(op.getSize())}));
      })
      .Case([&](yul::Create2Op op) {
        llvm::Value *addr = heapPtr(op.getAddr());
        return mapResult(genIntrCall(evm_create2, {lookup(op.getVal()), addr,
                                                   lookup(op.getSize()),
                                                   lookup(op.getSalt())}));
      })
      .Case([&](yul::CallOp op) {
        return mapResult(genIntrCall(
            evm_call, {lookup(op.getGas()), lookup(op.getAddress()),
                       lookup(op.getValue()), heapPtr(op.getInpOffset()),
                       lookup(op.getInpSize()), heapPtr(op.getOutOffset()),
                       lookup(op.getOutSize())}));
      })
      .Case([&](yul::CallCodeOp op) {
        return mapResult(genIntrCall(
            evm_callcode, {lookup(op.getGas()), lookup(op.getAddress()),
                           lookup(op.getValue()), heapPtr(op.getInpOffset()),
                           lookup(op.getInpSize()), heapPtr(op.getOutOffset()),
                           lookup(op.getOutSize())}));
      })
      .Case([&](yul::StaticCallOp op) {
        return mapResult(
            genIntrCall(evm_staticcall,
                        {lookup(op.getGas()), lookup(op.getAddress()),
                         heapPtr(op.getInpOffset()), lookup(op.getInpSize()),
                         heapPtr(op.getOutOffset()), lookup(op.getOutSize())}));
      })
      .Case([&](yul::DelegateCallOp op) {
        return mapResult(
            genIntrCall(evm_delegatecall,
                        {lookup(op.getGas()), lookup(op.getAddress()),
                         heapPtr(op.getInpOffset()), lookup(op.getInpSize()),
                         heapPtr(op.getOutOffset()), lookup(op.getOutSize())}));
      })
      .Case([&](yul::DataOffsetOp op) {
        return mapResult(genIntrCall(evm_dataoffset, {}, {op.getObj()}));
      })
      .Case([&](yul::DataSizeOp op) {
        return mapResult(genIntrCall(evm_datasize, {}, {op.getObj()}));
      })
      .Case([&](yul::LoadImmutableOp op) {
        return mapResult(genIntrCall(evm_loadimmutable, {}, {op.getName()}));
      })
      .Case([&](yul::LinkerSymbolOp op) {
        return mapResult(genIntrCall(evm_linkersymbol, {}, {op.getName()}));
      })
      .Case([&](yul::SetImmutableOp op) {
        genIntrCall(evm_setimmutable,
                    {lookup(op.getAddr()), lookup(op.getVal())},
                    {op.getName()});
        return success();
      })
      .Case([&](yul::MemGuardOp op) {
        // The size starts at zero; the driver rewrites it when the backend
        // asks for a spill area.
        llvmModule.addModuleFlag(llvm::Module::Error, "evm-memory-guard",
                                 op.getSize().getZExtValue());
        llvmModule.addModuleFlag(llvm::Module::Error, "evm-stack-region-size",
                                 0u);
        return mapResult(genIntrCall(evm_memoryguard, {}));
      })
      .Case([&](yul::AllocaOp op) {
        llvm::AllocaInst *alloca = builder.CreateAlloca(
            i256Ty, /*AddrSpace=*/0, llvm::ConstantInt::get(i256Ty, 1));
        alloca->setAlignment(llvm::Align(32));
        return mapResult(alloca);
      })
      .Case([&](yul::LoadOp op) {
        return mapResult(genLoad(lookup(op.getPtr()), 32));
      })
      .Case([&](yul::StoreOp op) {
        genStore(lookup(op.getVal()), lookup(op.getPtr()), 32);
        return success();
      })
      .Default([&](Operation *op) {
        return op->emitError("cannot be translated to LLVM IR");
      });
}

//===----------------------------------------------------------------------===//
// Object
//===----------------------------------------------------------------------===//

LogicalResult ObjectTranslation::translateGlobal(LLVM::GlobalOp op) {
  auto str = dyn_cast_or_null<StringAttr>(op.getValueOrNull());
  if (!str || !op.getInitializerRegion().empty() || op.getComdat() ||
      op.getDbgExprs() || op.getThreadLocal_() || op.getSection() ||
      op.getDsoLocal() || op.getExternallyInitialized() ||
      op.getVisibility_() != LLVM::Visibility::Default)
    return op.emitError("unsupported global");
  llvm::Constant *cst = llvm::ConstantDataArray::getString(ctx, str.getValue(),
                                                           /*AddNull=*/false);
  auto *var = new llvm::GlobalVariable(
      llvmModule, cst->getType(), op.getConstant(),
      convertLinkageToLLVM(op.getLinkage()), cst, op.getSymName(),
      /*InsertBefore=*/nullptr, llvm::GlobalValue::NotThreadLocal,
      op.getAddrSpace());
  if (op.getUnnamedAddr())
    var->setUnnamedAddr(convertUnnamedAddrToLLVM(*op.getUnnamedAddr()));
  if (std::optional<uint64_t> alignment = op.getAlignment())
    var->setAlignment(llvm::MaybeAlign(*alignment));
  globals[op.getSymName()] = var;
  return success();
}

LogicalResult ObjectTranslation::declare(yul::FuncOp func) {
  FunctionType type = func.getFunctionType();
  SmallVector<llvm::Type *> argTypes;
  for (Type argType : type.getInputs())
    argTypes.push_back(mt.convertType(argType));
  SmallVector<llvm::Type *> resultTypes;
  for (Type resultType : type.getResults())
    resultTypes.push_back(mt.convertType(resultType));
  llvm::Type *resultType = llvm::Type::getVoidTy(ctx);
  if (resultTypes.size() == 1)
    resultType = resultTypes.front();
  else if (resultTypes.size() > 1)
    resultType = llvm::StructType::get(ctx, resultTypes);

  llvm::FunctionCallee callee = llvmModule.getOrInsertFunction(
      func.getName(), llvm::FunctionType::get(resultType, argTypes, false));
  auto *llvmFunc = dyn_cast<llvm::Function>(callee.getCallee());
  if (!llvmFunc)
    return func.emitError("function redeclared");
  if (auto linkage = func->getAttrOfType<LLVM::LinkageAttr>("llvm.linkage"))
    llvmFunc->setLinkage(convertLinkageToLLVM(linkage.getLinkage()));
  else
    llvmFunc->setLinkage(func.isEntry() ? llvm::GlobalValue::ExternalLinkage
                                        : llvm::GlobalValue::PrivateLinkage);
  mt.mapFunction(func.getName(), llvmFunc);
  llvmFunc->addFnAttr(llvm::Attribute::NoFree);
  llvmFunc->addFnAttr(llvm::Attribute::NullPointerIsValid);
  if (func.isEntry())
    llvmFunc->addFnAttr("evm-entry-function");
  if (std::string features =
          sol::evmTargetFeatures(func->getParentOfType<ModuleOp>());
      !features.empty())
    llvmFunc->addFnAttr("target-features", features);
  if (auto spLoc =
          func.getLoc()->findInstanceOf<FusedLocWith<LLVM::DISubprogramAttr>>())
    llvmFunc->setSubprogram(
        cast<llvm::DISubprogram>(mt.translateDebugInfo(spLoc.getMetadata())));
  return success();
}

LogicalResult ObjectTranslation::translateBody(yul::FuncOp func) {
  fn = mt.lookupFunction(func.getName());
  subprogram = fn->getSubprogram();
  dests.clear();

  Region &body = func.getBody();
  if (!llvm::hasSingleElement(body))
    return func.emitError("expected a single block body");
  Block &entry = body.front();
  for (auto [arg, llvmArg] : llvm::zip(entry.getArguments(), fn->args()))
    mt.mapValue(arg, &llvmArg);
  place(llvm::BasicBlock::Create(ctx));
  return emitBlock(entry, nullptr);
}

LogicalResult ObjectTranslation::translate() {
  yul::FuncOp entry = obj.getEntryFn();
  if (!entry)
    return obj.emitError("expected an entry function");
  // Execution starts at the first function, which the backend checks.
  SmallVector<yul::FuncOp> funcs{entry};
  for (Operation &op : *obj.getBody()) {
    if (auto func = dyn_cast<yul::FuncOp>(op)) {
      if (func != entry)
        funcs.push_back(func);
      continue;
    }
    auto global = dyn_cast<LLVM::GlobalOp>(op);
    if (!global)
      return op.emitError("unexpected op in a yul.object");
    if (failed(translateGlobal(global)))
      return failure();
  }
  for (yul::FuncOp func : funcs)
    if (failed(declare(func)))
      return failure();
  for (yul::FuncOp func : funcs)
    if (failed(translateBody(func)))
      return failure();
  return success();
}

//===----------------------------------------------------------------------===//
// Registration
//===----------------------------------------------------------------------===//

namespace {

class YulDialectLLVMIRTranslationInterface
    : public LLVMTranslationDialectInterface {
public:
  using LLVMTranslationDialectInterface::LLVMTranslationDialectInterface;

  /// Translates `op`, a `yul.object`.
  LogicalResult
  convertOperation(Operation *op, llvm::IRBuilderBase &builder,
                   LLVM::ModuleTranslation &moduleTranslation) const final {
    auto obj = dyn_cast<yul::ObjectOp>(op);
    if (!obj)
      return op->emitError("expected a yul.object");
    return ObjectTranslation(obj, builder, moduleTranslation).translate();
  }
};

} // namespace

void mlir::registerYulDialectTranslation(DialectRegistry &registry) {
  // The module's sol.evm_version sets the functions' target features.
  registry.insert<sol::SolDialect, yul::YulDialect>();
  registry.addExtension(+[](MLIRContext *ctx, yul::YulDialect *dialect) {
    dialect->addInterfaces<YulDialectLLVMIRTranslationInterface>();
  });
}

void mlir::registerYulDialectTranslation(MLIRContext &context) {
  DialectRegistry registry;
  registerYulDialectTranslation(registry);
  context.appendDialectRegistry(registry);
}
