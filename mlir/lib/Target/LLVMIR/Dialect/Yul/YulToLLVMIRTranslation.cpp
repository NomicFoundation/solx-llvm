//===- YulToLLVMIRTranslation.cpp - Translate Yul dialect to LLVM IR ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements a translation between the MLIR Yul dialect and LLVM IR.
// A yul.object translates to the LLVM IR that the former convert-yul-to-std,
// the conversions to the LLVM dialect and the LLVM dialect translation
// produced for it: the same instructions in the same blocks, in the same
// order.
//
//===----------------------------------------------------------------------===//

#include "mlir/Target/LLVMIR/Dialect/Yul/YulToLLVMIRTranslation.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/Yul/EVMAddrSpace.h"
#include "mlir/Dialect/Yul/Yul.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Target/LLVMIR/LLVMTranslationInterface.h"
#include "mlir/Target/LLVMIR/ModuleTranslation.h"
#include "llvm/ADT/DepthFirstIterator.h"
#include "llvm/ADT/PostOrderIterator.h"
#include "llvm/ADT/TypeSwitch.h"
#include "llvm/Analysis/TargetFolder.h"
#include "llvm/IR/DebugInfoMetadata.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InlineAsm.h"
#include "llvm/IR/IntrinsicsEVM.h"
#include "llvm/Support/Allocator.h"
#include <deque>

using namespace mlir;

namespace {

#include "mlir/Dialect/LLVMIR/LLVMConversionEnumsToLLVM.inc"

enum class ArithKind : uint8_t {
  Opaque,
  Constant,
  AddI,
  SubI,
  MulI,
  AndI,
  OrI,
  XOrI,
  ShLI,
  ShRUI,
  ShRSI,
  DivUI,
  DivSI,
  RemUI,
  RemSI,
  CmpI,
  ExtUI,
  Select
};

/// An op of the arith IR convert-yul-to-std produced, or a value it uses.
///
/// The conversions after it fold that IR in two rounds. convert-func-to-llvm
/// leaves the arith ops unconverted but folds them, keeping only the folds to
/// an existing value: it cannot lower the constant another fold materializes.
/// convert-arith-to-llvm folds the IR that commit left. Within a round a fold
/// sees the IR as the previous round left it, since a replaced op stays until
/// the commit; a fold in place changes the op for good.
enum Round : unsigned { FuncToLLVMRound, ArithToLLVMRound };

struct ArithOp {
  ArithKind kind;
  /// The operands and predicate as each round sees them.
  std::array<ArithOp *, 3> operands[2] = {};
  llvm::CmpInst::Predicate predicate[2] = {};
  /// The value each round replaces the op with.
  ArithOp *replacement[2] = {};
  /// The LLVM value of an op neither round replaces, a constant or a value
  /// from outside the arith IR.
  llvm::Value *value = nullptr;
};

ArithOp *resolve(ArithOp *op, unsigned round) {
  while (op->replacement[round])
    op = op->replacement[round];
  return op;
}

const llvm::APInt *getConstant(ArithOp *op) {
  if (!op || op->kind != ArithKind::Constant)
    return nullptr;
  return &cast<llvm::ConstantInt>(op->value)->getValue();
}

/// The result of an arith op's fold: an existing value, a constant, or the op
/// changed in place.
struct FoldResult {
  ArithOp *value = nullptr;
  std::optional<llvm::APInt> constant;
  bool inPlace = false;

  static FoldResult none() { return {}; }
  static FoldResult of(ArithOp *value) { return {value, std::nullopt, false}; }
  static FoldResult of(llvm::APInt constant) {
    return {nullptr, std::move(constant), false};
  }
  static FoldResult changed() { return {nullptr, std::nullopt, true}; }
};

bool isCommutative(ArithKind kind) {
  return kind == ArithKind::AddI || kind == ArithKind::MulI ||
         kind == ArithKind::AndI || kind == ArithKind::OrI ||
         kind == ArithKind::XOrI;
}

bool isIdempotent(ArithKind kind) {
  return kind == ArithKind::AndI || kind == ArithKind::OrI;
}

/// Folds `op` in `round` as the folder of its arith op does.
FoldResult foldOp(ArithOp &op, unsigned round) {
  ArithOp *lhs = op.operands[round][0];
  ArithOp *rhs = op.operands[round][1];
  const llvm::APInt *lhsCst = getConstant(lhs);
  const llvm::APInt *rhsCst = getConstant(rhs);
  auto operand = [&](ArithOp *of, unsigned i) {
    return of->operands[round][i];
  };
  auto isAllOnesXOrOf = [&](ArithOp *xorOp, ArithOp *val) {
    if (xorOp->kind != ArithKind::XOrI || operand(xorOp, 0) != val)
      return false;
    const llvm::APInt *mask = getConstant(operand(xorOp, 1));
    return mask && mask->isAllOnes();
  };
  auto bothConstant = [&](auto compute) {
    if (lhsCst && rhsCst)
      return FoldResult::of(compute(*lhsCst, *rhsCst));
    return FoldResult::none();
  };

  switch (op.kind) {
  case ArithKind::AddI:
    if (rhsCst && rhsCst->isZero())
      return FoldResult::of(lhs);
    if (lhs->kind == ArithKind::SubI && rhs == operand(lhs, 1))
      return FoldResult::of(operand(lhs, 0));
    if (rhs->kind == ArithKind::SubI && lhs == operand(rhs, 1))
      return FoldResult::of(operand(rhs, 0));
    return bothConstant(
        [](const llvm::APInt &a, const llvm::APInt &b) { return a + b; });

  case ArithKind::SubI:
    if (lhs == rhs)
      return FoldResult::of(llvm::APInt::getZero(256));
    if (rhsCst && rhsCst->isZero())
      return FoldResult::of(lhs);
    if (lhs->kind == ArithKind::AddI) {
      if (rhs == operand(lhs, 1))
        return FoldResult::of(operand(lhs, 0));
      if (rhs == operand(lhs, 0))
        return FoldResult::of(operand(lhs, 1));
    }
    return bothConstant(
        [](const llvm::APInt &a, const llvm::APInt &b) { return a - b; });

  case ArithKind::MulI:
    if (rhsCst && rhsCst->isZero())
      return FoldResult::of(rhs);
    if (rhsCst && rhsCst->isOne())
      return FoldResult::of(lhs);
    return bothConstant(
        [](const llvm::APInt &a, const llvm::APInt &b) { return a * b; });

  case ArithKind::DivUI:
    if (rhsCst && rhsCst->isOne())
      return FoldResult::of(lhs);
    if (lhsCst && rhsCst && !rhsCst->isZero())
      return FoldResult::of(lhsCst->udiv(*rhsCst));
    return FoldResult::none();

  case ArithKind::DivSI:
    if (rhsCst && rhsCst->isOne())
      return FoldResult::of(lhs);
    if (lhsCst && rhsCst && !rhsCst->isZero()) {
      bool overflow = false;
      llvm::APInt quotient = lhsCst->sdiv_ov(*rhsCst, overflow);
      if (!overflow)
        return FoldResult::of(quotient);
    }
    return FoldResult::none();

  case ArithKind::RemUI:
  case ArithKind::RemSI:
    if (rhsCst && rhsCst->isOne())
      return FoldResult::of(llvm::APInt::getZero(256));
    if (lhsCst && rhsCst && !rhsCst->isZero())
      return FoldResult::of(op.kind == ArithKind::RemUI
                                ? lhsCst->urem(*rhsCst)
                                : lhsCst->srem(*rhsCst));
    return FoldResult::none();

  case ArithKind::AndI:
    if (rhsCst && rhsCst->isZero())
      return FoldResult::of(rhs);
    if (rhsCst && rhsCst->isAllOnes())
      return FoldResult::of(lhs);
    if (isAllOnesXOrOf(rhs, lhs) || isAllOnesXOrOf(lhs, rhs))
      return FoldResult::of(llvm::APInt::getZero(256));
    for (auto [prev, other] : {std::pair(lhs, rhs), std::pair(rhs, lhs)})
      if (prev->kind == ArithKind::AndI &&
          (other == operand(prev, 0) || other == operand(prev, 1)))
        return FoldResult::of(prev);
    return bothConstant(
        [](const llvm::APInt &a, const llvm::APInt &b) { return a & b; });

  case ArithKind::OrI:
    if (rhsCst && rhsCst->isZero())
      return FoldResult::of(lhs);
    if (rhsCst && rhsCst->isAllOnes())
      return FoldResult::of(*rhsCst);
    if (isAllOnesXOrOf(rhs, lhs))
      return FoldResult::of(operand(rhs, 1));
    if (isAllOnesXOrOf(lhs, rhs))
      return FoldResult::of(operand(lhs, 1));
    return bothConstant(
        [](const llvm::APInt &a, const llvm::APInt &b) { return a | b; });

  case ArithKind::XOrI:
    if (rhsCst && rhsCst->isZero())
      return FoldResult::of(lhs);
    if (lhs == rhs)
      return FoldResult::of(llvm::APInt::getZero(256));
    if (lhs->kind == ArithKind::XOrI) {
      if (operand(lhs, 1) == rhs)
        return FoldResult::of(operand(lhs, 0));
      if (operand(lhs, 0) == rhs)
        return FoldResult::of(operand(lhs, 1));
    }
    if (rhs->kind == ArithKind::XOrI) {
      if (operand(rhs, 1) == lhs)
        return FoldResult::of(operand(rhs, 0));
      if (operand(rhs, 0) == lhs)
        return FoldResult::of(operand(rhs, 1));
    }
    return bothConstant(
        [](const llvm::APInt &a, const llvm::APInt &b) { return a ^ b; });

  case ArithKind::ShLI:
  case ArithKind::ShRUI:
  case ArithKind::ShRSI:
    if (rhsCst && rhsCst->isZero())
      return FoldResult::of(lhs);
    if (lhsCst && rhsCst && rhsCst->ult(256)) {
      unsigned shift = rhsCst->getZExtValue();
      if (op.kind == ArithKind::ShLI)
        return FoldResult::of(lhsCst->shl(shift));
      return FoldResult::of(op.kind == ArithKind::ShRUI ? lhsCst->lshr(shift)
                                                        : lhsCst->ashr(shift));
    }
    return FoldResult::none();

  case ArithKind::CmpI: {
    llvm::CmpInst::Predicate pred = op.predicate[round];
    if (lhs == rhs)
      return FoldResult::of(
          llvm::APInt(1, llvm::CmpInst::isTrueWhenEqual(pred)));
    if (rhsCst && rhsCst->isZero() && lhs->kind == ArithKind::ExtUI &&
        pred == llvm::CmpInst::ICMP_NE)
      return FoldResult::of(operand(lhs, 0));
    if (lhsCst && !rhsCst) {
      op.predicate[round] = llvm::CmpInst::getSwappedPredicate(pred);
      std::swap(op.operands[round][0], op.operands[round][1]);
      return FoldResult::changed();
    }
    if (lhsCst)
      return FoldResult::of(
          llvm::APInt(1, llvm::ICmpInst::compare(*lhsCst, *rhsCst, pred)));
    return FoldResult::none();
  }

  case ArithKind::ExtUI:
    if (lhsCst)
      return FoldResult::of(lhsCst->zext(256));
    return FoldResult::none();

  case ArithKind::Select: {
    ArithOp *cond = lhs;
    ArithOp *trueVal = rhs;
    ArithOp *falseVal = op.operands[round][2];
    if (trueVal == falseVal)
      return FoldResult::of(trueVal);
    if (lhsCst)
      return FoldResult::of(lhsCst->isOne() ? trueVal : falseVal);
    if (cond->kind == ArithKind::CmpI) {
      llvm::CmpInst::Predicate pred = cond->predicate[round];
      ArithOp *cmpLhs = operand(cond, 0);
      ArithOp *cmpRhs = operand(cond, 1);
      if ((pred == llvm::CmpInst::ICMP_EQ || pred == llvm::CmpInst::ICMP_NE) &&
          ((cmpLhs == trueVal && cmpRhs == falseVal) ||
           (cmpRhs == trueVal && cmpLhs == falseVal)))
        return FoldResult::of(pred == llvm::CmpInst::ICMP_NE ? trueVal
                                                             : falseVal);
    }
    return FoldResult::none();
  }

  case ArithKind::Opaque:
  case ArithKind::Constant:
    break;
  }
  return FoldResult::none();
}

/// The fold of `op` with the folds of its traits, which run when the op's own
/// fold fails or changes it in place.
FoldResult fold(ArithOp &op, unsigned round) {
  FoldResult result = foldOp(op, round);
  if (result.value || result.constant)
    return result;
  auto &operands = op.operands[round];
  if (isCommutative(op.kind) && getConstant(operands[0]) &&
      !getConstant(operands[1])) {
    std::swap(operands[0], operands[1]);
    return FoldResult::changed();
  }
  if (isIdempotent(op.kind) && operands[0] == operands[1])
    return FoldResult::of(operands[0]);
  return result;
}

/// A block the lowering of a region op branches to, created by the first
/// branch to it, with a phi per block argument.
struct Dest {
  SmallVector<Type> types;
  SmallVector<Location> locs;
  llvm::BasicBlock *block = nullptr;
  SmallVector<llvm::PHINode *> phis;
  /// The block of each branch here, with the values it passes.
  SmallVector<std::pair<llvm::BasicBlock *, SmallVector<llvm::Value *>>>
      incoming;
};

struct LoopTargets {
  Dest *cond;
  Dest *body;
  Dest *step;
  Dest *exit;
};

class ObjectTranslation {
public:
  ObjectTranslation(yul::ObjectOp obj, LLVM::ModuleTranslation &mt)
      : obj(obj), mt(mt), llvmModule(*mt.getLLVMModule()),
        ctx(llvmModule.getContext()),
        builder(ctx, llvm::TargetFolder(llvmModule.getDataLayout())),
        i256Ty(llvm::Type::getIntNTy(ctx, 256)) {}

  LogicalResult translate();

private:
  LogicalResult translateGlobal(LLVM::GlobalOp op);
  LogicalResult declare(yul::FuncOp func);
  LogicalResult translateBody(yul::FuncOp func);
  void connectPhis();

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
  LogicalResult emitIf(yul::IfOp op, bool &fallsThrough);
  LogicalResult emitSwitch(yul::SwitchOp op, bool &fallsThrough);
  LogicalResult emitLoop(yul::LoopOpInterface op, bool &fallsThrough);
  LogicalResult emitScope(yul::ScopeOp op, bool &fallsThrough);
  LogicalResult emitCall(yul::FuncCallOp op);
  LogicalResult emitReturn(yul::FuncReturnOp op);
  LogicalResult emitLLVMOp(Operation &op);
  LogicalResult emitBuiltin(Operation &op, bool &fallsThrough);

  Dest &newDest(TypeRange types, ArrayRef<Location> locs);
  Dest &newDest(Block &block);
  llvm::BasicBlock *getBlock(Dest &dest);
  void place(llvm::BasicBlock *block);
  void addIncoming(Dest &dest, ValueRange operands);
  llvm::BranchInst *branch(Dest &dest, ValueRange operands);
  /// Maps `results` to the phis of `dest` and continues emission there.
  void continueAt(Dest &dest, ValueRange results);

  ArithOp *newArithOp(ArithKind kind, ArrayRef<ArithOp *> operands,
                      llvm::CmpInst::Predicate pred = {});
  ArithOp *newConstant(const llvm::APInt &value);
  ArithOp *arithOf(Value value);
  void legalize(ArithOp &op, unsigned round);
  llvm::Value *valueOf(ArithOp *op);
  void emitArith(ArithOp &op);
  void mapArith(Value value, ArithOp *op);
  /// The i1 of `cond`, from the `cmpi ne` against zero the lowering emits.
  llvm::Value *genCond(Value cond);

  llvm::Value *lookup(Value value) { return mt.lookupValue(value); }
  SmallVector<llvm::Value *> lookup(ValueRange values) {
    return mt.lookupValues(values);
  }
  void setLoc(Location loc) {
    builder.SetCurrentDebugLocation(mt.translateLoc(loc, subprogram));
  }
  llvm::Value *genPtr(Value addr, evm::AddrSpace addrSpace) {
    return builder.CreateIntToPtr(lookup(addr),
                                  llvm::PointerType::get(ctx, addrSpace));
  }
  llvm::CallInst *genIntrCall(llvm::Intrinsic::ID id,
                              ArrayRef<llvm::Value *> args,
                              ArrayRef<StringRef> metadata = {});
  llvm::Value *genLoad(llvm::Value *ptr, unsigned alignment);
  void genStore(llvm::Value *val, llvm::Value *ptr, unsigned alignment);
  llvm::MDNode *getFullUnrollLoopMetadata();

  yul::ObjectOp obj;
  LLVM::ModuleTranslation &mt;
  llvm::Module &llvmModule;
  llvm::LLVMContext &ctx;
  llvm::IRBuilder<llvm::TargetFolder> builder;
  llvm::IntegerType *i256Ty;
  llvm::MDNode *fullUnrollLoopMetadata = nullptr;
  DenseMap<StringRef, llvm::GlobalVariable *> globals;

  // Per function.
  llvm::Function *fn = nullptr;
  llvm::DISubprogram *subprogram = nullptr;
  /// The block the blocks of a region are placed before; null for the end.
  llvm::BasicBlock *placeBefore = nullptr;
  std::deque<Dest> dests;
  SmallVector<LoopTargets> loops;
  SmallVector<Dest *> scopes;
  DenseMap<Value, ArithOp *> arithOps;
  llvm::SpecificBumpPtrAllocator<ArithOp> arithAllocator;
};

} // namespace

//===----------------------------------------------------------------------===//
// Arith IR
//===----------------------------------------------------------------------===//

ArithOp *ObjectTranslation::newArithOp(ArithKind kind,
                                       ArrayRef<ArithOp *> operands,
                                       llvm::CmpInst::Predicate pred) {
  auto *op = new (arithAllocator.Allocate()) ArithOp{kind};
  llvm::copy(operands, op->operands[FuncToLLVMRound].begin());
  op->predicate[FuncToLLVMRound] = pred;
  legalize(*op, FuncToLLVMRound);
  if (op->replacement[FuncToLLVMRound])
    return op;
  for (auto [opd, committed] : llvm::zip(op->operands[ArithToLLVMRound],
                                         op->operands[FuncToLLVMRound]))
    opd = committed ? resolve(committed, FuncToLLVMRound) : nullptr;
  op->predicate[ArithToLLVMRound] = op->predicate[FuncToLLVMRound];
  legalize(*op, ArithToLLVMRound);
  if (!op->replacement[ArithToLLVMRound])
    emitArith(*op);
  return op;
}

ArithOp *ObjectTranslation::newConstant(const llvm::APInt &value) {
  auto *op = new (arithAllocator.Allocate()) ArithOp{ArithKind::Constant};
  op->value = llvm::ConstantInt::get(ctx, value);
  return op;
}

ArithOp *ObjectTranslation::arithOf(Value value) {
  auto [it, inserted] = arithOps.try_emplace(value);
  if (inserted) {
    it->second = new (arithAllocator.Allocate()) ArithOp{ArithKind::Opaque};
    it->second->value = lookup(value);
  }
  return it->second;
}

void ObjectTranslation::legalize(ArithOp &op, unsigned round) {
  // A fold in place is followed by another attempt, as the conversion driver
  // legalizes the changed op again.
  while (true) {
    FoldResult result = fold(op, round);
    if (result.value) {
      op.replacement[round] = result.value;
      return;
    }
    if (result.constant) {
      if (round == ArithToLLVMRound)
        op.replacement[round] = newConstant(*result.constant);
      return;
    }
    if (!result.inPlace)
      return;
  }
}

llvm::Value *ObjectTranslation::valueOf(ArithOp *op) {
  return resolve(resolve(op, FuncToLLVMRound), ArithToLLVMRound)->value;
}

void ObjectTranslation::emitArith(ArithOp &op) {
  auto operand = [&](unsigned i) {
    return resolve(op.operands[ArithToLLVMRound][i], ArithToLLVMRound)->value;
  };
  switch (op.kind) {
  case ArithKind::AddI:
    op.value = builder.CreateAdd(operand(0), operand(1));
    break;
  case ArithKind::SubI:
    op.value = builder.CreateSub(operand(0), operand(1));
    break;
  case ArithKind::MulI:
    op.value = builder.CreateMul(operand(0), operand(1));
    break;
  case ArithKind::AndI:
    op.value = builder.CreateAnd(operand(0), operand(1));
    break;
  case ArithKind::OrI:
    op.value = builder.CreateOr(operand(0), operand(1));
    break;
  case ArithKind::XOrI:
    op.value = builder.CreateXor(operand(0), operand(1));
    break;
  case ArithKind::ShLI:
    op.value = builder.CreateShl(operand(0), operand(1));
    break;
  case ArithKind::ShRUI:
    op.value = builder.CreateLShr(operand(0), operand(1));
    break;
  case ArithKind::ShRSI:
    op.value = builder.CreateAShr(operand(0), operand(1));
    break;
  case ArithKind::DivUI:
    op.value = builder.CreateUDiv(operand(0), operand(1));
    break;
  case ArithKind::DivSI:
    op.value = builder.CreateSDiv(operand(0), operand(1));
    break;
  case ArithKind::RemUI:
    op.value = builder.CreateURem(operand(0), operand(1));
    break;
  case ArithKind::RemSI:
    op.value = builder.CreateSRem(operand(0), operand(1));
    break;
  case ArithKind::CmpI:
    op.value = builder.CreateICmp(op.predicate[ArithToLLVMRound], operand(0),
                                  operand(1));
    break;
  case ArithKind::ExtUI:
    op.value = builder.CreateZExt(operand(0), i256Ty);
    break;
  case ArithKind::Select:
    op.value = builder.CreateSelect(operand(0), operand(1), operand(2));
    break;
  case ArithKind::Opaque:
  case ArithKind::Constant:
    llvm_unreachable("not an arith op");
  }
}

void ObjectTranslation::mapArith(Value value, ArithOp *op) {
  arithOps[value] = op;
  mt.mapValue(value, valueOf(op));
}

llvm::Value *ObjectTranslation::genCond(Value cond) {
  ArithOp *ne = newArithOp(ArithKind::CmpI,
                           {arithOf(cond), newConstant(llvm::APInt(256, 0))},
                           llvm::CmpInst::ICMP_NE);
  return valueOf(ne);
}

/// The arith op a binary Yul op lowers to.
static std::optional<ArithKind> getBinaryArithKind(Operation &op) {
  return TypeSwitch<Operation *, std::optional<ArithKind>>(&op)
      .Case([](yul::AddOp) { return ArithKind::AddI; })
      .Case([](yul::SubOp) { return ArithKind::SubI; })
      .Case([](yul::MulOp) { return ArithKind::MulI; })
      .Case([](yul::AndOp) { return ArithKind::AndI; })
      .Case([](yul::OrOp) { return ArithKind::OrI; })
      .Case([](yul::XOrOp) { return ArithKind::XOrI; })
      .Case([](yul::ArithShlOp) { return ArithKind::ShLI; })
      .Case([](yul::ArithShrOp) { return ArithKind::ShRUI; })
      .Case([](yul::ArithSarOp) { return ArithKind::ShRSI; })
      .Case([](yul::ArithDivOp) { return ArithKind::DivUI; })
      .Case([](yul::ArithSDivOp) { return ArithKind::DivSI; })
      .Case([](yul::ArithModOp) { return ArithKind::RemUI; })
      .Case([](yul::ArithSModOp) { return ArithKind::RemSI; })
      .Default([](Operation *) { return std::nullopt; });
}

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
  block->insertInto(fn, placeBefore);
  builder.SetInsertPoint(block);
}

void ObjectTranslation::addIncoming(Dest &dest, ValueRange operands) {
  if (dest.phis.empty())
    return;
  dest.incoming.emplace_back(builder.GetInsertBlock(), lookup(operands));
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

void ObjectTranslation::connectPhis() {
  // The LLVM dialect translation adds the incoming values in the order of the
  // block's predecessors, which is the reverse of the order
  // convert-cf-to-llvm creates their branches in: a depth-first walk from the
  // entry block.
  DenseMap<llvm::BasicBlock *, unsigned> order;
  for (llvm::BasicBlock *block : llvm::depth_first(&fn->getEntryBlock()))
    order.try_emplace(block, order.size());
  for (Dest &dest : dests) {
    if (!dest.block || dest.phis.empty())
      continue;
    llvm::stable_sort(dest.incoming, [&](const auto &a, const auto &b) {
      return order.lookup(a.first) > order.lookup(b.first);
    });
    for (auto &[pred, values] : dest.incoming)
      for (auto [phi, value] : llvm::zip(dest.phis, values))
        phi->addIncoming(value, pred);
  }
}

LogicalResult ObjectTranslation::emitBlock(Block &block, Dest *yieldDest,
                                           llvm::Instruction **yieldBranch) {
  for (Operation &op : block) {
    setLoc(op.getLoc());
    if (auto yield = dyn_cast<yul::YieldOp>(op)) {
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
  addIncoming(elseDest, {});

  if (!emptyElse && failed(emitRegion(elseDest, op.getElseRegion(), &cont)))
    return failure();
  if (failed(emitRegion(thenDest, op.getThenRegion(), &cont)))
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

  // Blocks are placed as the lowering inlines the regions: cond, body, step.
  loops.push_back({&cond, &body, step, &exit});
  if (isDoWhile) {
    if (failed(emitRegion(body, op.getBody(), next)))
      return failure();
    if (cond.block) {
      llvm::BasicBlock *outerPlaceBefore = placeBefore;
      placeBefore = body.block;
      if (failed(emitRegion(cond, op.getCond(), nullptr)))
        return failure();
      placeBefore = outerPlaceBefore;
    }
  } else {
    if (failed(emitRegion(cond, op.getCond(), nullptr)))
      return failure();
    if (body.block && failed(emitRegion(body, op.getBody(), next)))
      return failure();
    if (step && step->block) {
      llvm::Instruction *backEdge = nullptr;
      if (failed(emitRegion(*step, *stepRegion, &cond, &backEdge)))
        return failure();
      if (backEdge && op->hasAttr("full_unroll"))
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
  Dest &body = newDest({}, {});
  Dest &exit = newDest({}, {});
  branch(body, {});
  scopes.push_back(&exit);
  if (failed(emitRegion(body, op.getBodyRegion(), &exit)))
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

  if (std::optional<ArithKind> kind = getBinaryArithKind(op)) {
    mapArith(op.getResult(0), newArithOp(*kind, {arithOf(op.getOperand(0)),
                                                 arithOf(op.getOperand(1))}));
    return success();
  }

  return TypeSwitch<Operation *, LogicalResult>(&op)
      .Case([&](yul::ConstantOp op) {
        ArithOp *cst = newConstant(op.getValue());
        mapArith(op, cst);
        return success();
      })
      .Case([&](yul::NotOp op) {
        ArithOp *mask = newConstant(llvm::APInt::getAllOnes(256));
        mapArith(op,
                 newArithOp(ArithKind::XOrI, {arithOf(op.getValue()), mask}));
        return success();
      })
      .Case([&](yul::CmpOp op) {
        ArithOp *cmp = newArithOp(ArithKind::CmpI,
                                  {arithOf(op.getLhs()), arithOf(op.getRhs())},
                                  getPredicate(op.getPredicate()));
        mapArith(op, newArithOp(ArithKind::ExtUI, {cmp}));
        return success();
      })
      .Case([&](yul::ArithSelectOp op) {
        ArithOp *cond = newArithOp(
            ArithKind::CmpI,
            {arithOf(op.getCondition()), newConstant(llvm::APInt(256, 0))},
            llvm::CmpInst::ICMP_NE);
        mapArith(
            op, newArithOp(ArithKind::Select, {cond, arithOf(op.getTrueValue()),
                                               arithOf(op.getFalseValue())}));
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
  auto codePtr = [&](Value addr) { return genPtr(addr, evm::AddrSpace_Code); };
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

  // A noreturn op ends its block; what follows it is dead.
  if (op.hasTrait<yul::NoReturn>()) {
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
        });
    builder.CreateUnreachable();
    fallsThrough = false;
    return success();
  }

  return TypeSwitch<Operation *, LogicalResult>(&op)
      .Case([&](yul::ClzOp op) {
        // clz(0) == 256, so zero is not poison; the EVM backend selects
        // ctlz i256 to the Osaka CLZ opcode.
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
        llvm::Value *src = codePtr(op.getSrc());
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
  if (!op.getInitializerRegion().empty() || op.getComdat() || op.getDbgExprs())
    return op.emitError("unsupported global");
  llvm::Type *type = mt.convertType(op.getType());
  llvm::Constant *cst = nullptr;
  if (Attribute value = op.getValueOrNull()) {
    if (auto str = dyn_cast<StringAttr>(value)) {
      cst = llvm::ConstantDataArray::getString(ctx, str.getValue(),
                                               /*AddNull=*/false);
      type = cst->getType();
    } else if (!(cst = LLVM::detail::getLLVMConstant(type, value, op.getLoc(),
                                                     mt))) {
      return failure();
    }
  }
  llvm::GlobalValue::LinkageTypes linkage =
      convertLinkageToLLVM(op.getLinkage());
  if ((linkage == llvm::GlobalVariable::ExternalLinkage && !cst) ||
      linkage == llvm::GlobalVariable::ExternalWeakLinkage)
    cst = nullptr;
  else if (!cst)
    cst = llvm::UndefValue::get(type);

  auto *var = new llvm::GlobalVariable(
      llvmModule, type, op.getConstant(), linkage, cst, op.getSymName(),
      /*InsertBefore=*/nullptr,
      op.getThreadLocal_() ? llvm::GlobalValue::GeneralDynamicTLSModel
                           : llvm::GlobalValue::NotThreadLocal,
      op.getAddrSpace(), op.getExternallyInitialized());
  if (op.getUnnamedAddr())
    var->setUnnamedAddr(convertUnnamedAddrToLLVM(*op.getUnnamedAddr()));
  if (op.getSection())
    var->setSection(*op.getSection());
  if (op.getDsoLocal())
    var->setDSOLocal(true);
  if (std::optional<uint64_t> alignment = op.getAlignment())
    var->setAlignment(llvm::MaybeAlign(*alignment));
  var->setVisibility(convertVisibilityToLLVM(op.getVisibility_()));
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
  if (auto spLoc =
          func.getLoc()->findInstanceOf<FusedLocWith<LLVM::DISubprogramAttr>>())
    llvmFunc->setSubprogram(
        cast<llvm::DISubprogram>(mt.translateDebugInfo(spLoc.getMetadata())));
  return success();
}

LogicalResult ObjectTranslation::translateBody(yul::FuncOp func) {
  fn = mt.lookupFunction(func.getName());
  subprogram = fn->getSubprogram();
  placeBefore = nullptr;
  dests.clear();
  arithOps.clear();

  Region &body = func.getBody();
  if (!llvm::hasSingleElement(body))
    return func.emitError("expected a single block body");
  Block &entry = body.front();
  for (auto [arg, llvmArg] : llvm::zip(entry.getArguments(), fn->args()))
    mt.mapValue(arg, &llvmArg);
  place(llvm::BasicBlock::Create(ctx));
  if (failed(emitBlock(entry, nullptr)))
    return failure();
  connectPhis();
  return success();
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

  // The LLVM dialect translation declares an intrinsic at its first call,
  // translating the blocks of each function in reverse post-order.
  SmallVector<llvm::Function *> intrinsics;
  DenseSet<llvm::Function *> seen;
  for (yul::FuncOp func : funcs) {
    llvm::Function *llvmFunc = mt.lookupFunction(func.getName());
    for (llvm::BasicBlock *block :
         llvm::ReversePostOrderTraversal<llvm::Function *>(llvmFunc))
      for (llvm::Instruction &inst : *block)
        if (auto *call = dyn_cast<llvm::CallInst>(&inst))
          if (llvm::Function *callee = call->getCalledFunction();
              callee && callee->isIntrinsic() && seen.insert(callee).second)
            intrinsics.push_back(callee);
  }
  for (llvm::Function *intrinsic : intrinsics) {
    intrinsic->removeFromParent();
    llvmModule.getFunctionList().push_back(intrinsic);
  }
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

  LogicalResult
  convertOperation(Operation *op, llvm::IRBuilderBase &builder,
                   LLVM::ModuleTranslation &moduleTranslation) const final {
    auto obj = dyn_cast<yul::ObjectOp>(op);
    if (!obj)
      return op->emitError("expected a yul.object");
    return ObjectTranslation(obj, moduleTranslation).translate();
  }
};

} // namespace

void mlir::registerYulDialectTranslation(DialectRegistry &registry) {
  registry.insert<yul::YulDialect>();
  registry.addExtension(+[](MLIRContext *ctx, yul::YulDialect *dialect) {
    dialect->addInterfaces<YulDialectLLVMIRTranslationInterface>();
  });
}

void mlir::registerYulDialectTranslation(MLIRContext &context) {
  DialectRegistry registry;
  registerYulDialectTranslation(registry);
  context.appendDialectRegistry(registry);
}
