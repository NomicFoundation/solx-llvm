//===- SolToYul.cpp - Sol to Yul lowering ---------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Lowers the Sol contract of a module to its Yul object in one walk over its
// functions. An op is lowered after the ops defining its operands, so each Sol
// value is looked up for the Yul value it lowered to.
//
//===----------------------------------------------------------------------===//

#include "mlir/Conversion/SolToYul/SolToYul.h"
#include "mlir/Conversion/SolToYul/EVMConstants.h"
#include "mlir/Conversion/SolToYul/EVMUtil.h"
#include "mlir/Conversion/SolToYul/HelperSymbols.h"
#include "mlir/Conversion/SolToYul/Util.h"
#include "mlir/Dialect/LLVMIR/LLVMTypes.h"
#include "mlir/Dialect/Sol/DebugInfo.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/Dialect/Yul/Yul.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/IRMapping.h"
#include "mlir/IR/Matchers.h"
#include "mlir/IR/SymbolTable.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/Twine.h"
#include "llvm/ADT/TypeSwitch.h"
#include "llvm/Support/ErrorHandling.h"
#include <type_traits>

namespace mlir {
#define GEN_PASS_DEF_CONVERTSOLTOYULPASS
#include "mlir/Conversion/Passes.h.inc"
} // namespace mlir

using namespace mlir;
using solgen::getModule;

LLVM::GlobalOp evm::StringLiteralPool::getOrCreate(StringRef literal,
                                                   sol::ContractOp contr,
                                                   OpBuilder &b, Location loc) {
  auto [it, inserted] = globals.try_emplace(literal);
  if (!inserted)
    return it->second;
  std::string name = ("__data_in_code." + Twine(globals.size() - 1)).str();
  OpBuilder::InsertionGuard guard(b);
  b.setInsertionPointToStart(contr.getBody());
  it->second = b.create<LLVM::GlobalOp>(
      loc, LLVM::LLVMArrayType::get(b.getIntegerType(8), literal.size()),
      /*isConstant=*/true, LLVM::Linkage::Private, name,
      b.getStringAttr(literal), /*alignment=*/0, /*addrSpace=*/4);
  it->second.setUnnamedAddr(LLVM::UnnamedAddr::Global);
  return it->second;
}

namespace {

/// Lowers a module's one contract to its Yul object.
class Lowering {
public:
  explicit Lowering(sol::ContractOp contr)
      : contr(contr), mod(getModule(contr)), b(contr.getContext()) {}

  void run();

private:
  sol::ContractOp contr;
  ModuleOp mod;
  OpBuilder b;
  /// The Yul value of each lowered Sol value.
  IRMapping valMap;
  /// The yul.func a function of the contract lowers to, and its pointer value.
  struct Func {
    yul::FuncOp fn;
    std::optional<uint64_t> id;
  };
  /// The contract's functions by name. A yul.func shares its name with its
  /// sol.func until the contract is lowered, so it is reached through here,
  /// never through the symbol table.
  DenseMap<StringAttr, Func> funcs;
  /// The function whose body is being lowered.
  yul::FuncOp curFn;
  evm::InternalDispatch dispatch;
  evm::StringLiteralPool literalPool;

  /// Returns the Yul value of `v`.
  Value lowered(Value v) const {
    Value yulVal = valMap.lookupOrNull(v);
    assert(yulVal && "operand used before its definition is lowered");
    return yulVal;
  }

  /// Returns the Yul values of `vs`.
  SmallVector<Value> lowered(ValueRange vs) const {
    return llvm::map_to_vector(vs, [&](Value v) { return lowered(v); });
  }

  /// Maps `solVal` to its Yul value `yulVal`.
  void mapLowered(Value solVal, Value yulVal) {
    assert(!valMap.contains(solVal) && "value lowered twice");
    valMap.map(solVal, yulVal);
  }

  /// Maps each of `solVals` to its Yul value in `yulVals`.
  void mapLowered(ValueRange solVals, ValueRange yulVals) {
    for (auto [solVal, yulVal] : llvm::zip_equal(solVals, yulVals))
      mapLowered(solVal, yulVal);
  }

  /// Returns the declared function `name`.
  Func getFunc(StringAttr name) const {
    auto it = funcs.find(name);
    assert(it != funcs.end() && "function used before it is declared");
    return it->second;
  }

  /// Returns an EVM builder at `loc`.
  evm::Builder evmBuilder(Location loc) {
    return evm::Builder(mod, b, loc, literalPool);
  }

  /// Declares the yul.func of `fn`.
  void declare(sol::FuncOp fn);

  /// Lowers the body of `fn` into its yul.func.
  void lowerBody(sol::FuncOp fn);

  /// Lowers the ops of `src` at the insertion point.
  void lowerBlock(Block &src);

  /// Lowers each region of `src` into a block of the region of `dst` at the
  /// same position.
  void lowerRegions(Operation *src, Operation *dst);

  /// Lowers `op`.
  void lowerOp(Operation &op);

  /// Lowers `op` to what its folder computes, if it folds. A commutative op
  /// may fold in place first, moving a constant operand to the right.
  bool lowerFolded(Operation &op);

  /// Returns the Yul values of the operands of `op`, cleaned for their Sol
  /// types.
  SmallVector<Value> getCleaned(Operation *op);

  /// Generates field `field` of the {word, word} pair `pair`.
  Value genPairField(Value pair, int64_t field, Location loc) {
    return b.create<LLVM::ExtractValueOp>(loc, b.getIntegerType(256), pair,
                                          b.getDenseI64ArrayAttr({field}));
  }

  // Arithmetic

  Value lower(sol::ConstantOp op);
  /// Lowers the binary op `op` to a `YulOpT` of its operands.
  template <typename YulOpT, typename OpT>
  Value lowerBinOp(OpT op) {
    return b.create<YulOpT>(op.getLoc(), lowered(op.getLhs()),
                            lowered(op.getRhs()));
  }
  // old codegen begin
  // (Via-IR cleans output of these ops).
  Value lower(sol::AddOp op) { return lowerBinOp<yul::AddOp>(op); }
  Value lower(sol::SubOp op) { return lowerBinOp<yul::SubOp>(op); }
  Value lower(sol::MulOp op) { return lowerBinOp<yul::MulOp>(op); }
  Value lower(sol::AndOp op) { return lowerBinOp<yul::AndOp>(op); }
  Value lower(sol::OrOp op) { return lowerBinOp<yul::OrOp>(op); }
  Value lower(sol::XorOp op) { return lowerBinOp<yul::XOrOp>(op); }
  // old codegen end
  Value lower(sol::NotOp op);
  /// Lowers the division or modulo `op` to a `SignedOpT` or `UnsignedOpT` of
  /// its cleaned operands, after the division-by-zero panic.
  template <typename SignedOpT, typename UnsignedOpT, typename OpT>
  Value lowerDivOrMod(OpT op);
  // Signed div/mod use the EVM sdiv/smod ops (defined wrapping on INT_MIN/-1)
  // rather than the arith family, whose LLVM sdiv/srem are UB on that
  // overflow. Unsigned has no such overflow, so the arith ops are fine there.
  Value lower(sol::DivOp op) {
    return lowerDivOrMod<yul::SDivOp, yul::ArithDivOp>(op);
  }
  Value lower(sol::ModOp op) {
    return lowerDivOrMod<yul::SModOp, yul::ArithModOp>(op);
  }
  Value lower(sol::ExpOp op);
  Value lower(sol::ShlOp op);
  Value lower(sol::ShrOp op);
  Value lower(sol::CmpOp op);
  /// Lowers the modular `op` to a `YulOpT` of its cleaned operands, after the
  /// division-by-zero panic.
  template <typename YulOpT, typename OpT>
  Value lowerModArith(OpT op);
  Value lower(sol::AddModOp op) { return lowerModArith<yul::AddModOp>(op); }
  Value lower(sol::MulModOp op) { return lowerModArith<yul::MulModOp>(op); }
  Value lower(sol::CAddOp op);
  Value lower(sol::CSubOp op);
  Value lower(sol::CMulOp op);
  Value lower(sol::CDivOp op);
  /// Generates the loop of the checked exponentiation: it multiplies `initPow`
  /// by `initBase` raised to `initExp`, panicking on a power above `maxPow`,
  /// and returns the power and the base it reached.
  std::pair<Value, Value> genExpHelper(Location loc, Value initPow,
                                       Value initBase, Value initExp,
                                       Value maxPow);
  /// Generates the checked `base ** exp` of the unsigned type of `op`.
  Value genExpUnsigned(sol::CExpOp op, Value base, Value exp);
  /// Generates the checked `base ** exp` of the signed type of `op`.
  Value genExpSigned(sol::CExpOp op, Value base, Value exp);
  Value lower(sol::CExpOp op);

  // Casts

  Value lower(sol::CastOp op);
  Value lower(sol::AddressCastOp op);
  Value lower(sol::ContractCastOp op);
  Value lower(sol::EnumCastOp op);
  Value lower(sol::BytesCastOp op);
  Value lower(sol::DynBytesToFixedBytesOp op);
  Value lower(sol::FixedBytesIndexOp op);
  Value lower(sol::ExtFuncConstantOp op);
  Value lower(sol::ExtFuncAddrOp op);
  Value lower(sol::ExtFuncSelectorOp op);

  // Crypto

  Value lower(sol::Keccak256Op op);
  Value lower(sol::Erc7201Op op);
  /// Lowers the hash `op` to a static call of the precompile at
  /// `precompileAddr`.
  template <typename OpT>
  Value lowerHashPrecompile(OpT op, uint32_t precompileAddr);
  Value lower(sol::Sha256Op op) { return lowerHashPrecompile(op, 2); }
  Value lower(sol::Ripemd160Op op) { return lowerHashPrecompile(op, 3); }
  Value lower(sol::EcrecoverOp op);

  // Environment

  Value lower(sol::ThisOp op) { return b.create<yul::AddressOp>(op.getLoc()); }
  Value lower(sol::CallerOp op) { return b.create<yul::CallerOp>(op.getLoc()); }
  Value lower(sol::OriginOp op) { return b.create<yul::OriginOp>(op.getLoc()); }
  Value lower(sol::GasPriceOp op) {
    return b.create<yul::GasPriceOp>(op.getLoc());
  }
  Value lower(sol::CallValueOp op) {
    return b.create<yul::CallValOp>(op.getLoc());
  }
  Value lower(sol::BaseFeeOp op) {
    return b.create<yul::BaseFeeOp>(op.getLoc());
  }
  Value lower(sol::BlobBaseFeeOp op) {
    return b.create<yul::BlobBaseFeeOp>(op.getLoc());
  }
  Value lower(sol::ChainIdOp op) {
    return b.create<yul::ChainIdOp>(op.getLoc());
  }
  Value lower(sol::CoinbaseOp op) {
    return b.create<yul::CoinBaseOp>(op.getLoc());
  }
  Value lower(sol::DifficultyOp op) {
    return b.create<yul::PrevrandaoOp>(op.getLoc());
  }
  Value lower(sol::GasLimitOp op) {
    return b.create<yul::GasLimitOp>(op.getLoc());
  }
  Value lower(sol::BlockNumberOp op) {
    return b.create<yul::NumberOp>(op.getLoc());
  }
  Value lower(sol::PrevRandaoOp op) {
    return b.create<yul::PrevrandaoOp>(op.getLoc());
  }
  Value lower(sol::TimestampOp op) {
    return b.create<yul::TimeStampOp>(op.getLoc());
  }
  Value lower(sol::GasLeftOp op) { return b.create<yul::GasOp>(op.getLoc()); }
  Value lower(sol::SigOp op);
  Value lower(sol::BlockHashOp op);
  Value lower(sol::BlobHashOp op);
  void lower(sol::SelfdestructOp op);
  Value lower(sol::LibAddrOp op);
  Value lower(sol::CodeHashOp op);
  Value lower(sol::BalanceOp op);

  void lower(sol::AssertOp op);
  void lower(sol::RequireOp op);
  /// A constant string stays the Sol value its consumers read the bytes of.
  Value lower(sol::ConstantStringOp op) { return op; }

  // Control flow

  void lower(sol::IfOp op);
  void lower(sol::SwitchOp op);
  void lower(sol::WhileOp op);
  void lower(sol::DoWhileOp op);
  void lower(sol::ForOp op);
  void lower(sol::ScopeOp op);
  void lower(sol::LeaveOp op);
  void lower(sol::YieldOp op);
  void lower(sol::ConditionOp op);
  void lower(sol::BreakOp op);
  void lower(sol::ContinueOp op);

  // Functions

  SmallVector<Value> lower(sol::CallOp op);
  void lower(sol::ReturnOp op);

  // Memory and storage

  Value lower(sol::AllocaOp op);
  Value lower(sol::MallocOp op);
  Value lower(sol::ArrayLitOp op);
  Value lower(sol::StringLitOp op);
  Value lower(sol::ConcatOp op);
  Value lower(sol::GetCallDataOp op);
  Value lower(sol::DefaultCallDataOp op);
  Value lower(sol::DefaultStorageOp op);
  Value lower(sol::PushOp op);
  void lower(sol::PushStringOp op);
  void lower(sol::PopOp op);
  Value lower(sol::AddrOfOp op);
  Value lower(sol::GepOp op);
  Value lower(sol::MapOp op);
  Value lower(sol::LoadOp op);
  Value lower(sol::LoadImmutableOp op);
  void lower(sol::StoreOp op);
  Value lower(sol::DataLocCastOp op);
  Value lower(sol::LengthOp op);
  Value lower(sol::SliceOp op);
  void lower(sol::CopyOp op);
  void lower(sol::DeleteOp op);

  // ABI

  Value lower(sol::EncodeOp op);
  SmallVector<Value> lower(sol::DecodeOp op);
  void lower(sol::EmitOp op);
  void lower(sol::RevertOp op);

  // External calls

  /// An external call: its Sol arguments `ins` to the callee inputs
  /// `calleeInputTys`, its Sol results `resultTys` after the status, and the
  /// Yul values of the rest.
  struct ExtCall {
    ValueRange ins;
    TypeRange calleeInputTys;
    TypeRange resultTys;
    Value addr;
    Type addrTy;
    Value selector, gas, val;
    bool tryCall, staticCall, delegateCall, libraryCall;
  };
  /// Generates `call` and returns its status and results.
  SmallVector<Value> genExtCall(const ExtCall &call, Location loc);
  SmallVector<Value> lower(sol::ExtCallOp op);
  SmallVector<Value> lower(sol::ExtICallOp op);
  /// Lowers the bare call `op` to a `YulCallOpT` and returns its status and
  /// return data.
  template <typename YulCallOpT, typename OpT>
  SmallVector<Value> lowerBareCall(OpT op);
  SmallVector<Value> lower(sol::BareCallOp op) {
    return lowerBareCall<yul::CallOp>(op);
  }
  SmallVector<Value> lower(sol::BareDelegateCallOp op) {
    return lowerBareCall<yul::DelegateCallOp>(op);
  }
  SmallVector<Value> lower(sol::BareStaticCallOp op) {
    return lowerBareCall<yul::StaticCallOp>(op);
  }
  /// Generates the value transfer of `op` with the call stipend and returns
  /// its status compared to zero by `pred`.
  template <typename OpT>
  Value genValueTransferStatus(OpT op, yul::CmpPredicate pred);
  Value lower(sol::SendOp op);
  void lower(sol::TransferOp op);
  Value lower(sol::NewOp op);
  Value lower(sol::ObjectCodeOp op);
  Value lower(sol::CodeOp op);
  Value lower(sol::CodeSizeOp op);

  // Try

  void lower(sol::TryOp op);
  /// A clause of a try: its entry block is lowered at the end of `entry`, its
  /// other blocks at the end of `rest`.
  struct Clause {
    Region *src;
    Block *entry;
    Region *rest;
  };
  /// Lowers `clauses` in order.
  void lowerClauses(ArrayRef<Clause> clauses);

  // Internal function pointers

  Value lower(sol::FuncConstantOp op);
  Value lower(sol::DefaultFuncConstantOp op);
  SmallVector<Value> lower(sol::ICallOp op);

  // Inline assembly

  void lower(sol::InlineAsmOp op);
  /// Returns `ptr` as the !yul.ptr inline assembly takes, cast at the
  /// insertion point.
  Value getYulPtr(Value ptr, Location loc);
  /// Lowers `op`, the address of field `field` of the {word, word} pair at its
  /// source, to the !yul.ptr of the field.
  template <typename OpT>
  Value lowerPairFieldPtr(OpT op, int field);
  Value lower(sol::YulPtrCastOp op) {
    return getYulPtr(lowered(op.getSrc()), op.getLoc());
  }
  Value lower(sol::YulValCastOp op) { return lowered(op.getSrc()); }
  Value lower(sol::YulStorageSlotOp op) {
    return getYulPtr(lowered(op.getSrc()), op.getLoc());
  }
  Value lower(sol::YulCallDataOffsetOp op) { return lowerPairFieldPtr(op, 0); }
  Value lower(sol::YulCallDataLengthOp op) { return lowerPairFieldPtr(op, 1); }
  Value lower(sol::YulFuncAddrOp op) { return lowerPairFieldPtr(op, 0); }
  Value lower(sol::YulSelectorOp op) { return lowerPairFieldPtr(op, 1); }
  Value lower(sol::YulStorageOffsetOp op);
  Value lower(sol::YulStateVarSlotOp op);
  Value lower(sol::YulStateVarOffsetOp op);

  // Contract

  /// The functions a contract's code calls: the constructor, the interface
  /// functions with their selectors, and receive and fallback.
  struct ContractFns {
    sol::FuncOp ctor, receive, fallback;
    SmallVector<sol::FuncOp, 4> ifc;
    SmallVector<uint32_t, 4> selectors;
  };

  /// Generates a call of the contract's function `callee`.
  yul::FuncCallOp genCall(StringAttr callee, ValueRange args, Location loc);

  /// Generates the call value check.
  void genCallValChk(Location loc);

  /// Generates the free pointer initialization. A memoryguard lets the backend
  /// claim the memory below it for spills, which memory-unsafe inline assembly
  /// rules out.
  void genFreePtrInit(Location loc, size_t reservedMem = 0);

  /// Generates the dispatch to the interface functions.
  void genDispatch(ContractFns &fns, Location loc);

  /// Generates the creation code: it runs the constructor `ctor`, if any, then
  /// returns the runtime object's code with the immutables set.
  void genCreationCode(sol::FuncOp ctor, StringRef runtimeObjName,
                       Location loc);

  /// Generates the runtime code: the dispatch to the interface functions, then
  /// receive and fallback.
  void genRuntimeCode(ContractFns &fns, Location loc);

  /// Replaces the contract with its object.
  void lowerContract();
};

} // namespace

//===----------------------------------------------------------------------===//
// Walk
//===----------------------------------------------------------------------===//

void Lowering::run() {
  SmallVector<sol::FuncOp> creationRefs;
  for (auto sym : contr.getCreationFuncRefs().getAsRange<FlatSymbolRefAttr>())
    creationRefs.push_back(contr.lookupSymbol<sol::FuncOp>(sym));

  // Every function is declared ahead of the bodies, which name them.
  auto fns = llvm::to_vector(contr.getBody()->getOps<sol::FuncOp>());
  for (sol::FuncOp fn : fns)
    declare(fn);
  for (sol::FuncOp fn : creationRefs)
    dispatch.addTarget(getFunc(fn.getSymNameAttr()).fn, *fn.getId());
  for (sol::FuncOp fn : fns)
    lowerBody(fn);

  lowerContract();
  dispatch.genDispatchFns();
}

void Lowering::declare(sol::FuncOp fn) {
  OpBuilder::InsertionGuard guard(b);
  b.setInsertionPointAfter(fn);
  auto ty = cast<FunctionType>(evm::getYulType(fn.getFunctionType()));
  yul::FuncOp yulFn = evm::createPrivateFunc(b, fn.getLoc(), fn.getName(), ty);
  if (Attribute linkage = fn->getAttr("llvm.linkage"))
    yulFn->setAttr("llvm.linkage", linkage);
  funcs[fn.getSymNameAttr()] = {yulFn, fn.getId()};
}

void Lowering::lowerBody(sol::FuncOp fn) {
  curFn = getFunc(fn.getSymNameAttr()).fn;
  lowerRegions(fn, curFn);
  valMap.clear();
}

void Lowering::lowerBlock(Block &src) {
  for (Operation &op : src) {
    lowerOp(op);
    // The code after a lowering that ends the block, such as an inline
    // assembly body that halts, is unreachable.
    Block::iterator ip = b.getInsertionPoint();
    if (ip != b.getInsertionBlock()->begin() &&
        std::prev(ip)->hasTrait<OpTrait::IsTerminator>())
      return;
  }
}

void Lowering::lowerRegions(Operation *src, Operation *dst) {
  OpBuilder::InsertionGuard guard(b);
  for (auto [srcRegion, dstRegion] :
       llvm::zip_equal(src->getRegions(), dst->getRegions())) {
    // Blocks lower in list order, which suits structured control flow, so we
    // don't need RPO here.
    for (Block &srcBlock : srcRegion) {
      SmallVector<Location> argLocs =
          llvm::map_to_vector(srcBlock.getArguments(),
                              [](BlockArgument arg) { return arg.getLoc(); });
      Block *dstBlock = b.createBlock(
          &dstRegion, dstRegion.end(),
          llvm::map_to_vector(srcBlock.getArgumentTypes(), evm::getYulType),
          argLocs);
      mapLowered(srcBlock.getArguments(), dstBlock->getArguments());
      lowerBlock(srcBlock);
    }
  }
}

void Lowering::lowerOp(Operation &op) {
  // A lowering may leave the insertion point in a region it built.
  OpBuilder::InsertionGuard guard(b);

  // A Yul op of an inline assembly body is cloned over its lowered operands;
  // its regions are lowered in turn.
  if (!isa<sol::SolDialect>(op.getDialect())) {
    assert(llvm::all_of(op.getOperands(),
                        [&](Value v) { return valMap.contains(v); }) &&
           "operand used before its definition is lowered");
    lowerRegions(&op, b.cloneWithoutRegions(op, valMap));
    return;
  }

  if (lowerFolded(op))
    return;

  TypeSwitch<Operation *>(&op)
      .Case<
          // clang-format off
          sol::ConstantOp,
          sol::AddOp,
          sol::SubOp,
          sol::MulOp,
          sol::AndOp,
          sol::OrOp,
          sol::XorOp,
          sol::NotOp,
          sol::DivOp,
          sol::ModOp,
          sol::ExpOp,
          sol::ShlOp,
          sol::ShrOp,
          sol::CmpOp,
          sol::AddModOp,
          sol::MulModOp,
          sol::CAddOp,
          sol::CSubOp,
          sol::CMulOp,
          sol::CDivOp,
          sol::CExpOp,
          sol::CastOp,
          sol::AddressCastOp,
          sol::ContractCastOp,
          sol::EnumCastOp,
          sol::BytesCastOp,
          sol::DynBytesToFixedBytesOp,
          sol::FixedBytesIndexOp,
          sol::ExtFuncConstantOp,
          sol::ExtFuncAddrOp,
          sol::ExtFuncSelectorOp,
          sol::Keccak256Op,
          sol::Erc7201Op,
          sol::Sha256Op,
          sol::Ripemd160Op,
          sol::EcrecoverOp,
          sol::ThisOp,
          sol::CallerOp,
          sol::OriginOp,
          sol::GasPriceOp,
          sol::CallValueOp,
          sol::BaseFeeOp,
          sol::BlobBaseFeeOp,
          sol::ChainIdOp,
          sol::CoinbaseOp,
          sol::DifficultyOp,
          sol::GasLimitOp,
          sol::BlockNumberOp,
          sol::PrevRandaoOp,
          sol::TimestampOp,
          sol::GasLeftOp,
          sol::SigOp,
          sol::BlockHashOp,
          sol::BlobHashOp,
          sol::SelfdestructOp,
          sol::LibAddrOp,
          sol::CodeHashOp,
          sol::BalanceOp,
          sol::AssertOp,
          sol::RequireOp,
          sol::ConstantStringOp,
          sol::IfOp,
          sol::SwitchOp,
          sol::WhileOp,
          sol::DoWhileOp,
          sol::ForOp,
          sol::ScopeOp,
          sol::LeaveOp,
          sol::YieldOp,
          sol::ConditionOp,
          sol::BreakOp,
          sol::ContinueOp,
          sol::CallOp,
          sol::ReturnOp,
          sol::AllocaOp,
          sol::MallocOp,
          sol::ArrayLitOp,
          sol::StringLitOp,
          sol::ConcatOp,
          sol::GetCallDataOp,
          sol::DefaultCallDataOp,
          sol::DefaultStorageOp,
          sol::PushOp,
          sol::PushStringOp,
          sol::PopOp,
          sol::AddrOfOp,
          sol::GepOp,
          sol::MapOp,
          sol::LoadOp,
          sol::LoadImmutableOp,
          sol::StoreOp,
          sol::DataLocCastOp,
          sol::LengthOp,
          sol::SliceOp,
          sol::CopyOp,
          sol::DeleteOp,
          sol::EncodeOp,
          sol::DecodeOp,
          sol::EmitOp,
          sol::RevertOp,
          sol::ExtCallOp,
          sol::ExtICallOp,
          sol::BareCallOp,
          sol::BareDelegateCallOp,
          sol::BareStaticCallOp,
          sol::SendOp,
          sol::TransferOp,
          sol::NewOp,
          sol::ObjectCodeOp,
          sol::CodeOp,
          sol::CodeSizeOp,
          sol::TryOp,
          sol::FuncConstantOp,
          sol::DefaultFuncConstantOp,
          sol::ICallOp,
          sol::InlineAsmOp,
          sol::YulPtrCastOp,
          sol::YulValCastOp,
          sol::YulStorageSlotOp,
          sol::YulCallDataOffsetOp,
          sol::YulCallDataLengthOp,
          sol::YulFuncAddrOp,
          sol::YulSelectorOp,
          sol::YulStorageOffsetOp,
          sol::YulStateVarSlotOp,
          sol::YulStateVarOffsetOp
          // clang-format on
          >([&](auto op) {
        // A lowering returns the Yul value of each result: a Value for a
        // single-result op, a SmallVector<Value> for a variadic one, nothing
        // for an op without results.
        using ResultT = decltype(lower(op));
        if constexpr (std::is_same_v<ResultT, Value>) {
          assert(op->getNumResults() == 1 && "expected a single-result op");
          mapLowered(op->getResult(0), lower(op));
        } else if constexpr (std::is_same_v<ResultT, SmallVector<Value>>) {
          SmallVector<Value> results = lower(op);
          assert(results.size() == op->getNumResults() &&
                 "expected a Yul value per result");
          mapLowered(op->getResults(), results);
        } else {
          static_assert(std::is_void_v<ResultT>);
          assert(op->getNumResults() == 0 && "expected an op without results");
          lower(op);
        }
      })
      .Default([](Operation *) {
        llvm_unreachable("unexpected op in a function body");
      });
}

bool Lowering::lowerFolded(Operation &op) {
  if (matchPattern(&op, m_Constant()))
    return false;

  SmallVector<OpFoldResult> folded;
  do {
    if (failed(op.fold(folded)))
      return false;
  } while (folded.empty());

  for (auto [res, foldRes] : llvm::zip_equal(op.getResults(), folded)) {
    if (auto val = dyn_cast<Value>(foldRes)) {
      mapLowered(res, lowered(val));
      continue;
    }
    // As in the conversion driver, a folded attribute is materialized as a Sol
    // constant, which lowers like any other op.
    Operation *constOp = op.getDialect()->materializeConstant(
        b, cast<Attribute>(foldRes), res.getType(), op.getLoc());
    assert(constOp && "folded attribute the dialect cannot materialize");
    assert(constOp->getNumResults() == 1 &&
           "expected a single-result constant");
    lowerOp(*constOp);
    mapLowered(res, lowered(constOp->getResult(0)));
    constOp->erase();
  }
  return true;
}

SmallVector<Value> Lowering::getCleaned(Operation *op) {
  Location loc = op->getLoc();
  evm::Builder evmB = evmBuilder(loc);
  return llvm::map_to_vector(op->getOperands(), [&](Value v) {
    return evmB.genCleanup(v.getType(), lowered(v), loc);
  });
}

//===----------------------------------------------------------------------===//
// Arithmetic
//===----------------------------------------------------------------------===//

Value Lowering::lower(sol::ConstantOp op) {
  return solgen::BuilderExt(b, op.getLoc())
      .genI256Const(cast<IntegerAttr>(op.getValue()).getValue(),
                    cast<IntegerType>(op.getType()));
}

// old codegen begin
// (Via-IR cleans output of this op).
Value Lowering::lower(sol::NotOp op) {
  return b.create<yul::NotOp>(op.getLoc(), lowered(op.getValue()));
}
// old codegen end

template <typename SignedOpT, typename UnsignedOpT, typename OpT>
Value Lowering::lowerDivOrMod(OpT op) {
  Location loc = op.getLoc();
  SmallVector<Value> cleaned = getCleaned(op);
  Value lhs = cleaned[0], rhs = cleaned[1];
  evmBuilder(loc).genDivisionByZeroPanic(rhs, loc);
  if (cast<IntegerType>(op.getType()).isSigned())
    return b.create<SignedOpT>(loc, lhs, rhs);
  return b.create<UnsignedOpT>(loc, lhs, rhs);
}

Value Lowering::lower(sol::ExpOp op) {
  SmallVector<Value> cleaned = getCleaned(op);
  return b.create<yul::ExpOp>(op.getLoc(), cleaned[0], cleaned[1]);
}

Value Lowering::lower(sol::ShlOp op) {
  SmallVector<Value> cleaned = getCleaned(op);
  Value val = cleaned[0], shift = cleaned[1];
  return b.create<yul::ShlOp>(op.getLoc(), shift, val);
}

Value Lowering::lower(sol::ShrOp op) {
  SmallVector<Value> cleaned = getCleaned(op);
  Value val = cleaned[0], shift = cleaned[1];
  if (auto ty = dyn_cast<IntegerType>(op.getType()))
    if (ty.isSigned())
      return b.create<yul::SarOp>(op.getLoc(), shift, val);
  return b.create<yul::ShrOp>(op.getLoc(), shift, val);
}

/// Returns the Yul predicate of `pred` comparing integers of signedness
/// `isSigned`.
static yul::CmpPredicate getYulPred(sol::CmpPredicate pred, bool isSigned) {
  switch (pred) {
  case sol::CmpPredicate::eq:
    return yul::CmpPredicate::eq;
  case sol::CmpPredicate::ne:
    return yul::CmpPredicate::ne;
  case sol::CmpPredicate::lt:
    return isSigned ? yul::CmpPredicate::slt : yul::CmpPredicate::ult;
  case sol::CmpPredicate::le:
    return isSigned ? yul::CmpPredicate::sle : yul::CmpPredicate::ule;
  case sol::CmpPredicate::gt:
    return isSigned ? yul::CmpPredicate::sgt : yul::CmpPredicate::ugt;
  case sol::CmpPredicate::ge:
    return isSigned ? yul::CmpPredicate::sge : yul::CmpPredicate::uge;
  }
  llvm_unreachable("Invalid predicate");
}

Value Lowering::lower(sol::CmpOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);
  bool isSigned = false;
  if (auto intTy = dyn_cast<IntegerType>(op.getLhs().getType()))
    isSigned = intTy.isSigned();
  yul::CmpPredicate pred = getYulPred(op.getPredicate(), isSigned);

  // An external function compares by its address and selector lanes.
  if (isa<sol::ExtFuncRefType>(op.getLhs().getType())) {
    assert((pred == yul::CmpPredicate::eq || pred == yul::CmpPredicate::ne) &&
           "unexpected predicate on external functions");
    auto genLaneCmp = [&](int64_t idx, unsigned numBits) {
      Value mask = bExt.genI256Const(APInt::getLowBitsSet(256, numBits));
      Value lhsLane = genPairField(lowered(op.getLhs()), idx, loc);
      Value rhsLane = genPairField(lowered(op.getRhs()), idx, loc);
      return bExt.genCmp(pred, b.create<yul::AndOp>(loc, lhsLane, mask),
                         b.create<yul::AndOp>(loc, rhsLane, mask));
    };
    Value addrCmp = genLaneCmp(0, 160);
    Value selCmp = genLaneCmp(1, 32);
    if (pred == yul::CmpPredicate::eq)
      return b.create<yul::AndOp>(loc, addrCmp, selCmp);
    return b.create<yul::OrOp>(loc, addrCmp, selCmp);
  }

  Value lhs = evmB.genCleanup(op.getLhs().getType(), lowered(op.getLhs()), loc);
  Value rhs = evmB.genCleanup(op.getRhs().getType(), lowered(op.getRhs()), loc);
  return bExt.genCmp(pred, lhs, rhs);
}

template <typename YulOpT, typename OpT>
Value Lowering::lowerModArith(OpT op) {
  Location loc = op.getLoc();
  SmallVector<Value> cleaned = getCleaned(op);
  evmBuilder(loc).genDivisionByZeroPanic(cleaned[2], loc);
  return b.create<YulOpT>(loc, cleaned[0], cleaned[1], cleaned[2]);
}

Value Lowering::lower(sol::CAddOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);
  SmallVector<Value> cleaned = getCleaned(op);
  Value lhs = cleaned[0], rhs = cleaned[1];

  auto ty = cast<IntegerType>(op.getType());
  Value sum = b.create<yul::AddOp>(loc, lhs, rhs);

  if (ty.getWidth() < 256) {
    if (ty.isSigned()) {
      // overflow, if sum > max
      // underflow, if sum < min
      Value max =
          bExt.genI256Const(APInt::getSignedMaxValue(ty.getWidth()), ty, loc);
      Value overMax = bExt.genCmp(yul::CmpPredicate::sgt, sum, max);
      Value min =
          bExt.genI256Const(APInt::getSignedMinValue(ty.getWidth()), ty, loc);
      Value underMin = bExt.genCmp(yul::CmpPredicate::slt, sum, min);
      evmB.genPanic(mlir::evm::PanicCode::UnderOverflow,
                    b.create<yul::OrOp>(loc, overMax, underMin));
    } else {
      // overflow, if sum > max
      Value max = bExt.genI256Const(APInt::getMaxValue(ty.getWidth()), ty, loc);
      evmB.genPanic(mlir::evm::PanicCode::UnderOverflow,
                    bExt.genCmp(yul::CmpPredicate::ugt, sum, max));
    }
    return sum;
  }

  if (ty.isSigned()) {
    // (Copied from the yul codegen)
    // overflow, if y >= 0 and sum < x
    // underflow, if y < 0 and sum >= x
    //
    // The rhs is compared with zero since the canonicalizer could make it a
    // constant, which folds the comparison.
    auto zero = bExt.genI256Const(0, loc);

    auto rhsGtEqZero = bExt.genCmp(yul::CmpPredicate::sge, rhs, zero);
    auto sumLtLhs = bExt.genCmp(yul::CmpPredicate::slt, sum, lhs);
    auto overflowCond = b.create<yul::AndOp>(loc, rhsGtEqZero, sumLtLhs);

    auto rhsLtZero = bExt.genCmp(yul::CmpPredicate::slt, rhs, zero);
    auto sumGtEqLhs = bExt.genCmp(yul::CmpPredicate::sge, sum, lhs);
    auto underflowCond = b.create<yul::AndOp>(loc, rhsLtZero, sumGtEqLhs);

    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow,
                  b.create<yul::OrOp>(loc, overflowCond, underflowCond));
  } else {
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow,
                  bExt.genCmp(yul::CmpPredicate::ugt, lhs, sum));
  }
  return sum;
}

Value Lowering::lower(sol::CSubOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);
  SmallVector<Value> cleaned = getCleaned(op);
  Value lhs = cleaned[0], rhs = cleaned[1];

  auto ty = cast<IntegerType>(op.getType());
  Value diff = b.create<yul::SubOp>(loc, lhs, rhs);

  if (ty.getWidth() < 256) {
    if (ty.isSigned()) {
      // overflow, if diff > max
      // underflow, if diff < min
      Value max =
          bExt.genI256Const(APInt::getSignedMaxValue(ty.getWidth()), ty, loc);
      Value overMax = bExt.genCmp(yul::CmpPredicate::sgt, diff, max);
      Value min =
          bExt.genI256Const(APInt::getSignedMinValue(ty.getWidth()), ty, loc);
      Value underMin = bExt.genCmp(yul::CmpPredicate::slt, diff, min);
      evmB.genPanic(mlir::evm::PanicCode::UnderOverflow,
                    b.create<yul::OrOp>(loc, overMax, underMin));
    } else {
      // underflow, if diff > max
      Value max = bExt.genI256Const(APInt::getMaxValue(ty.getWidth()), ty, loc);
      evmB.genPanic(mlir::evm::PanicCode::UnderOverflow,
                    bExt.genCmp(yul::CmpPredicate::ugt, diff, max));
    }
    return diff;
  }

  if (ty.isSigned()) {
    // (Copied from the yul codegen)
    // underflow, if y >= 0 and diff > x
    // overflow, if y < 0 and diff < x
    auto zero = bExt.genI256Const(0, loc);

    auto rhsGtEqZero = bExt.genCmp(yul::CmpPredicate::sge, rhs, zero);
    auto diffGtLhs = bExt.genCmp(yul::CmpPredicate::sgt, diff, lhs);
    auto overflowCond = b.create<yul::AndOp>(loc, rhsGtEqZero, diffGtLhs);

    auto rhsLtZero = bExt.genCmp(yul::CmpPredicate::slt, rhs, zero);
    auto diffLtRhs = bExt.genCmp(yul::CmpPredicate::slt, diff, lhs);
    auto underflowCond = b.create<yul::AndOp>(loc, rhsLtZero, diffLtRhs);

    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow,
                  b.create<yul::OrOp>(loc, overflowCond, underflowCond));
  } else {
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow,
                  bExt.genCmp(yul::CmpPredicate::ugt, diff, lhs));
  }
  return diff;
}

Value Lowering::lower(sol::CMulOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);
  SmallVector<Value> cleaned = getCleaned(op);
  Value lhs = cleaned[0], rhs = cleaned[1];

  auto ty = cast<IntegerType>(op.getType());
  Value rawProduct = b.create<yul::MulOp>(loc, lhs, rhs);
  Value product = evmB.genCleanup(op.getType(), rawProduct, loc);
  auto zero = bExt.genI256Const(0, loc);
  if (ty.getWidth() <= 128) {
    // overflow/underflow, if product != product_raw
    Value panicCond = bExt.genCmp(yul::CmpPredicate::ne, rawProduct, product);
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow, panicCond);
    return product;
  }

  if (ty.isSigned()) {
    // (Copied from the yul codegen)
    // underflow, if x < 0 and y == int.min
    if (ty.getWidth() == 256) {
      auto lhsLtZero = bExt.genCmp(yul::CmpPredicate::slt, lhs, zero);
      auto minVal =
          bExt.genI256Const(APInt::getSignedMinValue(ty.getWidth()), ty, loc);
      auto rhsEqMin = bExt.genCmp(yul::CmpPredicate::eq, rhs, minVal);
      evmB.genPanic(mlir::evm::PanicCode::UnderOverflow,
                    b.create<yul::AndOp>(loc, lhsLtZero, rhsEqMin));
    }

    // over/underflow, if x != 0 and product/x != y
    auto lhsNeqZero = bExt.genCmp(yul::CmpPredicate::ne, lhs, zero);
    auto quotient = b.create<yul::SDivOp>(loc, product, lhs);
    auto quotientNeqRhs = bExt.genCmp(yul::CmpPredicate::ne, quotient, rhs);
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow,
                  b.create<yul::AndOp>(loc, lhsNeqZero, quotientNeqRhs));
  } else {
    // over/underflow, if x != 0 and product/x != y
    auto lhsNeqZero = bExt.genCmp(yul::CmpPredicate::ne, lhs, zero);
    auto quotient = b.create<yul::DivOp>(loc, product, lhs);
    auto quotientNeqRhs = bExt.genCmp(yul::CmpPredicate::ne, quotient, rhs);
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow,
                  b.create<yul::AndOp>(loc, lhsNeqZero, quotientNeqRhs));
  }
  return product;
}

Value Lowering::lower(sol::CDivOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);
  SmallVector<Value> cleaned = getCleaned(op);
  Value lhs = cleaned[0], rhs = cleaned[1];

  auto ty = cast<IntegerType>(op.getType());
  evmB.genDivisionByZeroPanic(rhs, loc);

  if (!ty.isSigned())
    return b.create<yul::ArithDivOp>(loc, lhs, rhs);

  // (Copied from the yul codegen)
  // underflow, if x == int.min and y == -1
  auto minVal =
      bExt.genI256Const(APInt::getSignedMinValue(ty.getWidth()), ty, loc);
  auto lhsEqMin = bExt.genCmp(yul::CmpPredicate::eq, lhs, minVal);
  auto minusOne = bExt.genI256Const(-1, loc);
  auto rhsEqMinusOne = bExt.genCmp(yul::CmpPredicate::eq, rhs, minusOne);
  evmB.genPanic(mlir::evm::PanicCode::UnderOverflow,
                b.create<yul::AndOp>(loc, lhsEqMin, rhsEqMinusOne));
  return b.create<yul::ArithSDivOp>(loc, lhs, rhs);
}

// The helper implements:
//
//   function checked_exp_helper(power, base, exponent, max) -> power, base {
//     for { } gt(exponent, 1) {}
//     {
//       if gt(base, div(max, base)) { panic_error_0x11() }
//       if and(exponent, 1)
//       {
//         power := mul(power, base)
//       }
//       base := mul(base, base)
//       exponent := shift_right_1_unsigned(exponent)
//     }
//  }
std::pair<Value, Value> Lowering::genExpHelper(Location loc, Value initPow,
                                               Value initBase, Value initExp,
                                               Value maxPow) {
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  Value one = bExt.genI256Const(1, loc);
  SmallVector<Value> whileInitVals{initPow, initBase, initExp};
  TypeRange whileArgTypes(whileInitVals);
  SmallVector<Location> whileBbArgLocs(whileInitVals.size(), loc);

  auto whileOp = b.create<yul::WhileOp>(loc, whileArgTypes, whileInitVals);
  {
    Block *condBlock = &whileOp.getCond().emplaceBlock();
    whileOp.getCond().addArguments(whileArgTypes, whileBbArgLocs);
    b.setInsertionPointToStart(condBlock);
    Value curPow = condBlock->getArgument(0);
    Value curBase = condBlock->getArgument(1);
    Value curExp = condBlock->getArgument(2);
    Value cmp = bExt.genCmp(yul::CmpPredicate::ugt, curExp, one);
    b.create<yul::ConditionOp>(loc, cmp, ValueRange{curPow, curBase, curExp});
  }

  {
    Block *bodyBlock = &whileOp.getBody().emplaceBlock();
    whileOp.getBody().addArguments(whileArgTypes, whileBbArgLocs);
    b.setInsertionPointToStart(bodyBlock);
    Value curPow = bodyBlock->getArgument(0);
    Value curBase = bodyBlock->getArgument(1);
    Value curExp = bodyBlock->getArgument(2);
    {
      Value tmpDiv = b.create<yul::DivOp>(loc, maxPow, curBase);
      Value panicCond = bExt.genCmp(yul::CmpPredicate::ugt, curBase, tmpDiv);
      evmB.genPanic(mlir::evm::PanicCode::UnderOverflow, panicCond);
    }
    Value lsb = b.create<yul::AndOp>(loc, curExp, one);
    Value zero = bExt.genI256Const(0, loc);
    Value expIsOdd = bExt.genCmp(yul::CmpPredicate::ne, lsb, zero);
    Value newPow =
        b.create<yul::ArithSelectOp>(
             loc, expIsOdd, b.create<yul::MulOp>(loc, curPow, curBase), curPow)
            .getResult();
    Value newBase = b.create<yul::MulOp>(loc, curBase, curBase);
    Value newExp = b.create<yul::ArithShrOp>(loc, curExp, one);
    b.create<yul::YieldOp>(loc, ValueRange{newPow, newBase, newExp});
  }

  return {whileOp.getResult(0), whileOp.getResult(1)};
}

// Implements:
//
//   function checked_exp_unsigned(base, exponent, max) -> power {
//     if iszero(exponent) { power := 1 leave }
//     if iszero(base) { power := 0 leave }
//     switch base
//     case 1 { power := 1 leave }
//     case 2
//     {
//       if gt(exponent, 255) { panic_error_0x11() }
//       power := exp(2, exponent)
//       if gt(power, max) { panic_error_0x11() }
//       leave
//     }
//     if or(and(lt(base, 11), lt(exponent, 78)),
//           and(lt(base, 307), lt(exponent, 32)))
//     {
//       power := exp(base, exponent)
//       if gt(power, max) { panic_error_0x11() }
//       leave
//     }
//     power, base := checked_exp_helper(1, base, exponent, max)
//     if gt(power, div(max, base)) { panic_error_0x11() }
//     power := mul(power, base)
//   }
Value Lowering::genExpUnsigned(sol::CExpOp op, Value base, Value exp) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  IntegerType i256Ty = b.getIntegerType(256);
  auto ty = cast<IntegerType>(op.getType());
  Value max256 =
      bExt.genI256Const(llvm::APInt::getMaxValue(ty.getWidth()), ty, loc);
  Value zero = bExt.genI256Const(0, loc);
  Value one = bExt.genI256Const(1, loc);

  auto expEqZero = bExt.genCmp(yul::CmpPredicate::eq, exp, zero);
  auto baseEqOne = bExt.genCmp(yul::CmpPredicate::eq, base, one);
  auto powOneCond = b.create<yul::OrOp>(loc, expEqZero, baseEqOne);

  // If 1 begin
  auto ifExpEqZero = bExt.createIf(i256Ty, powOneCond);
  // If 1 then
  b.setInsertionPointToStart(&ifExpEqZero.getThenRegion().front());
  b.create<yul::YieldOp>(loc, one);

  // If 1 else
  b.setInsertionPointToStart(&ifExpEqZero.getElseRegion().front());
  auto baseEqZero = bExt.genCmp(yul::CmpPredicate::eq, base, zero);

  // If 2 begin
  auto ifBaseEqZero = bExt.createIf(i256Ty, baseEqZero);
  // If 2 then
  b.setInsertionPointToStart(&ifBaseEqZero.getThenRegion().front());
  b.create<yul::YieldOp>(loc, zero);

  // If 2 else
  b.setInsertionPointToStart(&ifBaseEqZero.getElseRegion().front());
  Value two = bExt.genI256Const(2, loc);
  auto baseEqTwo = bExt.genCmp(yul::CmpPredicate::eq, base, two);

  // If 3 begin
  auto ifBaseEqTwo = bExt.createIf(i256Ty, baseEqTwo);
  // If 3 then
  b.setInsertionPointToStart(&ifBaseEqTwo.getThenRegion().front());
  {
    auto expGt255 =
        bExt.genCmp(yul::CmpPredicate::ugt, exp, bExt.genI256Const(255, loc));
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow, expGt255);

    auto two256 = bExt.genI256Const(2, loc);
    Value tmpPow = b.create<yul::ExpOp>(loc, two256, exp);
    auto panicCond = bExt.genCmp(yul::CmpPredicate::ugt, tmpPow, max256);
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow, panicCond);

    b.create<yul::YieldOp>(loc, tmpPow);
  }
  // If 3 else
  b.setInsertionPointToStart(&ifBaseEqTwo.getElseRegion().front());
  auto baseLT11 =
      bExt.genCmp(yul::CmpPredicate::ult, base, bExt.genI256Const(11, loc));
  Value baseLT307 = (ty.getWidth() > 8)
                        ? bExt.genCmp(yul::CmpPredicate::ult, base,
                                      bExt.genI256Const(307, loc))
                        : bExt.genBool(true, loc);

  auto expLT78 =
      bExt.genCmp(yul::CmpPredicate::ult, exp, bExt.genI256Const(78, loc));
  auto expLT32 =
      bExt.genCmp(yul::CmpPredicate::ult, exp, bExt.genI256Const(32, loc));

  auto viaExpBuitinCond =
      b.create<yul::OrOp>(loc, b.create<yul::AndOp>(loc, baseLT11, expLT78),
                          b.create<yul::AndOp>(loc, baseLT307, expLT32));
  // If 4 begin
  auto ifViaExpBuitinCond = bExt.createIf(i256Ty, viaExpBuitinCond);
  // If 4 then
  b.setInsertionPointToStart(&ifViaExpBuitinCond.getThenRegion().front());

  {
    Value tmpPow = b.create<yul::ExpOp>(loc, base, exp);
    Value panicCond = bExt.genCmp(yul::CmpPredicate::ugt, tmpPow, max256);
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow, panicCond);

    b.create<yul::YieldOp>(loc, tmpPow);
  }
  // If 4 else
  b.setInsertionPointToStart(&ifViaExpBuitinCond.getElseRegion().front());
  auto [pow2, base2] = genExpHelper(loc, one, base, exp, max256);

  {
    b.setInsertionPointToEnd(&ifViaExpBuitinCond.getElseRegion().front());
    Value tmpDiv = b.create<yul::DivOp>(loc, max256, base2);
    Value panicCond = bExt.genCmp(yul::CmpPredicate::ugt, pow2, tmpDiv);
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow, panicCond);
    Value res = b.create<yul::MulOp>(loc, base2, pow2);
    b.create<yul::YieldOp>(loc, res);
  }
  // If 4 (ifViaExpBuitinCond) end
  b.setInsertionPointToEnd(&ifBaseEqTwo.getElseRegion().front());
  b.create<yul::YieldOp>(loc, ifViaExpBuitinCond.getResult(0));
  // If 3 (ifBaseEqTwo) end

  b.setInsertionPointToEnd(&ifBaseEqZero.getElseRegion().front());
  b.create<yul::YieldOp>(loc, ifBaseEqTwo.getResult(0));
  // If 2 (ifBaseEqZero) end

  b.setInsertionPointToEnd(&ifExpEqZero.getElseRegion().front());
  b.create<yul::YieldOp>(loc, ifBaseEqZero.getResult(0));
  // If 1 (ifExpEqZero) end

  return ifExpEqZero.getResult(0);
}

// Implements:
//
//   function checked_exp_signed(base, exponent, min, max) -> power {
//     switch exponent
//     case 0 { power := 1 leave }
//     case 1 { power := base leave }
//     if iszero(base) { power := 0 leave }
//
//     power := 1
//     switch sgt(base, 0)
//     case 1 { if gt(base, div(max, base)) { panic_error_0x11() } }
//     case 0 { if slt(base, sdiv(max, base)) { panic_error_0x11() } }
//     if and(exponent, 1)
//     {
//       power := base
//     }
//     base := mul(base, base)
//     exponent := shift_right_1_unsigned(exponent)
//
//     power, base := checked_exp_helper(power, base, exponent, max)
//
//     if and(sgt(power, 0), gt(power, div(max, base))) { panic_error_0x11() }
//     if and(slt(power, 0), slt(power, sdiv(min, base))) { panic_error_0x11()
//     } power := mul(power, base)
//  }
Value Lowering::genExpSigned(sol::CExpOp op, Value base, Value exp) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  IntegerType i256Ty = b.getIntegerType(256);
  auto ty = cast<IntegerType>(op.getType());
  Value zero = bExt.genI256Const(0, loc);
  Value one = bExt.genI256Const(1, loc);
  Value max256 =
      bExt.genI256Const(llvm::APInt::getSignedMaxValue(ty.getWidth()), ty, loc);
  Value min256 =
      bExt.genI256Const(llvm::APInt::getSignedMinValue(ty.getWidth()), ty, loc);

  auto expEqZero = bExt.genCmp(yul::CmpPredicate::eq, exp, zero);

  // If 1 begin
  auto ifExpEqZero = bExt.createIf(i256Ty, expEqZero);
  // If 1 then
  b.setInsertionPointToStart(&ifExpEqZero.getThenRegion().front());
  b.create<yul::YieldOp>(loc, one);

  // If 1 else
  b.setInsertionPointToStart(&ifExpEqZero.getElseRegion().front());
  auto baseEqZero = bExt.genCmp(yul::CmpPredicate::eq, base, zero);

  // If 2 begin
  auto ifBaseEqZero = bExt.createIf(i256Ty, baseEqZero);
  // If 2 then
  b.setInsertionPointToStart(&ifBaseEqZero.getThenRegion().front());
  b.create<yul::YieldOp>(loc, zero);

  // If 2 else
  b.setInsertionPointToStart(&ifBaseEqZero.getElseRegion().front());
  auto expEqOne = bExt.genCmp(yul::CmpPredicate::eq, exp, one);

  // If 3 begin
  auto ifExpEqOne = bExt.createIf(i256Ty, expEqOne);
  // If 3 then
  b.setInsertionPointToStart(&ifExpEqOne.getThenRegion().front());
  b.create<yul::YieldOp>(loc, base);

  // If 3 else
  b.setInsertionPointToStart(&ifExpEqOne.getElseRegion().front());
  auto baseSgtZero = bExt.genCmp(yul::CmpPredicate::sgt, base, zero);

  // If 4 begin
  auto ifBaseSgtZero = bExt.createIf(TypeRange{}, baseSgtZero,
                                     /*withElseRegion=*/true);
  // If 4 then
  b.setInsertionPointToStart(&ifBaseSgtZero.getThenRegion().front());
  {
    Value tmpDiv = b.create<yul::DivOp>(loc, max256, base);
    Value panicCond = bExt.genCmp(yul::CmpPredicate::ugt, base, tmpDiv);
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow, panicCond);
  }
  // If 4 else
  b.setInsertionPointToStart(&ifBaseSgtZero.getElseRegion().front());
  {
    Value tmpDiv = b.create<yul::SDivOp>(loc, max256, base);
    Value panicCond = bExt.genCmp(yul::CmpPredicate::slt, base, tmpDiv);
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow, panicCond);
  }
  // If 4 end
  b.setInsertionPointAfter(ifBaseSgtZero);

  Value lsb = b.create<yul::AndOp>(loc, exp, one);
  Value expIsOdd = bExt.genCmp(yul::CmpPredicate::ne, lsb, zero);
  Value pow2 =
      b.create<yul::ArithSelectOp>(loc, expIsOdd, base, one).getResult();
  Value base2 = b.create<yul::MulOp>(loc, base, base);
  Value exp2 = b.create<yul::ArithShrOp>(loc, exp, one);
  auto [pow3, base3] = genExpHelper(loc, pow2, base2, exp2, max256);

  b.setInsertionPointToEnd(&ifExpEqOne.getElseRegion().front());
  {
    auto zero256 = bExt.genI256Const(0, loc);
    Value div = b.create<yul::DivOp>(loc, max256, base3);
    Value cmp = bExt.genCmp(yul::CmpPredicate::ugt, pow3, div);
    Value cmp2 = bExt.genCmp(yul::CmpPredicate::sgt, pow3, zero256);
    Value panicCond = b.create<yul::AndOp>(loc, cmp, cmp2);
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow, panicCond);
  }
  {
    auto zero256 = bExt.genI256Const(0, loc);
    Value div = b.create<yul::SDivOp>(loc, min256, base3);
    Value cmp = bExt.genCmp(yul::CmpPredicate::slt, pow3, div);
    Value cmp2 = bExt.genCmp(yul::CmpPredicate::slt, pow3, zero256);
    Value panicCond = b.create<yul::AndOp>(loc, cmp, cmp2);
    evmB.genPanic(mlir::evm::PanicCode::UnderOverflow, panicCond);
  }

  Value pow4 = b.create<yul::MulOp>(loc, pow3, base3);
  b.create<yul::YieldOp>(loc, pow4);
  // If 3 (ifExpEqOne) end

  b.setInsertionPointToEnd(&ifBaseEqZero.getElseRegion().front());
  b.create<yul::YieldOp>(loc, ifExpEqOne.getResult(0));
  // If 2 (ifBaseEqZero) end

  b.setInsertionPointToEnd(&ifExpEqZero.getElseRegion().front());
  b.create<yul::YieldOp>(loc, ifBaseEqZero.getResult(0));
  // If 1 (ifExpEqZero) end

  return ifExpEqZero.getResult(0);
}

Value Lowering::lower(sol::CExpOp op) {
  SmallVector<Value> cleaned = getCleaned(op);
  Value base = cleaned[0], exp = cleaned[1];
  if (cast<IntegerType>(op.getType()).isSigned())
    return genExpSigned(op, base, exp);
  return genExpUnsigned(op, base, exp);
}

//===----------------------------------------------------------------------===//
// Casts
//===----------------------------------------------------------------------===//

Value Lowering::lower(sol::CastOp op) {
  Location loc = op.getLoc();
  auto inpTyWidth = cast<IntegerType>(op.getInp().getType()).getWidth();
  auto outTyWidth = cast<IntegerType>(op.getType()).getWidth();

  Value val = lowered(op.getInp());
  // old codegen begin
  // A widening cast cleans its source width; a narrowing one is a typed view,
  // cleaned where it is consumed: comparisons, ABI and stores.
  // (Via-IR cleans in both directions).
  if (outTyWidth > inpTyWidth)
    val = evmBuilder(loc).genCleanup(op.getInp().getType(), val, loc);
  // old codegen end
  return val;
}

Value Lowering::lower(sol::AddressCastOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  Type inpTy = op.getInp().getType();
  Type outTy = op.getType();
  Value inp = lowered(op.getInp());

  if (isa<sol::FixedBytesType>(inpTy) || isa<sol::FixedBytesType>(outTy)) {
    // bytes20 -> address
    if (auto inpBytesTy = dyn_cast<sol::FixedBytesType>(inpTy)) {
      assert(inpBytesTy.getSize() == 20 &&
             "AddressCastOp only supports bytes20");
      assert(isa<sol::AddressType>(outTy));
      return b.create<yul::ArithShrOp>(loc, inp, bExt.genI256Const(96));
    }

    // address -> bytes20
    assert(cast<sol::FixedBytesType>(outTy).getSize() == 20 &&
           "AddressCastOp only supports bytes20");
    assert(isa<sol::AddressType>(inpTy));
    return b.create<yul::ArithShlOp>(loc, inp, bExt.genI256Const(96));
  }

  // old codegen begin
  // (Via-IR adds cleanup helpers around address casts),
  if (isa<IntegerType>(inpTy) || isa<IntegerType>(outTy)) {
    // uint160 -> address
    if (isa<IntegerType>(inpTy)) {
      [[maybe_unused]] auto inpIntTy = cast<IntegerType>(inpTy);
      assert(inpIntTy.getWidth() == 160 && !inpIntTy.isSigned() &&
             "AddressCastOp only supports uint160 -> address");
      assert(isa<sol::AddressType>(outTy));
    } else {
      // address -> uint160
      [[maybe_unused]] auto outIntTy = cast<IntegerType>(outTy);
      assert(isa<sol::AddressType>(inpTy) && outIntTy.getWidth() == 160 &&
             !outIntTy.isSigned() &&
             "AddressCastOp only supports address -> uint160");
    }
    return inp;
  }

  if (isa<sol::AddressType>(inpTy) && isa<sol::AddressType>(outTy))
    // address -> address (payable <-> non-payable)
    assert(cast<sol::AddressType>(inpTy).getPayable() !=
               cast<sol::AddressType>(outTy).getPayable() &&
           "AddressCastOp only supports payable <-> non-payable address casts");
  else if (!(isa<sol::AddressType>(inpTy) && isa<sol::ContractType>(outTy)) &&
           !(isa<sol::ContractType>(inpTy) && isa<sol::AddressType>(outTy)))
    llvm_unreachable("Unexpected types for AddressCastOp");
  return inp;
  // old codegen end
}

// old codegen begin
// (Via-IR adds cleanup helpers around contract casts).
Value Lowering::lower(sol::ContractCastOp op) { return lowered(op.getInp()); }
// old codegen end

// An int -> enum cast cleans the input and the output. An enum -> int cast
// cleans only the input: an enum value is always in the valid range and thus
// also valid as an int value.
Value Lowering::lower(sol::EnumCastOp op) {
  Value val = getCleaned(op)[0];
  if (isa<sol::EnumType>(op.getType()))
    val = evmBuilder(op.getLoc()).genCleanup(op.getType(), val, op.getLoc());
  return val;
}

Value Lowering::lower(sol::BytesCastOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  Type inpTy = op.getInp().getType();
  Type outTy = op.getType();
  Value inp = lowered(op.getInp());

  const bool isByteToBytes1 = isa<sol::ByteType>(inpTy) &&
                              isa<sol::FixedBytesType>(outTy) &&
                              sol::getNumBytes(outTy) == 1;
  const bool isBytes1ToByte = isa<sol::FixedBytesType>(inpTy) &&
                              sol::getNumBytes(inpTy) == 1 &&
                              isa<sol::ByteType>(outTy);
  // byte <-> bytes1 is a no-op.
  if (isByteToBytes1 || isBytes1ToByte)
    return inp;

  if (sol::isBytesLikeType(inpTy)) {
    unsigned inpBytesSize = sol::getNumBytes(inpTy);
    if (sol::isBytesLikeType(outTy)) {
      // old codegen begin
      // bytesN -> bytesM shortening is intentionally dirty for old-codegen
      // stack-slot parity. Widening must clear bytes beyond the source width.
      // (Via-IR cleans in both directions).
      if (inpBytesSize < sol::getNumBytes(outTy))
        return evmBuilder(loc).genCleanup(inpTy, inp, loc);
      return inp;
      // old codegen end
    }

    // Bytes to int
    auto shiftAmt = bExt.genI256Const(256 - (8 * inpBytesSize));
    return b.create<yul::ArithShrOp>(loc, inp, shiftAmt);
  }

  // Int to bytes
  assert(isa<IntegerType>(inpTy));
  unsigned outBytesSize = sol::getNumBytes(outTy);
  auto shiftAmt = bExt.genI256Const(256 - (8 * outBytesSize));
  return b.create<yul::ArithShlOp>(loc, inp, shiftAmt);
}

Value Lowering::lower(sol::DynBytesToFixedBytesOp op) {
  return evmBuilder(op.getLoc())
      .genDynBytesToFixedBytes(lowered(op.getInp()), op.getInp().getType(),
                               cast<sol::FixedBytesType>(op.getType()),
                               op.getLoc());
}

Value Lowering::lower(sol::FixedBytesIndexOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  unsigned numBytes =
      cast<sol::FixedBytesType>(op.getValue().getType()).getSize();
  // Only the index is cleaned. The bounds check keeps `byte` within the
  // leading numBytes bytes, and dirty bits only sit in the trailing ones.
  Value idx = evmBuilder(loc).genCleanup(op.getIndex().getType(),
                                         lowered(op.getIndex()), loc);
  Value val = lowered(op.getValue());

  // Bounds check, mirroring the legacy codegen: index >= numBytes panics
  // with ArrayOutOfBounds.
  Value oob = bExt.genCmp(yul::CmpPredicate::uge, idx,
                          bExt.genI256Const(numBytes, loc), loc);
  evmBuilder(loc).genPanic(mlir::evm::PanicCode::ArrayOutOfBounds, oob, loc);

  // `byte(idx, val)` extracts the idx-th byte (from the MSB) right-aligned;
  // shift it left by 248 bits to left-align it as a bytes1 value.
  Value byteVal = b.create<yul::ByteOp>(loc, idx, val);
  return b.create<yul::ShlOp>(loc, bExt.genI256Const(248, loc), byteVal);
}

Value Lowering::lower(sol::ExtFuncConstantOp op) {
  Location loc = op.getLoc();
  Value undef = b.create<LLVM::UndefOp>(loc, evm::getYulType(op.getType()));
  Value selector = solgen::BuilderExt(b, loc).genI256Const(op.getSelector());
  Value withAddr = b.create<LLVM::InsertValueOp>(
      loc, undef, lowered(op.getAddr()), b.getDenseI64ArrayAttr({0}));
  return b.create<LLVM::InsertValueOp>(loc, withAddr, selector,
                                       b.getDenseI64ArrayAttr({1}));
}

Value Lowering::lower(sol::ExtFuncAddrOp op) {
  return genPairField(lowered(op.getFunc()), 0, op.getLoc());
}

Value Lowering::lower(sol::ExtFuncSelectorOp op) {
  Location loc = op.getLoc();
  // The bytes4 result is MSB-aligned: bits [255:224] are the selector.
  Value sel = genPairField(lowered(op.getFunc()), 1, loc);
  return b.create<yul::ArithShlOp>(
      loc, sel, solgen::BuilderExt(b, loc).genI256Const(224));
}

//===----------------------------------------------------------------------===//
// Crypto
//===----------------------------------------------------------------------===//

Value Lowering::lower(sol::Keccak256Op op) {
  Location loc = op.getLoc();
  evm::Builder evmB = evmBuilder(loc);
  Type ty = op.getAddr().getType();
  Value addr = lowered(op.getAddr());
  Value dataLen = evmB.genLoad(addr, sol::getDataLocation(ty));
  Value dataSlot = evmB.genDataAddrPtr(addr, ty);
  return b.create<yul::Keccak256Op>(loc, dataSlot, dataLen);
}

Value Lowering::lower(sol::Erc7201Op op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);
  Type ty = op.getId().getType();
  Value id = lowered(op.getId());
  Value dataLen = evmB.genLoad(id, sol::getDataLocation(ty));
  Value dataSlot = evmB.genDataAddrPtr(id, ty);
  Value inner = b.create<yul::Keccak256Op>(loc, dataSlot, dataLen);
  Value decremented = b.create<yul::SubOp>(loc, inner, bExt.genI256Const(1));
  // The outer hash input is a single word, so it fits the scratch space.
  Value zero = bExt.genI256Const(0);
  b.create<yul::MStoreOp>(loc, zero, decremented);
  Value outer = b.create<yul::Keccak256Op>(loc, zero, bExt.genI256Const(32));
  Value mask = b.create<yul::NotOp>(loc, bExt.genI256Const(0xff));
  return b.create<yul::AndOp>(loc, outer, mask);
}

template <typename OpT>
Value Lowering::lowerHashPrecompile(OpT op, uint32_t precompileAddr) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  sol::DataLocation dataLoc = sol::DataLocation::Memory;
  Value zero = bExt.genI256Const(0);
  Value retSize = bExt.genI256Const(32);
  Value dataLen, dataSlot;
  if (isa<sol::ConstantStringType>(op.getData().getType())) {
    StringRef bytes =
        cast<sol::ConstantStringOp>(op.getData().getDefiningOp()).getValue();
    // The precompile reads the bytes only during the call, so they skip the
    // allocation a memory literal gets: they are written at the free memory
    // pointer, and the pointer does not move.
    dataSlot = evmB.genFreePtr();
    evmB.genStringLiteralData(bytes, dataSlot);
    dataLen = bExt.genI256Const(bytes.size());
  } else {
    assert(sol::getDataLocation(op.getData().getType()) == dataLoc);
    dataLen = evmB.genLoad(lowered(op.getData()), dataLoc);
    dataSlot = evmB.genDataAddrPtr(lowered(op.getData()), dataLoc);
  }

  Value gas = b.create<yul::GasOp>(loc);
  // Hashing functions store their result in scratch space (0x00-0x3f).
  Value status =
      b.create<yul::StaticCallOp>(loc, gas,
                                  /*address=*/bExt.genI256Const(precompileAddr),
                                  /*inpOffset=*/dataSlot, dataLen,
                                  /*outOffset=*/zero, /*outSize=*/retSize);

  auto statusIsZero = bExt.genCmp(yul::CmpPredicate::eq, status, zero);
  evmB.genForwardingRevert(statusIsZero);

  auto res = evmB.genLoad(zero, dataLoc);
  // A ripemd160 result is left-aligned.
  if constexpr (std::is_same_v<OpT, sol::Ripemd160Op>)
    res = b.create<yul::ShlOp>(loc, bExt.genI256Const(96), res);
  return res;
}

Value Lowering::lower(sol::EcrecoverOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  Value zero = bExt.genI256Const(0);
  Value retSize = bExt.genI256Const(32);
  Value freePtr = evmB.genFreePtr();
  Value paramsSize = bExt.genI256Const(128);
  // The precompile reads the input only during the call, so the free pointer
  // does not move.
  evmB.genABIEncoding(op.getOperandTypes(), lowered(op.getOperands()), freePtr);

  Value gas = b.create<yul::GasOp>(loc);
  // The output area must be cleared before the call: a failing ecrecover
  // cannot be detected from the status (the precompile succeeds with empty
  // returndata, leaving the output area untouched), so this zero is what
  // the caller reads back as the documented address(0) failure result.
  b.create<yul::MStoreOp>(loc, zero, zero);
  Value status =
      b.create<yul::StaticCallOp>(loc, gas,
                                  /*address=*/bExt.genI256Const(1),
                                  /*inpOffset=*/freePtr, paramsSize,
                                  /*outOffset=*/zero, /*outSize=*/retSize);

  auto statusIsZero = bExt.genCmp(yul::CmpPredicate::eq, status, zero);
  evmB.genForwardingRevert(statusIsZero);
  return evmB.genLoad(zero, sol::DataLocation::Memory);
}

//===----------------------------------------------------------------------===//
// Environment
//===----------------------------------------------------------------------===//

Value Lowering::lower(sol::SigOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  Value data = b.create<yul::CallDataLoadOp>(loc, bExt.genI256Const(0));
  // Mask to keep only the top 4 bytes (bytes4 is MSB-aligned).
  Value mask = bExt.genI256Const(llvm::APInt::getHighBitsSet(256, 32));
  return b.create<yul::AndOp>(loc, data, mask);
}

Value Lowering::lower(sol::BlockHashOp op) {
  return b.create<yul::BlockHashOp>(op.getLoc(), lowered(op.getBlockNumber()));
}

Value Lowering::lower(sol::BlobHashOp op) {
  return b.create<yul::BlobHashOp>(op.getLoc(), lowered(op.getIdx()));
}

void Lowering::lower(sol::SelfdestructOp op) {
  b.create<yul::SelfDestructOp>(op.getLoc(), getCleaned(op)[0]);
}

Value Lowering::lower(sol::LibAddrOp op) {
  return b.create<yul::LinkerSymbolOp>(op.getLoc(), op.getName());
}

// old codegen begin
// (Via-IR cleans on casts, not here).
Value Lowering::lower(sol::CodeHashOp op) {
  return b.create<yul::ExtCodeHashOp>(op.getLoc(), getCleaned(op)[0]);
}

Value Lowering::lower(sol::BalanceOp op) {
  return b.create<yul::BalanceOp>(op.getLoc(), getCleaned(op)[0]);
}
// old codegen end

void Lowering::lower(sol::AssertOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  Value negCond = bExt.genCmp(yul::CmpPredicate::eq, lowered(op.getCond()),
                              bExt.genBool(false));
  evmBuilder(loc).genPanic(evm::PanicCode::Assert, negCond);
}

void Lowering::lower(sol::RequireOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);
  Value falseVal = bExt.genBool(false);
  Value negCond =
      bExt.genCmp(yul::CmpPredicate::eq, lowered(op.getCond()), falseVal);
  if (op.getCall()) {
    assert(op.getMsg());
    evmB.genRevert(negCond, op.getArgs().getTypes(), lowered(op.getArgs()),
                   *op.getMsg());
    return;
  }
  if (op.getMsg())
    evmB.genUserRevertWithMsg(negCond, op.getMsg()->str());
  else
    evmB.genRevert(negCond);
}

//===----------------------------------------------------------------------===//
// Control flow
//===----------------------------------------------------------------------===//

void Lowering::lower(sol::IfOp op) {
  assert(op->getResults().empty() &&
         "Yul structured control flow does not support results yet");
  auto yulIf =
      b.create<yul::IfOp>(op.getLoc(), TypeRange{}, lowered(op.getCond()));
  lowerRegions(op, yulIf);
}

void Lowering::lower(sol::SwitchOp op) {
  auto yulSwitch =
      b.create<yul::SwitchOp>(op.getLoc(), TypeRange{}, lowered(op.getArg()),
                              op.getCases(), op.getCaseRegions().size());
  lowerRegions(op, yulSwitch);
}

void Lowering::lower(sol::WhileOp op) {
  lowerRegions(op,
               b.create<yul::WhileOp>(op.getLoc(), TypeRange{}, ValueRange{}));
}

void Lowering::lower(sol::DoWhileOp op) {
  lowerRegions(op, b.create<yul::DoWhileOp>(op.getLoc()));
}

void Lowering::lower(sol::ForOp op) {
  lowerRegions(op,
               b.create<yul::ForOp>(op.getLoc(), TypeRange{}, ValueRange{}));
}

void Lowering::lower(sol::ScopeOp op) {
  lowerRegions(op, b.create<yul::ScopeOp>(op.getLoc()));
}

void Lowering::lower(sol::LeaveOp op) {
  b.create<yul::LeaveScopeOp>(op.getLoc());
}

void Lowering::lower(sol::YieldOp op) {
  assert(op.getIns().empty() &&
         "Yul structured control flow does not support yielded values yet");
  b.create<yul::YieldOp>(op.getLoc());
}

void Lowering::lower(sol::ConditionOp op) {
  b.create<yul::ConditionOp>(op.getLoc(), lowered(op.getCondition()),
                             ValueRange{});
}

void Lowering::lower(sol::BreakOp op) { b.create<yul::BreakOp>(op.getLoc()); }

void Lowering::lower(sol::ContinueOp op) {
  b.create<yul::ContinueOp>(op.getLoc());
}

//===----------------------------------------------------------------------===//
// Functions
//===----------------------------------------------------------------------===//

SmallVector<Value> Lowering::lower(sol::CallOp op) {
  return genCall(op.getCalleeAttr().getAttr(), lowered(op.getOperands()),
                 op.getLoc())
      .getResults();
}

void Lowering::lower(sol::ReturnOp op) {
  b.create<yul::FuncReturnOp>(op.getLoc(), lowered(op.getOperands()));
}

//===----------------------------------------------------------------------===//
// Memory and storage
//===----------------------------------------------------------------------===//

Value Lowering::lower(sol::AllocaOp op) {
  auto ptrTy = cast<sol::PointerType>(op.getAllocType());
  return b.create<LLVM::AllocaOp>(
      op.getLoc(), LLVM::LLVMPointerType::get(b.getContext()),
      evm::getYulType(ptrTy.getPointeeType()),
      solgen::BuilderExt(b, op.getLoc()).genI256Const(1));
}

Value Lowering::lower(sol::MallocOp op) {
  Type sizeTy = op.getSize() ? op.getSize().getType() : Type{};
  Value size = op.getSize() ? lowered(op.getSize()) : Value{};
  return evmBuilder(op.getLoc())
      .genMemAlloc(op.getType(), op.getZeroInit(), {}, size, sizeTy);
}

Value Lowering::lower(sol::ArrayLitOp op) {
  return evmBuilder(op.getLoc())
      .genMemAlloc(op.getType(), false, lowered(op.getIns()), {}, Type{});
}

Value Lowering::lower(sol::StringLitOp op) {
  Location loc = op.getLoc();
  evm::Builder evmB = evmBuilder(loc);
  solgen::BuilderExt bExt(b, loc);
  StringRef lit = op.getValue();
  size_t roundedLen = llvm::alignTo(lit.size(), 32u);
  Value allocPtr = evmB.genMemAlloc(bExt.genI256Const(32 + roundedLen), loc);
  b.create<yul::MStoreOp>(loc, allocPtr, bExt.genI256Const(lit.size()));
  evmB.genStringLiteralData(
      lit, evmB.genDataAddrPtr(allocPtr, sol::DataLocation::Memory, loc), loc);
  return allocPtr;
}

Value Lowering::lower(sol::ConcatOp op) {
  Location loc = op.getLoc();
  evm::Builder evmB = evmBuilder(loc);
  solgen::BuilderExt bExt(b, loc);

  Value freePtr = evmB.genFreePtr();
  Value dstStart = b.create<yul::AddOp>(loc, freePtr, bExt.genI256Const(32));

  Value currDst = dstStart;
  for (Value arg : op.getArgs()) {
    Type ty = arg.getType();
    if (isa<sol::ConstantStringType>(ty)) {
      StringRef bytes =
          cast<sol::ConstantStringOp>(arg.getDefiningOp()).getValue();
      evmB.genStringLiteralData(bytes, currDst, loc);
      currDst =
          b.create<yul::AddOp>(loc, currDst, bExt.genI256Const(bytes.size()));
      continue;
    }

    if (auto bytesTy = dyn_cast<sol::FixedBytesType>(ty)) {
      // The bytes are cleaned so that the padding is zero.
      b.create<yul::MStoreOp>(loc, currDst,
                              evmB.genCleanup(ty, lowered(arg), loc));
      Value length = bExt.genI256Const(bytesTy.getSize());
      currDst = b.create<yul::AddOp>(loc, currDst, length);
      continue;
    }

    assert(isa<sol::StringType>(ty));
    Value length =
        evmB.genCopyStringDataToMemory(lowered(arg), ty, currDst, loc);
    currDst = b.create<yul::AddOp>(loc, currDst, length);
  }
  Value dataSize = b.create<yul::SubOp>(loc, currDst, dstStart);
  b.create<yul::MStoreOp>(loc, freePtr, dataSize);
  evmB.genFreePtrStore(currDst);
  return freePtr;
}

Value Lowering::lower(sol::GetCallDataOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  Value zero = bExt.genI256Const(0);
  if (auto strTy = dyn_cast<sol::StringType>(op.getType());
      strTy && strTy.getDataLocation() == sol::DataLocation::CallData) {
    Value callDataSz = b.create<yul::CallDataSizeOp>(loc);
    return bExt.genLLVMStruct({zero, callDataSz});
  }
  return zero;
}

Value Lowering::lower(sol::DefaultCallDataOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  Value zero = bExt.genI256Const(0);
  Value callDataSz = b.create<yul::CallDataSizeOp>(loc);
  // A slice defaults to the empty {calldatasize(), 0}, any other reference to
  // calldatasize(), an offset past valid calldata.
  if (isa<LLVM::LLVMStructType>(evm::getYulType(op.getType())))
    return bExt.genLLVMStruct({callDataSz, zero});
  return callDataSz;
}

// A storage or transient reference is a slot, and slot 0 is the default.
Value Lowering::lower(sol::DefaultStorageOp op) {
  return solgen::BuilderExt(b, op.getLoc()).genI256Const(0);
}

Value Lowering::lower(sol::PushOp op) {
  Location loc = op.getLoc();
  evm::Builder evmB = evmBuilder(loc);
  solgen::BuilderExt bExt(b, loc);
  Type inpTy = op.getInp().getType();
  // The address of the new element: a {slot, byte offset} pair for a packed
  // element, one word otherwise.
  Type resTy = evm::getYulType(op.getType());

  if (isa<sol::StringType>(inpTy))
    return evmB.genHelperCall(
        evm::helpersym::pushStorageString(/*zero=*/true),
        {lowered(op.getInp())}, resTy,
        [&](ValueRange args, Location bodyLoc) {
          return evmB.genPushVoidToString(args[0], bodyLoc);
        },
        loc);

  auto arrTy = cast<sol::ArrayType>(inpTy);
  return evmB.genHelperCall(
      evm::helpersym::pushStorageArray(arrTy), {lowered(op.getInp())}, resTy,
      [&](ValueRange args, Location bodyLoc) {
        Value slot = args[0];
        Value oldSize = b.create<yul::SLoadOp>(bodyLoc, slot);
        Value newSize = b.create<yul::AddOp>(bodyLoc, oldSize,
                                             bExt.genI256Const(1, bodyLoc));
        b.create<yul::SStoreOp>(bodyLoc, slot, newSize);
        Value dataSlot =
            evmB.genDataAddrPtr(slot, sol::DataLocation::Storage, bodyLoc);
        return evmB.genStorageEltAddr(dataSlot, oldSize, arrTy, bodyLoc);
      });
}

void Lowering::lower(sol::PushStringOp op) {
  Location loc = op.getLoc();
  evm::Builder evmB = evmBuilder(loc);
  solgen::BuilderExt bExt(b, loc);
  Value val = lowered(op.getValue());
  Value byte = isa<sol::FixedBytesType>(op.getValue().getType())
                   ? b.create<yul::ArithShrOp>(loc, val, bExt.genI256Const(248))
                         .getResult()
                   : val;
  // The helper takes the string slot and the byte, right-aligned.
  evmB.genHelperCall(
      evm::helpersym::pushStorageString(/*zero=*/false),
      {lowered(op.getAddr()), byte},
      [&](ValueRange args, Location bodyLoc) {
        evmB.genPushToString(args[0], args[1], bodyLoc);
      },
      loc);
}

void Lowering::lower(sol::PopOp op) {
  Location loc = op.getLoc();
  evm::Builder evmB = evmBuilder(loc);
  solgen::BuilderExt bExt(b, loc);
  Type inpTy = op.getInp().getType();
  Value slot = lowered(op.getInp());

  if (isa<sol::StringType>(inpTy)) {
    evmB.genHelperCall(
        evm::helpersym::popStorageString(), {slot},
        [&](ValueRange args, Location bodyLoc) {
          Value slot = args[0];
          Value data = evmB.genLoad(slot, sol::DataLocation::Storage, bodyLoc);
          Value oldSize = evmB.genStorageStringLength(data, bodyLoc);
          Value panicCond = bExt.genCmp(yul::CmpPredicate::eq, oldSize,
                                        bExt.genI256Const(0, bodyLoc), bodyLoc);
          evmB.genPanic(mlir::evm::PanicCode::EmptyArrayPop, panicCond,
                        bodyLoc);
          evmB.genPopString(slot, data, oldSize, bodyLoc);
        },
        loc);
    return;
  }

  auto arrTy = cast<sol::ArrayType>(inpTy);
  evmB.genHelperCall(
      evm::helpersym::popStorageArray(arrTy), {slot},
      [&](ValueRange args, Location bodyLoc) {
        Value slot = args[0];
        Value oldSize = evmB.genLoad(slot, sol::DataLocation::Storage, bodyLoc);
        Value panicCond = bExt.genCmp(yul::CmpPredicate::eq, oldSize,
                                      bExt.genI256Const(0, bodyLoc), bodyLoc);
        evmB.genPanic(mlir::evm::PanicCode::EmptyArrayPop, panicCond, bodyLoc);
        Value newSize = b.create<yul::SubOp>(bodyLoc, oldSize,
                                             bExt.genI256Const(1, bodyLoc));
        // The removed element is cleared before the length is written, the
        // upstream order.
        evmB.genClearStorageArrayTail(slot, arrTy, newSize, oldSize,
                                      /*isDecrement=*/true, bodyLoc);
        b.create<yul::SStoreOp>(bodyLoc, slot, newSize);
      });
}

Value Lowering::lower(sol::AddrOfOp op) {
  solgen::BuilderExt bExt(b, op.getLoc());
  Operation *sym = contr.lookupSymbol(op.getVar());
  assert(sym);
  if (auto stateVarOp = dyn_cast<sol::StateVarOp>(sym)) {
    Value slot = bExt.genI256Const(stateVarOp.getSlot());
    if (!sol::canBePacked(stateVarOp.getType()))
      return slot;
    Value offset = bExt.genI256Const(stateVarOp.getByteOffset());
    return bExt.genLLVMStruct({slot, offset});
  }
  return bExt.genI256Const(evm::getImmutableAddr(cast<sol::ImmutableOp>(sym)));
}

Value Lowering::lower(sol::GepOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  Type baseAddrTy = op.getBaseAddr().getType();
  Value baseAddr = lowered(op.getBaseAddr());
  Value idx = lowered(op.getIdx());
  Value cleanedIdx;
  auto getCleanedIdx = [&]() -> Value {
    if (!cleanedIdx)
      cleanedIdx = evmB.genCleanup(op.getIdx().getType(), idx, loc);
    return cleanedIdx;
  };
  auto genBoundsCheck = [&](Value cond,
                            std::optional<Location> locArg = std::nullopt) {
    if (op.getNoPanicBounds())
      evmB.genRevert(cond, locArg);
    else
      evmB.genPanic(mlir::evm::PanicCode::ArrayOutOfBounds, cond, locArg);
  };
  auto getInBoundsConstIdx = [&](sol::ArrayType arrTy) -> std::optional<APInt> {
    APInt constIdx;
    if (arrTy.isDynSized() ||
        !matchPattern(getCleanedIdx(), m_ConstantInt(&constIdx)) ||
        constIdx.uge(arrTy.getSize()))
      return std::nullopt;
    return constIdx;
  };
  sol::DataLocation dataLoc = sol::getDataLocation(baseAddrTy);

  switch (dataLoc) {
  case sol::DataLocation::Stack: {
    auto stkPtrTy =
        LLVM::LLVMPointerType::get(b.getContext(), evm::AddrSpace_Stack);
    return b.create<LLVM::GEPOp>(loc, /*resultType=*/stkPtrTy,
                                 /*basePtrType=*/baseAddr.getType(), baseAddr,
                                 idx);
  }

  case sol::DataLocation::Storage: {
    if (auto arrTy = dyn_cast<sol::ArrayType>(baseAddrTy)) {
      [[maybe_unused]] Type eltTy = arrTy.getEltType();
      assert((isa<IntegerType>(eltTy) || isa<sol::FixedBytesType>(eltTy) ||
              sol::isAddressLikeType(eltTy) || isa<sol::EnumType>(eltTy) ||
              isa<sol::FuncRefType>(eltTy) || isa<sol::ExtFuncRefType>(eltTy) ||
              sol::isNonPtrRefType(eltTy)) &&
             "NYI");

      // Bounds check (always for dynamic, unless an in-bounds constant index
      // for static).
      bool needsBoundsCheck = !getInBoundsConstIdx(arrTy);
      Value arrayIdx = getCleanedIdx();

      // The element address at `slot` and `index`, built at `l`: the bounds
      // check, the keccak256 of the data slot for a dynamic array, and the
      // stride or packed-slot arithmetic.
      auto genElementAddr = [&](Value slot, Value index, Location l) -> Value {
        if (needsBoundsCheck) {
          Value size = arrTy.isDynSized()
                           ? evmB.genDynSize(slot, baseAddrTy, l)
                           : bExt.genI256Const(arrTy.getSize(), l);
          auto panicCond = bExt.genCmp(yul::CmpPredicate::uge, index, size, l);
          genBoundsCheck(panicCond, l);
        }
        Value baseSlot = arrTy.isDynSized()
                             ? evmB.genDataAddrPtr(slot, baseAddrTy, l)
                             : slot;
        return evmB.genStorageEltAddr(baseSlot, index, arrTy, l);
      };

      // A bounds-checked access goes through a helper shared per array type
      // and bounds behaviour.
      if (!needsBoundsCheck)
        return genElementAddr(baseAddr, arrayIdx, loc);
      return evmB.genHelperCall(
          evm::helpersym::indexStorageArray(arrTy, op.getNoPanicBounds()),
          {baseAddr, arrayIdx}, evm::getYulType(op.getType()),
          [&](ValueRange args, Location bodyLoc) {
            return genElementAddr(args[0], args[1], bodyLoc);
          });
    }

    if (auto structTy = dyn_cast<sol::StructType>(baseAddrTy)) {
      auto constIdx = cast<yul::ConstantOp>(idx.getDefiningOp());
      uint64_t fieldIdx = constIdx.getValue().getZExtValue();
      ArrayRef<Type> memberTypes = structTy.getMemberTypes();
      assert(fieldIdx < memberTypes.size() &&
             "struct field index out of range");
      Type fieldTy = memberTypes[fieldIdx];
      auto [slotOffset, byteOffset] = structTy.getStorageMemberOffset(fieldIdx);

      // A packed field is {baseSlot + slotOffset, byteOffset}.
      if (sol::canBePacked(fieldTy)) {
        Value slot =
            b.create<yul::AddOp>(loc, baseAddr, bExt.genI256Const(slotOffset));
        return bExt.genLLVMStruct({slot, bExt.genI256Const(byteOffset)});
      }
      return b.create<yul::AddOp>(loc, baseAddr, bExt.genI256Const(slotOffset));
    }

    assert(isa<sol::StringType>(baseAddrTy) && "NYI");
    return evmB.genStringItemAddress(baseAddr, getCleanedIdx(), loc);
  }

  case sol::DataLocation::CallData:
  case sol::DataLocation::Memory: {
    if (auto arrTy = dyn_cast<sol::ArrayType>(baseAddrTy)) {
      Value addrAtIdx;

      // Don't generate out-of-bounds check for in-bounds constant indexing of
      // static arrays.
      if (std::optional<APInt> constIdx = getInBoundsConstIdx(arrTy)) {
        APInt stride = evm::getArrayEltStride(arrTy);
        addrAtIdx = b.create<yul::AddOp>(loc, baseAddr,
                                         bExt.genI256Const(*constIdx * stride));
      } else {
        Value size;
        if (arrTy.isDynSized())
          size = evmB.genDynSize(baseAddr, baseAddrTy);
        else
          size = bExt.genI256Const(arrTy.getSize());

        auto panicCond =
            bExt.genCmp(yul::CmpPredicate::uge, getCleanedIdx(), size);
        genBoundsCheck(panicCond);

        Value stride = bExt.genI256Const(evm::getArrayEltStride(arrTy));
        Value scaledIdx = b.create<yul::MulOp>(loc, getCleanedIdx(), stride);
        if (arrTy.isDynSized()) {
          Value dataAddr = evmB.genDataAddrPtr(baseAddr, baseAddrTy);
          addrAtIdx = b.create<yul::AddOp>(loc, dataAddr, scaledIdx);
        } else {
          addrAtIdx = b.create<yul::AddOp>(loc, baseAddr, scaledIdx);
        }
      }

      // A calldata element with dynamic content is reached through the ABI
      // relative-offset word in the head area.
      Type eltTy = arrTy.getEltType();
      if (dataLoc == sol::DataLocation::CallData &&
          sol::hasDynamicallySizedElt(eltTy)) {
        Value outerDataBase = arrTy.isDynSized()
                                  ? evmB.genDataAddrPtr(baseAddr, baseAddrTy)
                                  : baseAddr;
        addrAtIdx = evmB.genCalldataAccessRef(eltTy, outerDataBase, addrAtIdx,
                                              /*isNonABI=*/true, loc);
      }
      return addrAtIdx;
    }

    if (auto structTy = dyn_cast<sol::StructType>(baseAddrTy)) {
      auto idxConstOp = cast<yul::ConstantOp>(idx.getDefiningOp());
      uint64_t fieldIdx = idxConstOp.getValue().getZExtValue();

      unsigned byteOffset = 0;
      ArrayRef<Type> memberTypes = structTy.getMemberTypes();
      assert(fieldIdx < memberTypes.size() &&
             "struct field index out of range");
      if (dataLoc == sol::DataLocation::CallData) {
        for (uint64_t i = 0; i < fieldIdx; ++i)
          byteOffset += evm::getCallDataHeadSize(memberTypes[i]);
      } else {
        byteOffset = fieldIdx * 32;
      }
      Value res =
          b.create<yul::AddOp>(loc, baseAddr, bExt.genI256Const(byteOffset));

      // A dynamic member of a calldata struct is reached through its ABI
      // relative offset.
      if (dataLoc == sol::DataLocation::CallData) {
        Type memberTy = memberTypes[fieldIdx];
        if (sol::hasDynamicallySizedElt(memberTy))
          res = evmB.genCalldataAccessRef(memberTy, baseAddr, res,
                                          /*isNonABI=*/true, loc);
      }
      return res;
    }

    assert(isa<sol::StringType>(baseAddrTy));
    Value size = evmB.genDynSize(baseAddr, baseAddrTy);
    auto panicCond = bExt.genCmp(yul::CmpPredicate::uge, getCleanedIdx(), size);
    genBoundsCheck(panicCond);
    Value dataAddr = evmB.genDataAddrPtr(baseAddr, baseAddrTy);
    return b.create<yul::AddOp>(loc, dataAddr, getCleanedIdx());
  }

  default:
    llvm_unreachable("NYI");
  }
}

Value Lowering::lower(sol::MapOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);
  Value mapping = lowered(op.getMapping());
  // The mapping is a slot: the result of a sol.addr_of or a sol.map.
  assert(cast<IntegerType>(mapping.getType()).getWidth() == 256);

  Type keyTy = op.getKey().getType();
  Value slot;
  if (isa<sol::StringType>(keyTy)) {
    // keccak256(abi.encodePacked(rawBytes, slot))
    Value pos = evmB.genFreePtr(loc);
    Value dataLen =
        evmB.genCopyStringDataToMemory(lowered(op.getKey()), keyTy, pos, loc);
    Value slotAddr = b.create<yul::AddOp>(loc, pos, dataLen);
    b.create<yul::MStoreOp>(loc, slotAddr, mapping);
    Value totalLen =
        b.create<yul::AddOp>(loc, dataLen, bExt.genI256Const(0x20));
    slot = b.create<yul::Keccak256Op>(loc, pos, totalLen);
  } else {
    // keccak256(key_word, slot_word), the value-type key aligned in its word.
    auto zero = bExt.genI256Const(0);
    Value key = evmB.genCleanup(keyTy, lowered(op.getKey()), loc);
    b.create<yul::MStoreOp>(loc, zero, key);
    b.create<yul::MStoreOp>(loc, bExt.genI256Const(0x20), mapping);
    slot = b.create<yul::Keccak256Op>(loc, zero, bExt.genI256Const(0x40));
  }

  if (auto ptrTy = dyn_cast<sol::PointerType>(op.getType());
      ptrTy && ptrTy.getDataLocation() == sol::DataLocation::Storage &&
      sol::canBePacked(ptrTy.getPointeeType()))
    return bExt.genLLVMStruct({slot, bExt.genI256Const(0)});
  return slot;
}

Value Lowering::lower(sol::LoadOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  Value addr = lowered(op.getAddr());
  sol::DataLocation dataLoc = sol::getDataLocation(op.getAddr().getType());
  Type eltTy = cast<sol::PointerType>(op.getAddr().getType()).getPointeeType();

  switch (dataLoc) {
  case sol::DataLocation::Stack:
    return b.create<LLVM::LoadOp>(loc, evm::getYulType(eltTy), addr,
                                  evm::getAlignment(addr));
  case sol::DataLocation::Immutable:
    return evmB.genLoad(addr, dataLoc);
  case sol::DataLocation::CallData: {
    Value ld = evmB.genLoad(addr, dataLoc);
    if (isa<sol::ExtFuncRefType>(eltTy)) {
      evmB.genExtFuncWordValidation(ld, loc);
      ld = evmB.genExtFuncUnpack(ld, /*inStorage=*/false, loc);
    } else if (isa<IntegerType>(eltTy) || isa<sol::EnumType>(eltTy) ||
               sol::isAddressLikeType(eltTy) || sol::isBytesLikeType(eltTy)) {
      ld = evmB.genCleanup(eltTy, ld, loc, dataLoc);
    }
    return ld;
  }
  case sol::DataLocation::Memory: {
    Value ld = evmB.genLoad(addr, dataLoc);
    // old codegen begin
    // (Via-IR cleans every memory load).
    if (isa<sol::ByteType>(eltTy))
      ld = evmB.genCleanup(eltTy, ld, loc, dataLoc);
    // old codegen end
    if (isa<sol::ExtFuncRefType>(eltTy))
      ld = evmB.genExtFuncUnpack(ld, /*inStorage=*/false, loc);
    return ld;
  }
  case sol::DataLocation::Storage:
  case sol::DataLocation::Transient: {
    if (!sol::canBePacked(eltTy))
      return evmB.genLoad(addr, dataLoc);

    // A packed value is at {slot, byte offset}: the slot shifted right by
    // offset * 8, cleaned.
    Value slot = genPairField(addr, 0, loc);
    Value offset = genPairField(addr, 1, loc);
    Value slotVal = evmB.genLoad(slot, dataLoc);
    Value shiftBits = b.create<yul::MulOp>(loc, offset, bExt.genI256Const(8));
    Value shifted = b.create<yul::ArithShrOp>(loc, slotVal, shiftBits);
    return evmB.genCleanupPackedStorageValue(eltTy, shifted, loc);
  }
  }
  llvm_unreachable("unexpected data location");
}

Value Lowering::lower(sol::LoadImmutableOp op) {
  return b.create<yul::LoadImmutableOp>(op.getLoc(), op.getName());
}

void Lowering::lower(sol::StoreOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  Value val = lowered(op.getVal());
  Value addr = lowered(op.getAddr());
  sol::DataLocation dataLoc = sol::getDataLocation(op.getAddr().getType());
  Type eltTy = cast<sol::PointerType>(op.getAddr().getType()).getPointeeType();

  switch (dataLoc) {
  case sol::DataLocation::Stack:
    b.create<LLVM::StoreOp>(loc, val, addr, evm::getAlignment(addr));
    return;
  case sol::DataLocation::Immutable:
  case sol::DataLocation::Memory: {
    if (isa<sol::ByteType>(eltTy) && dataLoc == sol::DataLocation::Memory) {
      auto byteVal = b.create<yul::ByteOp>(loc, bExt.genI256Const(0), val);
      b.create<yul::MStore8Op>(loc, addr, byteVal);
      return;
    }

    if (isa<sol::ExtFuncRefType>(eltTy))
      val = evmB.genExtFuncPack(val, /*inStorage=*/false, loc);
    else if (isa<IntegerType>(eltTy) || isa<sol::EnumType>(eltTy) ||
             sol::isAddressLikeType(eltTy) || isa<sol::FixedBytesType>(eltTy))
      val = evmB.genCleanup(eltTy, val, loc);
    evmB.genStore(val, addr, dataLoc);
    return;
  }
  case sol::DataLocation::Storage:
  case sol::DataLocation::Transient: {
    if (!sol::canBePacked(eltTy)) {
      evmB.genStore(val, addr, dataLoc);
      return;
    }

    // A packed value is at {slot, byte offset}.
    Value slot = genPairField(addr, 0, loc);
    Value offset = genPairField(addr, 1, loc);

    // An external function is cleaned by its packing, as upstream does.
    Value preparedVal = isa<sol::ExtFuncRefType>(eltTy)
                            ? val
                            : evmB.genCleanup(eltTy, val, loc);
    unsigned numBits;
    if (sol::isBytesLikeType(eltTy)) {
      // From MSB-aligned to LSB-aligned.
      numBits = sol::getNumBytes(eltTy) * 8;
      preparedVal = b.create<yul::ArithShrOp>(loc, preparedVal,
                                              bExt.genI256Const(256 - numBits));
    } else if (sol::isAddressLikeType(eltTy)) {
      numBits = 160;
    } else if (auto intTy = dyn_cast<IntegerType>(eltTy)) {
      // A packed bool occupies a byte.
      numBits = intTy.getWidth() == 1 ? 8 : intTy.getWidth();

      // Signed integer cleanup sign-extends to i256, and the slot holds only
      // the field slice.
      if (intTy.isSigned() && numBits < 256)
        preparedVal = b.create<yul::AndOp>(
            loc, preparedVal,
            bExt.genI256Const(APInt::getLowBitsSet(256, numBits)));
    } else if (isa<sol::FuncRefType>(eltTy)) {
      numBits = 64;
    } else if (isa<sol::ExtFuncRefType>(eltTy)) {
      // bytes24
      numBits = 192;
      preparedVal = evmB.genExtFuncPack(preparedVal, /*inStorage=*/true, loc);
    } else if (isa<sol::EnumType>(eltTy)) {
      // An enum has at most 256 members.
      numBits = 8;
    } else {
      llvm_unreachable("NYI");
    }

    Value shiftBits = b.create<yul::MulOp>(loc, offset, bExt.genI256Const(8));
    Value slotWithHole = evmB.genPunchHole(slot, shiftBits, numBits, dataLoc);
    preparedVal = b.create<yul::ArithShlOp>(loc, preparedVal, shiftBits);
    evmB.genStore(b.create<yul::OrOp>(loc, slotWithHole, preparedVal), slot,
                  dataLoc);
    return;
  }
  default:
    llvm_unreachable("NYI: Calldata data-location");
  }
}

Value Lowering::lower(sol::DataLocCastOp op) {
  Type srcTy = op.getInp().getType();
  assert(!isa<sol::MappingType>(srcTy));
  assert(sol::getDataLocation(op.getType()) == sol::DataLocation::Memory &&
         sol::isNonPtrRefType(srcTy) && "unexpected data location cast");

  Location loc = op.getLoc();
  evm::Builder evmB = evmBuilder(loc);
  sol::DataLocation srcDataLoc = sol::getDataLocation(srcTy);
  Value src = lowered(op.getInp());

  // A calldata struct, or a calldata array of dynamically encoded elements,
  // is copied to memory by decoding it against the end of calldata, which
  // validates every nested offset and length.
  // old codegen begin
  // Every other calldata array and bytes stays a raw copy with no checks.
  // (Via-IR decodes every calldata array copy.)
  auto srcArrTy = dyn_cast<sol::ArrayType>(srcTy);
  bool decodesFromCallData =
      isa<sol::StructType>(srcTy) ||
      (srcArrTy && sol::hasDynamicallySizedElt(srcArrTy.getEltType()));
  // old codegen end
  if (srcDataLoc != sol::DataLocation::CallData || !decodesFromCallData)
    return evmB.genCloneToMemory(srcTy, src, srcDataLoc);

  // The decoder reads a dynamic array from its length word, which precedes
  // the data of every calldata array: a slice cannot have a dynamically
  // encoded element type.
  Value addr = src;
  if (srcArrTy && srcArrTy.isDynSized())
    addr = b.create<yul::SubOp>(loc, evmB.genDataAddrPtr(src, srcTy),
                                solgen::BuilderExt(b, loc).genI256Const(32));
  return evmB.genABITupleDecoding(
      op.getType(), addr, /*fromMem=*/false,
      /*tupleEnd=*/b.create<yul::CallDataSizeOp>(loc), /*topLevel=*/false, loc);
}

Value Lowering::lower(sol::LengthOp op) {
  Type ty = op.getInp().getType();
  auto arrTy = dyn_cast<sol::ArrayType>(ty);
  assert((isa<sol::StringType>(ty) || arrTy) && "NYI");
  if (arrTy && !arrTy.isDynSized())
    return solgen::BuilderExt(b, op.getLoc()).genI256Const(arrTy.getSize());
  return evmBuilder(op.getLoc()).genDynSize(lowered(op.getInp()), ty);
}

Value Lowering::lower(sol::SliceOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  Type arrTy = op.getArr().getType();
  assert(sol::getDataLocation(arrTy) == sol::DataLocation::CallData);

  Value arr = lowered(op.getArr());
  Value start =
      evmB.genCleanup(op.getStart().getType(), lowered(op.getStart()), loc);
  Value end = evmB.genCleanup(op.getEnd().getType(), lowered(op.getEnd()), loc);

  Value dataAddr = evmB.genDataAddrPtr(arr, arrTy);
  Value length = evmB.genDynSize(arr, arrTy);

  auto startGtEnd = bExt.genCmp(yul::CmpPredicate::ugt, start, end);
  evmB.genDebugRevertWithMsg(startGtEnd, "Slice starts after end", loc);
  auto endGtLen = bExt.genCmp(yul::CmpPredicate::ugt, end, length);
  evmB.genDebugRevertWithMsg(endGtLen, "Slice is greater than length", loc);

  unsigned stride = 32;
  if (auto arrType = dyn_cast<sol::ArrayType>(arrTy))
    stride = evm::getCallDataHeadSize(arrType.getEltType());
  else if (isa<sol::StringType>(arrTy))
    stride = 1;

  Value scaledStart =
      b.create<yul::MulOp>(loc, start, bExt.genI256Const(stride));
  Value newOffset = b.create<yul::AddOp>(loc, dataAddr, scaledStart);
  Value newLength = b.create<yul::SubOp>(loc, end, start);
  return bExt.genLLVMStruct({newOffset, newLength});
}

void Lowering::lower(sol::CopyOp op) {
  Location loc = op.getLoc();
  evm::Builder evmB = evmBuilder(loc);

  if (isa<sol::ConstantStringType>(op.getSrc().getType())) {
    StringRef bytes =
        cast<sol::ConstantStringOp>(op.getSrc().getDefiningOp()).getValue();
    evmB.genCopyConstantStringToStorage(bytes, lowered(op.getDst()), loc);
    return;
  }

  Type srcTy = op.getSrc().getType();
  Type dstTy = op.getDst().getType();
  evmB.genCopy(srcTy, dstTy, lowered(op.getSrc()), lowered(op.getDst()),
               sol::getDataLocation(srcTy), sol::getDataLocation(dstTy), loc);
}

void Lowering::lower(sol::DeleteOp op) {
  Type refTy = op.getReference().getType();
  assert(sol::getDataLocation(refTy) == sol::DataLocation::Storage &&
         "sol.delete expects a Storage reference");
  evmBuilder(op.getLoc())
      .genClearStorageValue(refTy, lowered(op.getReference()), op.getLoc());
}

//===----------------------------------------------------------------------===//
// ABI
//===----------------------------------------------------------------------===//

/// Returns the types the ABI encodes `tys` as, given the callee's `boundaryTys`
/// and whether it `isLibrary`: a library takes a storage reference as its
/// slot.
static SmallVector<Type> getABITypes(OpBuilder &b, TypeRange tys,
                                     TypeRange boundaryTys, bool isLibrary) {
  if (!isLibrary)
    return SmallVector<Type>(tys);
  return llvm::map_to_vector(
      llvm::zip_equal(tys, boundaryTys), [&](auto tyPair) -> Type {
        auto [ty, boundaryTy] = tyPair;
        if (sol::getDataLocation(boundaryTy) == sol::DataLocation::Storage)
          return b.getIntegerType(256);
        return ty;
      });
}

Value Lowering::lower(sol::EncodeOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  // An encoding that only the next op hashes is read before anything else
  // allocates, so it takes no memory of its own.
  Operation *user = op->hasOneUse() ? *op->user_begin() : nullptr;
  bool reserve =
      !isa_and_nonnull<sol::Keccak256Op>(user) || user != op->getNextNode();

  SmallVector<Value> ins = lowered(op.getIns());
  Value freePtr = evmB.genFreePtr();
  Value dataStart, dataEnd;
  if (op.getPacked()) {
    dataStart = b.create<yul::AddOp>(loc, freePtr, bExt.genI256Const(32));
    dataEnd = evmB.genABIEncodingPacked(op.getIns().getType(), ins, dataStart);
  } else if (op.getSelector()) {
    dataStart = b.create<yul::AddOp>(loc, freePtr, bExt.genI256Const(32));
    b.create<yul::MStoreOp>(loc, dataStart, lowered(op.getSelector()));
    Value tupleStart =
        b.create<yul::AddOp>(loc, dataStart, bExt.genI256Const(4));
    dataEnd = evmB.genABIEncoding(op.getIns().getType(), ins, tupleStart);
  } else {
    dataStart = b.create<yul::AddOp>(loc, freePtr, bExt.genI256Const(32));
    dataEnd = evmB.genABIEncoding(op.getIns().getType(), ins, dataStart);
  }
  Value dataSize = b.create<yul::SubOp>(loc, dataEnd, dataStart);
  b.create<yul::MStoreOp>(loc, freePtr, dataSize);
  if (reserve)
    evmB.genFreePtrStore(dataEnd);
  return freePtr;
}

SmallVector<Value> Lowering::lower(sol::DecodeOp op) {
  Location loc = op.getLoc();
  evm::Builder evmB = evmBuilder(loc);

  Type srcTy = op.getAddr().getType();
  auto srcStringTy = dyn_cast<sol::StringType>(srcTy);
  assert(srcStringTy &&
         "abi.decode source must be bytes memory/calldata in sol dialect");
  sol::DataLocation dataLoc = srcStringTy.getDataLocation();
  assert((dataLoc == sol::DataLocation::Memory ||
          dataLoc == sol::DataLocation::CallData) &&
         "abi.decode expects memory/calldata byte buffer");

  Value addr = lowered(op.getAddr());
  Value tupleStart = evmB.genDataAddrPtr(addr, srcTy);
  Value tupleSize = evmB.genDynSize(addr, srcTy);
  Value tupleEnd = b.create<yul::AddOp>(loc, tupleStart, tupleSize);
  std::vector<Value> results;
  evmB.genABITupleDecoding(op.getResultTypes(), tupleStart, tupleEnd, results,
                           /*fromMem=*/dataLoc == sol::DataLocation::Memory);
  return SmallVector<Value>(results.begin(), results.end());
}

void Lowering::lower(sol::EmitOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  std::vector<Value> indexedArgs;
  if (op.getSignature())
    indexedArgs.push_back(
        bExt.genI256Const(evm::keccak256AsAPInt(op.getSignature()->str())));
  for (Value arg : op.getIndexedArgs()) {
    Type ty = arg.getType();

    if (isa<sol::ConstantStringType>(ty)) {
      StringRef bytes =
          cast<sol::ConstantStringOp>(arg.getDefiningOp()).getValue();
      indexedArgs.push_back(bExt.genI256Const(evm::keccak256AsAPInt(bytes)));
      continue;
    }

    if (isa<sol::StringType, sol::ArrayType, sol::StructType>(ty)) {
      Value scratchStart = evmB.genFreePtr();
      Value scratchEnd = evmB.genABIEncodingPacked(
          TypeRange{ty}, ValueRange{lowered(arg)}, scratchStart, loc);
      Value scratchSize = b.create<yul::SubOp>(loc, scratchEnd, scratchStart);
      indexedArgs.push_back(
          b.create<yul::Keccak256Op>(loc, scratchStart, scratchSize));
      continue;
    }

    indexedArgs.push_back(
        isa<sol::ExtFuncRefType>(ty)
            ? evmB.genExtFuncPack(lowered(arg), /*inStorage=*/false, loc)
            : evmB.genCleanup(ty, lowered(arg), loc));
  }

  Value tupleStart = evmB.genFreePtr();
  Value tupleEnd =
      evmB.genABIEncoding(op.getNonIndexedArgs().getTypes(),
                          lowered(op.getNonIndexedArgs()), tupleStart);
  Value tupleSize = b.create<yul::SubOp>(loc, tupleEnd, tupleStart);
  b.create<yul::LogOp>(loc, tupleStart, tupleSize, indexedArgs);
}

void Lowering::lower(sol::RevertOp op) {
  evm::Builder evmB = evmBuilder(op.getLoc());
  if (op.getCall()) {
    assert(op.getSignature() && !op.getSignature()->empty());
    evmB.genRevert(op.getArgs().getTypes(), lowered(op.getArgs()),
                   *op.getSignature());
  } else if (op.getSignature()) {
    // An empty reason still ABI-encodes Error("").
    evmB.genUserRevertWithMsg(op.getSignature()->str());
  } else {
    evmB.genRevert(op.getLoc());
  }
}

//===----------------------------------------------------------------------===//
// External calls
//===----------------------------------------------------------------------===//

SmallVector<Value> Lowering::genExtCall(const ExtCall &call, Location loc) {
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  assert(sol::evmCanOverchargeGasForCall(mod) && "NYI");
  // TODO: The return info (solidity::frontend::ReturnInfo) assumes an EVM
  // with return data, copied with returndatacopy and returndatasize.
  assert(sol::evmSupportsReturnData(mod) && "NYI");

  SmallVector<Type> abiInputTys = getABITypes(
      b, call.ins.getTypes(), call.calleeInputTys, call.libraryCall);
  // The results decode into the types the caller holds: a calldata-typed
  // return lands in memory.
  SmallVector<Type> abiResultTys =
      getABITypes(b, call.resultTys, call.resultTys, call.libraryCall);

  unsigned totHeadSize = 0;
  for (Type resTy : abiResultTys)
    totHeadSize += evm::getCallDataHeadSize(resTy);
  bool extCodeSizeCheck = totHeadSize == 0 ||
                          !sol::evmSupportsReturnData(mod) ||
                          sol::shouldEmitDebugRevertStrings(mod);

  Value addr = call.addr;
  // old codegen begin
  // (Via-IR cleans on casts, not here).
  if (isa<sol::AddressType>(call.addrTy))
    addr = evmB.genCleanup(call.addrTy, addr, loc);
  // old codegen end

  if (extCodeSizeCheck) {
    auto extCodeSize = b.create<yul::ExtCodeSizeOp>(loc, addr);
    auto isExtCodeSizeZero =
        bExt.genCmp(yul::CmpPredicate::eq, extCodeSize, bExt.genI256Const(0));
    evmB.genDebugRevertWithMsg(isExtCodeSizeZero,
                               "Target contract does not contain code");
  }

  Value selectorAddr = evmB.genFreePtr();
  Value shiftedSelector =
      b.create<yul::ArithShlOp>(loc, call.selector, bExt.genI256Const(224));
  b.create<yul::MStoreOp>(loc, selectorAddr, shiftedSelector);

  Value tupleStart =
      b.create<yul::AddOp>(loc, selectorAddr, bExt.genI256Const(4));
  Value tupleEnd =
      evmB.genABIEncoding(abiInputTys, lowered(call.ins), tupleStart);

  // The static return size, unless it is dynamic (from
  // solidity::frontend::ReturnInfo). A struct or array with a dynamically
  // sized element encodes as a tail whose size is not static.
  unsigned staticRetSizeVal = 0;
  bool isRetSizeDynamic = false;
  for (Type ty : abiResultTys) {
    if (sol::hasDynamicallySizedElt(ty)) {
      isRetSizeDynamic = true;
      staticRetSizeVal = 0;
      break;
    }
    staticRetSizeVal += evm::getCallDataHeadSize(ty);
  }

  Value inpSize = b.create<yul::SubOp>(loc, tupleEnd, selectorAddr);
  Value staticRetSize = bExt.genI256Const(staticRetSizeVal);
  // A call that names no gas forwards all the gas left, read here so that it
  // is not kept live across the encoding.
  Value gas = call.gas ? call.gas : b.create<yul::GasOp>(loc);
  Value status;
  // A delegate call may also be static, and is checked first.
  if (call.delegateCall)
    status = b.create<yul::DelegateCallOp>(loc, gas, addr,
                                           /*inpOffset=*/selectorAddr, inpSize,
                                           /*outOffset=*/selectorAddr,
                                           /*outSize=*/staticRetSize);
  else if (call.staticCall)
    status = b.create<yul::StaticCallOp>(loc, gas, addr,
                                         /*inpOffset=*/selectorAddr, inpSize,
                                         /*outOffset=*/selectorAddr,
                                         /*outSize=*/staticRetSize);
  else
    status = b.create<yul::CallOp>(loc, gas, addr, call.val,
                                   /*inpOffset=*/selectorAddr, inpSize,
                                   /*outOffset=*/selectorAddr,
                                   /*outSize=*/staticRetSize);

  // A try call leaves a failure to the try's clauses.
  if (!call.tryCall) {
    auto statusIsZero =
        bExt.genCmp(yul::CmpPredicate::eq, status, bExt.genI256Const(0));
    evmB.genForwardingRevert(statusIsZero);
  }

  SmallVector<Type> decodedResultTys =
      llvm::map_to_vector(call.resultTys, evm::getYulType);

  // The results are decoded on success. A failure yields undefs that
  // execution never reads: it either skips the try's success clause or has
  // reverted.
  auto statusIsNotZero =
      bExt.genCmp(yul::CmpPredicate::ne, status, bExt.genI256Const(0));
  auto statusIfOp = b.create<yul::IfOp>(loc, /*resultTys=*/decodedResultTys,
                                        /*cond=*/statusIsNotZero);
  OpBuilder::InsertionGuard guard(b);
  b.setInsertionPointToStart(&statusIfOp.getElseRegion().emplaceBlock());
  SmallVector<Value, 2> undefYields;
  for (Type ty : decodedResultTys)
    undefYields.push_back(b.create<LLVM::UndefOp>(loc, ty));
  b.create<yul::YieldOp>(loc, undefYields);

  // The return data reuses the memory at `selectorAddr`.
  b.setInsertionPointToStart(&statusIfOp.getThenRegion().emplaceBlock());
  std::vector<Value> decodedResults;
  if (isRetSizeDynamic) {
    Value retDataSize = b.create<yul::ReturnDataSizeOp>(loc);
    b.create<yul::ReturnDataCopyOp>(loc, selectorAddr,
                                    /*src=*/bExt.genI256Const(0), retDataSize);
    evmB.genFreePtrUpd(selectorAddr, retDataSize);
    Value tupleEnd = b.create<yul::AddOp>(loc, selectorAddr, retDataSize);
    evmB.genABITupleDecoding(abiResultTys, selectorAddr, tupleEnd,
                             decodedResults, /*fromMem=*/true);
  } else {
    // See https://github.com/ethereum/solidity/pull/12684: the tuple is the
    // return data up to the static size, so return data shorter than that
    // fails the tuple's size check, and the tuple is otherwise exactly the
    // static size.
    if (staticRetSizeVal) {
      Value retDataSize = b.create<yul::ReturnDataSizeOp>(loc);
      Value tooShort =
          bExt.genCmp(yul::CmpPredicate::ult, retDataSize, staticRetSize);
      evmB.genDebugRevertWithMsg(tooShort,
                                 "ABI decoding: tuple data too short");
    }
    // Scalar results are decoded onto the stack right away, so the return
    // data needs no memory of its own.
    if (!llvm::all_of(abiResultTys, [](Type ty) { return sol::isScalar(ty); }))
      evmB.genFreePtrUpd(selectorAddr, staticRetSize);
    Value tupleEnd = b.create<yul::AddOp>(loc, selectorAddr, staticRetSize);
    evmB.genABITupleDecoding(abiResultTys, selectorAddr, tupleEnd,
                             decodedResults, /*fromMem=*/true);
  }
  b.create<yul::YieldOp>(loc, decodedResults);

  SmallVector<Value> results{statusIsNotZero};
  llvm::append_range(results, statusIfOp.getResults());
  return results;
}

SmallVector<Value> Lowering::lower(sol::ExtCallOp op) {
  ExtCall call{op.getIns(),
               op.getCalleeType().getInputs(),
               TypeRange(op.getResultTypes()).drop_front(),
               lowered(op.getAddr()),
               op.getAddr().getType(),
               lowered(op.getSelector()),
               op.getGas() ? lowered(op.getGas()) : Value{},
               op.getVal() ? lowered(op.getVal()) : Value{},
               op.getTryCall(),
               op.getStaticCall(),
               op.getDelegateCall(),
               op.getLibraryCall()};
  return genExtCall(call, op.getLoc());
}

SmallVector<Value> Lowering::lower(sol::ExtICallOp op) {
  Location loc = op.getLoc();
  Value callee = lowered(op.getCallee());
  Value addr = genPairField(callee, 0, loc);
  Value selector = genPairField(callee, 1, loc);
  FunctionType calleeTy =
      cast<sol::ExtFuncRefType>(op.getCallee().getType()).getFuncTy();
  ExtCall call{op.getCalleeOperands(),
               calleeTy.getInputs(),
               TypeRange(op.getResultTypes()).drop_front(),
               addr,
               addr.getType(),
               selector,
               op.getGas() ? lowered(op.getGas()) : Value{},
               op.getValue() ? lowered(op.getValue()) : Value{},
               op.getTryCall(),
               op.getStaticCall(),
               /*delegateCall=*/false,
               /*libraryCall=*/false};
  return genExtCall(call, loc);
}

template <typename YulCallOpT, typename OpT>
SmallVector<Value> Lowering::lowerBareCall(OpT op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);
  assert(sol::evmSupportsReturnData(mod) && "NYI");

  Value inpSize, inpStart;
  if (isa<sol::ConstantStringType>(op.getInp().getType())) {
    StringRef bytes =
        cast<sol::ConstantStringOp>(op.getInp().getDefiningOp()).getValue();
    // The callee reads the input only during the call, so it skips the
    // allocation a memory literal gets: it is written at the free memory
    // pointer, and the pointer does not move.
    inpStart = evmB.genFreePtr(loc);
    evmB.genStringLiteralData(bytes, inpStart, loc);
    inpSize = bExt.genI256Const(bytes.size());
  } else {
    auto inpTy = cast<sol::StringType>(op.getInp().getType());
    inpSize = evmB.genDynSize(lowered(op.getInp()), inpTy, loc);
    inpStart = evmB.genDataAddrPtr(lowered(op.getInp()), inpTy, loc);
  }
  // old codegen begin
  // (Via-IR cleans on casts, not here).
  Value addr =
      evmB.genCleanup(op.getAddr().getType(), lowered(op.getAddr()), loc);
  // old codegen end
  Value zero = bExt.genI256Const(0);
  // A call that names no gas forwards all the gas left, read here so that it
  // is not kept live across the input size and address computation.
  Value gas = op.getGas() ? lowered(op.getGas()) : b.create<yul::GasOp>(loc);
  Value rawStatus;
  if constexpr (std::is_same_v<YulCallOpT, yul::CallOp>)
    rawStatus = b.create<yul::CallOp>(loc, gas, addr, lowered(op.getVal()),
                                      /*inpOffset=*/inpStart, inpSize,
                                      /*outOffset=*/zero, /*outSize=*/zero);
  else
    rawStatus = b.create<YulCallOpT>(loc, gas, addr, /*inpOffset=*/inpStart,
                                     inpSize, /*outOffset=*/zero,
                                     /*outSize=*/zero);

  Value status = bExt.genCmp(yul::CmpPredicate::ne, rawStatus, zero);
  // Return data nobody reads is not copied, whatever its size.
  Value retData = op.getRetData().use_empty()
                      ? bExt.genI256Const(mlir::evm::MemoryLayout::zeroPointer)
                      : evmB.genReturnDataBytes(loc);
  return {status, retData};
}

template <typename OpT>
Value Lowering::genValueTransferStatus(OpT op, yul::CmpPredicate pred) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);
  Value val = lowered(op.getVal());
  Value zero = bExt.genI256Const(0);
  Value callStipend = bExt.genI256Const(2300);
  Value valueIsZero = bExt.genCmp(yul::CmpPredicate::eq, val, zero);
  Value gas = b.create<yul::ArithSelectOp>(loc, valueIsZero, callStipend, zero);
  // old codegen begin
  // (Via-IR cleans on casts, not here).
  Value addr =
      evmB.genCleanup(op.getAddr().getType(), lowered(op.getAddr()), loc);
  // old codegen end
  Value callStatus = b.create<yul::CallOp>(loc, gas, addr, val,
                                           /*inpOffset=*/zero, /*inpSize=*/zero,
                                           /*outOffset=*/zero,
                                           /*outSize=*/zero);
  return bExt.genCmp(pred, callStatus, zero);
}

Value Lowering::lower(sol::SendOp op) {
  return genValueTransferStatus(op, yul::CmpPredicate::ne);
}

void Lowering::lower(sol::TransferOp op) {
  Value statusIsZero = genValueTransferStatus(op, yul::CmpPredicate::eq);
  evmBuilder(op.getLoc()).genForwardingRevert(statusIsZero);
}

Value Lowering::lower(sol::NewOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  Value bytecodeAddr = evmB.genFreePtr();
  Value dataOffset = b.create<yul::DataOffsetOp>(loc, op.getObjName());
  Value dataSize = b.create<yul::DataSizeOp>(loc, op.getObjName());
  b.create<yul::CodeCopyOp>(loc, bytecodeAddr, dataOffset, dataSize);

  Value tupleStart = b.create<yul::AddOp>(loc, bytecodeAddr, dataSize);
  Value tupleEnd = evmB.genABIEncoding(op.getCtorArgs().getType(),
                                       lowered(op.getCtorArgs()), tupleStart);
  Value allocSize = b.create<yul::SubOp>(loc, tupleEnd, bytecodeAddr);

  Value addr;
  if (op.getSalt())
    addr = b.create<yul::Create2Op>(loc, lowered(op.getVal()), bytecodeAddr,
                                    allocSize, lowered(op.getSalt()));
  else
    addr = b.create<yul::CreateOp>(loc, lowered(op.getVal()), bytecodeAddr,
                                   allocSize);

  if (!op.getTryCall()) {
    Value zero = bExt.genI256Const(0);
    Value addrIsZero = bExt.genCmp(yul::CmpPredicate::eq, addr, zero);
    evmB.genForwardingRevert(addrIsZero);
  }
  return addr;
}

Value Lowering::lower(sol::ObjectCodeOp op) {
  Location loc = op.getLoc();
  evm::Builder evmB = evmBuilder(loc);
  Value dataSize = b.create<yul::DataSizeOp>(loc, op.getObjName());
  Value alloc = evmB.genMemAlloc(op.getType(), /*zeroInit=*/false,
                                 /*initVals=*/{}, dataSize, Type{});
  Value dataAddr = evmB.genDataAddrPtr(alloc, sol::DataLocation::Memory);
  Value dataOffset = b.create<yul::DataOffsetOp>(loc, op.getObjName());
  b.create<yul::CodeCopyOp>(loc, dataAddr, dataOffset, dataSize);
  return alloc;
}

// old codegen begin
// (Via-IR cleans on casts, not here).
Value Lowering::lower(sol::CodeOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);
  Value addr = getCleaned(op)[0];

  auto extCodeSize = b.create<yul::ExtCodeSizeOp>(loc, addr);
  Value alloc = evmB.genFreePtr();
  b.create<yul::MStoreOp>(loc, alloc, extCodeSize);
  auto codeAddr = evmB.genDataAddrPtr(alloc, sol::DataLocation::Memory);
  b.create<yul::ExtCodeCopyOp>(loc, addr, /*dstOffset=*/codeAddr,
                               /*srcOffset=*/bExt.genI256Const(0), extCodeSize);
  evmB.genFreePtrStore(b.create<yul::AddOp>(loc, codeAddr, extCodeSize));
  return alloc;
}
// old codegen end

Value Lowering::lower(sol::CodeSizeOp op) {
  return b.create<yul::ExtCodeSizeOp>(op.getLoc(), getCleaned(op)[0]);
}

//===----------------------------------------------------------------------===//
// Try
//===----------------------------------------------------------------------===//

// The status picks the success clause or the failure path. A failure whose
// return data starts with the selector of a caught Panic(uint256) or
// Error(string) runs that clause; any other failure runs the fallback clause,
// or reverts with the return data when there is none. The clauses are lowered
// once the code around them is.
void Lowering::lower(sol::TryOp op) {
  Location loc = op.getLoc();
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);

  SmallVector<Clause, 4> clauses;

  auto ifStatus =
      b.create<yul::IfOp>(loc, TypeRange{}, lowered(op.getStatus()));
  assert(!op.getSuccessRegion().empty() && "a try has a success clause");
  clauses.push_back({&op.getSuccessRegion(),
                     &ifStatus.getThenRegion().emplaceBlock(),
                     &ifStatus.getThenRegion()});

  Block *failure = &ifStatus.getElseRegion().emplaceBlock();
  b.setInsertionPointToStart(failure);
  if (op.getFallbackRegion().empty()) {
    evmB.genForwardingRevert();
  } else {
    // The fallback clause's parameter is the return data as `bytes memory`.
    Block &fallback = op.getFallbackRegion().front();
    if (fallback.getNumArguments() > 0) {
      BlockArgument arg = fallback.getArgument(0);
      mapLowered(arg,
                 evmBuilder(arg.getLoc()).genReturnDataBytes(arg.getLoc()));
    }
  }

  if (op.getPanicRegion().empty() && op.getErrorRegion().empty()) {
    if (!op.getFallbackRegion().empty())
      clauses.push_back(
          {&op.getFallbackRegion(), failure, &ifStatus.getElseRegion()});
    lowerClauses(clauses);
    return;
  }

  // The flag is cleared by a caught clause and keeps the fallback otherwise.
  b.setInsertionPointToStart(failure);
  auto runFallbackFlag =
      b.create<LLVM::AllocaOp>(loc, LLVM::LLVMPointerType::get(b.getContext()),
                               b.getIntegerType(256), bExt.genI256Const(1));
  auto genStoreFlag = [&](bool runFallback) {
    Value flag = bExt.genBool(runFallback);
    b.create<LLVM::StoreOp>(loc, flag, runFallbackFlag,
                            evm::getAlignment(runFallbackFlag));
  };
  genStoreFlag(true);

  // The return data holds a selector.
  auto returnDataSize = b.create<yul::ReturnDataSizeOp>(loc);
  auto selectorRetCond =
      bExt.genCmp(yul::CmpPredicate::ugt, returnDataSize, bExt.genI256Const(3));
  auto ifSelectorRet = b.create<yul::IfOp>(loc, TypeRange{}, selectorRetCond);
  // What follows in the failure block is the fallback path.
  Block::iterator fallbackPoint = b.getInsertionPoint();

  b.setInsertionPointToStart(&ifSelectorRet.getThenRegion().emplaceBlock());
  b.setInsertionPoint(b.create<yul::YieldOp>(loc));
  auto zero = bExt.genI256Const(0);
  b.create<yul::ReturnDataCopyOp>(loc, /*dst=*/zero, /*src=*/zero,
                                  /*size=*/bExt.genI256Const(4));
  auto selectorWord = b.create<yul::MLoadOp>(loc, zero);
  auto selector =
      b.create<yul::ArithShrOp>(loc, selectorWord, bExt.genI256Const(224));

  SmallVector<APInt, 2> switchSelectors;
  if (!op.getPanicRegion().empty())
    switchSelectors.emplace_back(
        /*numBits=*/256, mlir::evm::selectorFromSignature("Panic(uint256)"));
  if (!op.getErrorRegion().empty())
    switchSelectors.emplace_back(
        /*numBits=*/256, mlir::evm::selectorFromSignature("Error(string)"));
  auto switchSelectorsAttr = DenseIntElementsAttr::get(
      RankedTensorType::get(static_cast<int64_t>(switchSelectors.size()),
                            b.getIntegerType(256)),
      switchSelectors);
  auto switchOp = b.create<yul::SwitchOp>(
      loc, TypeRange{}, selector, switchSelectorsAttr, switchSelectors.size());
  b.setInsertionPointToStart(&switchOp.getDefaultRegion().emplaceBlock());
  b.create<yul::YieldOp>(loc);
  unsigned caseIdx = 0;

  if (!op.getPanicRegion().empty()) {
    b.setInsertionPointToStart(
        &switchOp.getCaseRegions()[caseIdx++].emplaceBlock());
    b.setInsertionPoint(b.create<yul::YieldOp>(loc));

    // The return data holds the panic code.
    auto panicRetCond = bExt.genCmp(yul::CmpPredicate::ugt, returnDataSize,
                                    bExt.genI256Const(0x23));
    auto ifPanicRet = b.create<yul::IfOp>(loc, TypeRange{}, panicRetCond);
    Block *panic = &ifPanicRet.getThenRegion().emplaceBlock();
    b.setInsertionPointToStart(panic);
    genStoreFlag(false);
    // The clause's parameter is the panic code at offset 4.
    BlockArgument arg = op.getPanicRegion().front().getArgument(0);
    b.create<yul::ReturnDataCopyOp>(arg.getLoc(), /*dst=*/zero,
                                    /*src=*/bExt.genI256Const(4),
                                    /*size=*/bExt.genI256Const(0x20));
    mapLowered(arg, b.create<yul::MLoadOp>(arg.getLoc(), zero));
    clauses.push_back(
        {&op.getPanicRegion(), panic, &ifPanicRet.getThenRegion()});
  }

  if (!op.getErrorRegion().empty()) {
    b.setInsertionPointToStart(
        &switchOp.getCaseRegions()[caseIdx].emplaceBlock());
    b.setInsertionPoint(b.create<yul::YieldOp>(loc));

    // Decode the ABI-encoded Error(string) like upstream's
    // try_decode_error_message. Three nested guards; a failed one leaves
    // the flag set so the fallback clause runs:
    //
    // - 0x44 = 4 (selector) + 0x20 (offset) + 0x20 (length)
    // - 0x24 = 4 (selector) + 0x20 (offset)
    // - offset is the ABI offset to the string body, read from the head.
    // - length is the string length, read at msg.
    // - dataEnd is one past the last byte of the returned tuple.
    //
    // clang-format off
    //
    //   if (returndatasize >= 0x44)
    //     if (offset <= u64Max && offset + 0x24 <= returndatasize)
    //       if (length <= u64Max && msg + 0x20 + length <= dataEnd)
    //         run the Error clause
    //
    // clang-format on
    Value sizeOk = bExt.genCmp(yul::CmpPredicate::uge, returnDataSize,
                               bExt.genI256Const(0x44));
    auto ifSizeOk = b.create<yul::IfOp>(loc, TypeRange{}, sizeOk);
    b.setInsertionPointToStart(&ifSizeOk.getThenRegion().emplaceBlock());
    b.setInsertionPoint(b.create<yul::YieldOp>(loc));
    Value u64Max = bExt.genI256Const(APInt::getLowBitsSet(256, 64));
    Value abiTupleSize =
        b.create<yul::SubOp>(loc, returnDataSize, bExt.genI256Const(4));
    Value abiTuple = evmB.genFreePtr();
    b.create<yul::ReturnDataCopyOp>(loc, /*dst=*/abiTuple,
                                    /*src=*/bExt.genI256Const(4), abiTupleSize);
    Value offset = b.create<yul::MLoadOp>(loc, abiTuple);
    Value offsetSmall = bExt.genCmp(yul::CmpPredicate::ule, offset, u64Max);
    Value offsetEnd =
        b.create<yul::AddOp>(loc, offset, bExt.genI256Const(0x24));
    Value offsetInBounds =
        bExt.genCmp(yul::CmpPredicate::ule, offsetEnd, returnDataSize);
    Value offsetOk = b.create<yul::AndOp>(loc, offsetSmall, offsetInBounds);
    auto ifOffsetOk = b.create<yul::IfOp>(loc, TypeRange{}, offsetOk);
    b.setInsertionPointToStart(&ifOffsetOk.getThenRegion().emplaceBlock());
    b.setInsertionPoint(b.create<yul::YieldOp>(loc));

    Value errMsg = b.create<yul::AddOp>(loc, abiTuple, offset);
    Value length = b.create<yul::MLoadOp>(loc, errMsg);
    Value lengthSmall = bExt.genCmp(yul::CmpPredicate::ule, length, u64Max);
    Value msgEnd = b.create<yul::AddOp>(
        loc, b.create<yul::AddOp>(loc, errMsg, bExt.genI256Const(0x20)),
        length);
    Value dataEnd = b.create<yul::AddOp>(loc, abiTuple, abiTupleSize);
    Value lengthInBounds = bExt.genCmp(yul::CmpPredicate::ule, msgEnd, dataEnd);
    Value lengthOk = b.create<yul::AndOp>(loc, lengthSmall, lengthInBounds);
    auto ifLengthOk = b.create<yul::IfOp>(loc, TypeRange{}, lengthOk);
    Block *error = &ifLengthOk.getThenRegion().emplaceBlock();
    b.setInsertionPointToStart(error);
    genStoreFlag(false);
    // The copy is reserved only once every guard passed, and only up to the
    // end of the reason.
    evmB.genFreePtrUpd(abiTuple, b.create<yul::SubOp>(loc, msgEnd, abiTuple));
    // The clause's parameter is the reason.
    mapLowered(op.getErrorRegion().front().getArgument(0), errMsg);
    clauses.push_back(
        {&op.getErrorRegion(), error, &ifLengthOk.getThenRegion()});
  }

  // The fallback path runs if the flag is still set.
  Block *fallbackPath = failure->splitBlock(fallbackPoint);
  b.setInsertionPointAfter(ifSelectorRet);
  Value runFallback =
      b.create<LLVM::LoadOp>(loc, b.getIntegerType(256), runFallbackFlag,
                             evm::getAlignment(runFallbackFlag));
  auto ifRunFallback = b.create<yul::IfOp>(loc, TypeRange{}, runFallback);
  Block *fallback = &ifRunFallback.getThenRegion().emplaceBlock();
  fallback->getOperations().splice(fallback->end(),
                                   fallbackPath->getOperations());
  fallbackPath->erase();
  b.create<yul::YieldOp>(loc);
  if (!op.getFallbackRegion().empty())
    clauses.push_back(
        {&op.getFallbackRegion(), fallback, &ifStatus.getElseRegion()});
  lowerClauses(clauses);
}

void Lowering::lowerClauses(ArrayRef<Clause> clauses) {
  OpBuilder::InsertionGuard guard(b);
  for (const Clause &clause : clauses) {
    b.setInsertionPointToEnd(clause.entry);
    lowerBlock(clause.src->front());
    for (Block &block : llvm::drop_begin(*clause.src)) {
      b.createBlock(clause.rest, clause.rest->end());
      lowerBlock(block);
    }
  }
}

//===----------------------------------------------------------------------===//
// Internal function pointers
//===----------------------------------------------------------------------===//

Value Lowering::lower(sol::FuncConstantOp op) {
  Func target = getFunc(op.getSymAttr().getAttr());
  assert(target.id && "function constant of a function without an id");
  int64_t id = *target.id;
  dispatch.addTarget(target.fn, id);
  return solgen::BuilderExt(b, op.getLoc()).genI256Const(id);
}

Value Lowering::lower(sol::DefaultFuncConstantOp op) {
  return solgen::BuilderExt(b, op.getLoc()).genI256Const(0);
}

SmallVector<Value> Lowering::lower(sol::ICallOp op) {
  Value callee = lowered(op.getCallee());
  SmallVector<Value> args = lowered(op.getOperands().drop_front());
  auto resTys = llvm::map_to_vector(op.getResultTypes(), evm::getYulType);
  // The dispatch takes the pointer ahead of the callee's arguments.
  SmallVector<Type> dispatchInputTys{callee.getType()};
  llvm::append_range(dispatchInputTys, ValueRange(args).getTypes());
  auto dispatchFnTy =
      FunctionType::get(b.getContext(), dispatchInputTys, resTys);
  args.insert(args.begin(), callee);
  return b
      .create<yul::FuncCallOp>(
          op.getLoc(), resTys,
          FlatSymbolRefAttr::get(
              dispatch.getOrCreateDispatchFn(dispatchFnTy, curFn, b)),
          args)
      .getResults();
}

//===----------------------------------------------------------------------===//
// Inline assembly
//===----------------------------------------------------------------------===//

/// Returns whether `op` has a memory effect in upstream solc's sense
/// (InlineAssemblyAnnotation::hasMemoryEffects): a builtin that reads or
/// writes memory, or an assignment to a Solidity memory variable.
static bool hasMemoryEffects(Operation *op) {
  if (auto effectOp = dyn_cast<MemoryEffectOpInterface>(op)) {
    SmallVector<MemoryEffects::EffectInstance> effects;
    effectOp.getEffectsOnResource(yul::MemoryResource::get(), effects);
    if (!effects.empty())
      return true;
  }

  auto store = dyn_cast<yul::StoreOp>(op);
  if (!store)
    return false;
  auto ptrCast = store.getPtr().getDefiningOp<sol::YulPtrCastOp>();
  if (!ptrCast)
    return false;
  auto ptrTy = cast<sol::PointerType>(ptrCast.getSrc().getType());
  return sol::getDataLocation(ptrTy.getPointeeType()) ==
         sol::DataLocation::Memory;
}

/// Returns whether `op` is memory-unsafe: not annotated memory-safe, and its
/// body has a memory effect.
static bool isMemoryUnsafe(sol::InlineAsmOp op) {
  if (op.getMemorySafe())
    return false;
  return op.getBody()
      .walk([](Operation *inner) {
        return hasMemoryEffects(inner) ? WalkResult::interrupt()
                                       : WalkResult::advance();
      })
      .wasInterrupted();
}

void Lowering::lower(sol::InlineAsmOp op) {
  // A memory-unsafe body leaves out the contract's memoryguard.
  if (!contr.getUnsafeAsm() && isMemoryUnsafe(op))
    contr.setUnsafeAsm(true);

  // The body's functions join the contract's, renamed apart from them.
  MLIRContext *ctx = b.getContext();
  Block &body = op.getBody().front();
  auto fns = llvm::to_vector(body.getOps<yul::FuncOp>());
  for (yul::FuncOp fn : fns) {
    StringAttr oldName = fn.getSymNameAttr();
    if (!SymbolTable::lookupSymbolIn(contr, oldName))
      continue;
    unsigned counter = 0;
    StringAttr uniqName = StringAttr::get(
        ctx, SymbolTable::generateSymbolName<64>(
                 oldName.getValue(),
                 [&](StringRef cand) {
                   auto candName = StringAttr::get(ctx, cand);
                   return SymbolTable::lookupSymbolIn(contr, candName) ||
                          SymbolTable::lookupSymbolIn(op, candName);
                 },
                 counter));
    [[maybe_unused]] LogicalResult replaced =
        SymbolTable::replaceAllSymbolUses(oldName, uniqName, op);
    assert(succeeded(replaced));
    SymbolTable::setSymbolName(fn, uniqName);
  }
  // A function may read a Solidity constant, so its body is lowered too.
  for (yul::FuncOp fn : fns) {
    OpBuilder::InsertionGuard guard(b);
    b.setInsertionPointToStart(contr.getBody());
    lowerRegions(fn, b.cloneWithoutRegions(*fn.getOperation(), valMap));
    fn.erase();
  }

  lowerBlock(body);
}

Value Lowering::getYulPtr(Value ptr, Location loc) {
  if (isa<yul::PtrType>(ptr.getType()))
    return ptr;
  // The Yul to LLVM IR translation reads an !llvm.ptr as a !yul.ptr through a
  // builtin.unrealized_conversion_cast.
  return b
      .create<UnrealizedConversionCastOp>(
          loc, yul::PtrType::get(b.getContext()), ptr)
      .getResult(0);
}

template <typename OpT>
Value Lowering::lowerPairFieldPtr(OpT op, int field) {
  Location loc = op.getLoc();
  auto i256Ty = b.getIntegerType(256);
  auto pairTy =
      LLVM::LLVMStructType::getLiteral(b.getContext(), {i256Ty, i256Ty});
  Value fieldPtr = b.create<LLVM::GEPOp>(
      loc, LLVM::LLVMPointerType::get(b.getContext()), pairTy,
      lowered(op.getSrc()),
      ArrayRef<LLVM::GEPArg>{LLVM::GEPArg(0), LLVM::GEPArg(field)});
  return getYulPtr(fieldPtr, loc);
}

// The `.offset` of a local storage reference is 0: its pointee is a reference
// type, the only kind Solidity admits there.
Value Lowering::lower(sol::YulStorageOffsetOp op) {
  return solgen::BuilderExt(b, op.getLoc()).genI256Const(0);
}

Value Lowering::lower(sol::YulStateVarSlotOp op) {
  auto stateVar =
      contr.lookupSymbol<sol::StateVarOp>(op.getSymAttr().getValue());
  return solgen::BuilderExt(b, op.getLoc())
      .genI256Const(stateVar.getSlot().zextOrTrunc(256));
}

Value Lowering::lower(sol::YulStateVarOffsetOp op) {
  auto stateVar =
      contr.lookupSymbol<sol::StateVarOp>(op.getSymAttr().getValue());
  return solgen::BuilderExt(b, op.getLoc())
      .genI256Const(APInt(/*numBits=*/256, stateVar.getByteOffset()));
}

//===----------------------------------------------------------------------===//
// Contract
//===----------------------------------------------------------------------===//

/// The immutable a library's runtime code compares its address with.
static constexpr const char *libAddrName = "library_deploy_address";

yul::FuncCallOp Lowering::genCall(StringAttr callee, ValueRange args,
                                  Location loc) {
  return b.create<yul::FuncCallOp>(loc, getFunc(callee).fn, args);
}

void Lowering::genCallValChk(Location loc) {
  solgen::BuilderExt bExt(b, loc);
  auto callVal = b.create<yul::CallValOp>(loc);
  auto callValChk =
      bExt.genCmp(yul::CmpPredicate::ne, callVal, bExt.genI256Const(0));
  evmBuilder(loc).genDebugRevertWithMsg(
      callValChk, "Ether sent to non-payable function", loc);
}

void Lowering::genFreePtrInit(Location loc, size_t reservedMem) {
  solgen::BuilderExt bExt(b, loc);
  int64_t start =
      mlir::evm::MemoryLayout::generalPurposeMemoryStart + reservedMem;
  Value freePtr;
  if (contr.getUnsafeAsm())
    freePtr = bExt.genI256Const(start);
  else
    freePtr = b.create<yul::MemGuardOp>(
        loc, b.getIntegerAttr(b.getIntegerType(256), start));
  b.create<yul::MStoreOp>(loc, bExt.genI256Const(64), freePtr);
}

void Lowering::genDispatch(ContractFns &fns, Location loc) {
  solgen::BuilderExt bExt(b, loc);
  bool isLibrary = contr.getKind() == sol::ContractKind::Library;

  Value notDelegateCallCond;
  if (isLibrary) {
    auto libAddr =
        b.create<yul::LoadImmutableOp>(loc, b.getIntegerType(256), libAddrName);
    auto currAddr = b.create<yul::AddressOp>(loc);
    notDelegateCallCond = bExt.genCmp(yul::CmpPredicate::eq, libAddr, currAddr);
  }

  if (fns.ifc.empty())
    return;

  // One call value test serves the whole switch when no route reachable
  // from it accepts value: the cases are the interface functions, and the
  // default falls through to the fallback. A receive function is only
  // reached with empty calldata, outside the `calldatasize >= 4` block, so
  // it does not count. A library emits no test, its functions cannot be
  // payable.
  auto isPayable = [](sol::FuncOp fn) {
    return fn.getStateMutability() == sol::StateMutability::Payable;
  };
  bool hoistCallValChk = !isLibrary && llvm::none_of(fns.ifc, isPayable) &&
                         (!fns.fallback || !isPayable(fns.fallback));

  auto callDataSz = b.create<yul::CallDataSizeOp>(loc);
  auto callDataSzCmp =
      bExt.genCmp(yul::CmpPredicate::uge, callDataSz, bExt.genI256Const(4));
  auto ifOp = bExt.createIf(callDataSzCmp);
  OpBuilder::InsertionGuard insertGuard(b);
  b.setInsertionPointToStart(&ifOp.getThenRegion().front());

  if (hoistCallValChk)
    genCallValChk(loc);

  auto callDataLd = b.create<yul::CallDataLoadOp>(loc, bExt.genI256Const(0));
  Value callDataSelector =
      b.create<yul::ArithShrOp>(loc, callDataLd, bExt.genI256Const(224));

  SmallVector<APInt, 4> selectorValues;
  for (uint32_t selector : fns.selectors)
    selectorValues.emplace_back(/*numBits=*/256, selector);
  auto selectorsAttr = DenseIntElementsAttr::get(
      RankedTensorType::get(static_cast<int64_t>(fns.selectors.size()),
                            b.getIntegerType(256)),
      selectorValues);
  auto switchOp = b.create<yul::SwitchOp>(loc, /*resultTypes=*/TypeRange{},
                                          callDataSelector, selectorsAttr,
                                          fns.selectors.size());

  {
    OpBuilder::InsertionGuard insertGuard(b);
    b.setInsertionPointToStart(b.createBlock(&switchOp.getDefaultRegion()));
    b.create<yul::YieldOp>(loc);
  }

  for (auto [caseRegion, ifcFn] :
       llvm::zip(switchOp.getCaseRegions(), fns.ifc)) {
    OpBuilder::InsertionGuard insertGuard(b);
    b.setInsertionPointToStart(b.createBlock(&caseRegion));

    // A case runs its interface function, so it is at that function's
    // location.
    Location fnLoc = evm::sourceLoc(ifcFn.getLoc());
    solgen::BuilderExt fnBExt(b, fnLoc);
    evm::Builder fnEvmB = evmBuilder(fnLoc);

    assert(ifcFn.getStateMutability());
    sol::StateMutability stateMutability = *ifcFn.getStateMutability();
    if (isLibrary) {
      assert(stateMutability != sol::StateMutability::Payable);
      if (stateMutability > sol::StateMutability::View) {
        assert(notDelegateCallCond);
        fnEvmB.genDebugRevertWithMsg(
            notDelegateCallCond,
            "Non-view function of library called without DELEGATECALL", fnLoc);
      }
    }

    if (!hoistCallValChk && !isLibrary &&
        stateMutability != sol::StateMutability::Payable)
      genCallValChk(fnLoc);

    FunctionType origIfcFnTy = *ifcFn.getOrigFnType();
    SmallVector<Type> abiInputTys = getABITypes(
        b, origIfcFnTy.getInputs(), origIfcFnTy.getInputs(), isLibrary);
    SmallVector<Type> abiResultTys = getABITypes(
        b, origIfcFnTy.getResults(), origIfcFnTy.getResults(), isLibrary);
    std::vector<Value> decodedArgs;
    if (!abiInputTys.empty())
      fnEvmB.genABITupleDecoding(abiInputTys,
                                 /*tupleStart=*/fnBExt.genI256Const(4),
                                 /*tupleEnd=*/callDataSz, decodedArgs,
                                 /*fromMem=*/false);

    auto callOp = genCall(ifcFn.getSymNameAttr(), decodedArgs, fnLoc);

    auto tupleStart = fnEvmB.genFreePtr();
    Value tupleSize;
    if (!callOp.getResultTypes().empty()) {
      auto tupleEnd =
          fnEvmB.genABIEncoding(abiResultTys, callOp.getResults(), tupleStart);
      tupleSize = b.create<yul::SubOp>(fnLoc, tupleEnd, tupleStart);
    } else {
      tupleSize = fnBExt.genI256Const(0);
    }
    b.create<yul::ReturnOp>(fnLoc, tupleStart, tupleSize);
  }
}

void Lowering::genCreationCode(sol::FuncOp ctor, StringRef runtimeObjName,
                               Location loc) {
  solgen::BuilderExt bExt(b, loc);
  SmallVector<sol::ImmutableOp, 2> immOps(
      contr.getBody()->getOps<sol::ImmutableOp>());

  genFreePtrInit(loc, immOps.size() * evm::MemoryLayout::immutableCellSize);

  // The constructor's check, argument decoding and call run the constructor,
  // so they are at its location.
  Location ctorLoc = ctor ? evm::sourceLoc(ctor.getLoc()) : loc;
  evm::Builder ctorEvmB = evmBuilder(ctorLoc);

  if (!ctor) {
    genCallValChk(loc);
  } else {
    assert(ctor.getStateMutability());
    if (*ctor.getStateMutability() != sol::StateMutability::Payable)
      genCallValChk(ctorLoc);
  }

  if (ctor && contr.getKind() != sol::ContractKind::Library) {
    std::vector<Value> decodedArgs;
    FunctionType ctorFnTy = *ctor.getOrigFnType();
    if (!ctorFnTy.getInputs().empty()) {
      auto progSize = b.create<yul::DataSizeOp>(ctorLoc, contr.getName());
      auto codeSize = b.create<yul::CodeSizeOp>(ctorLoc);
      auto argSize = b.create<yul::SubOp>(ctorLoc, codeSize, progSize);
      Value tupleStart = ctorEvmB.genMemAlloc(argSize);
      b.create<yul::CodeCopyOp>(ctorLoc, tupleStart, progSize, argSize);
      ctorEvmB.genABITupleDecoding(
          ctorFnTy.getInputs(), tupleStart,
          /*tupleEnd=*/b.create<yul::AddOp>(ctorLoc, tupleStart, argSize),
          decodedArgs, /*fromMem=*/true);
    }
    genCall(ctor.getSymNameAttr(), decodedArgs, ctorLoc);
  }

  auto freePtr = b.create<yul::MLoadOp>(loc, bExt.genI256Const(64));
  auto runtimeObjSym = FlatSymbolRefAttr::get(b.getContext(), runtimeObjName);
  auto runtimeObjOffset = b.create<yul::DataOffsetOp>(loc, runtimeObjSym);
  auto runtimeObjSize = b.create<yul::DataSizeOp>(loc, runtimeObjSym);
  b.create<yul::CodeCopyOp>(loc, freePtr, runtimeObjOffset, runtimeObjSize);

  // The runtime code of a library compares its address with this one to
  // reject a call that is not a delegate call.
  if (contr.getKind() == sol::ContractKind::Library)
    b.create<yul::SetImmutableOp>(loc, freePtr, libAddrName,
                                  b.create<yul::AddressOp>(loc));

  for (sol::ImmutableOp immOp : immOps) {
    auto addr = bExt.genI256Const(evm::getImmutableAddr(immOp));
    auto val = b.create<yul::MLoadOp>(loc, addr);
    b.create<yul::SetImmutableOp>(loc, freePtr, immOp.getName(), val);
  }

  b.create<yul::ReturnOp>(loc, freePtr, runtimeObjSize);
}

void Lowering::genRuntimeCode(ContractFns &fns, Location loc) {
  solgen::BuilderExt bExt(b, loc);
  evm::Builder evmB = evmBuilder(loc);
  genFreePtrInit(loc);
  genDispatch(fns, loc);

  if (fns.receive) {
    auto callDataSz = b.create<yul::CallDataSizeOp>(loc);
    auto callDataSzIsZero =
        bExt.genCmp(yul::CmpPredicate::eq, callDataSz, bExt.genI256Const(0));
    OpBuilder::InsertionGuard insertGuard(b);
    auto ifOp = b.create<yul::IfOp>(loc, TypeRange{}, callDataSzIsZero);
    b.setInsertionPointToStart(&ifOp.getThenRegion().emplaceBlock());
    genCall(fns.receive.getSymNameAttr(), /*args=*/{}, loc);
    b.create<yul::StopOp>(loc);
  }

  if (!fns.fallback) {
    evmB.genDebugRevertWithMsg(
        fns.receive ? "Unknown signature and no fallback defined"
                    : "Contract does not have fallback nor receive functions",
        loc);
    return;
  }

  FunctionType fallbackFnTy = fns.fallback.getFunctionType();
  // Both valid fallback forms (with and without bytes) match counts.
  assert(fallbackFnTy.getNumInputs() == fallbackFnTy.getNumResults() &&
         "fallback has mismatched parameter/return counts");

  if (fns.fallback.getStateMutability() != sol::StateMutability::Payable)
    genCallValChk(loc);

  // The `bytes calldata` parameter, when present, is the full call payload:
  // a `{offset, length}` reference of `{0, calldatasize()}`.
  SmallVector<Value, 1> fallbackArgs;
  if (fallbackFnTy.getNumInputs() == 1) {
    Value callDataSz = b.create<yul::CallDataSizeOp>(loc);
    fallbackArgs.push_back(
        bExt.genLLVMStruct({bExt.genI256Const(0), callDataSz}, loc));
  }

  auto call = genCall(fns.fallback.getSymNameAttr(), fallbackArgs, loc);

  if (fallbackFnTy.getNumResults() == 1) {
    // The returned `bytes memory` is returned verbatim, not ABI-encoded like
    // a dispatch result.
    Value ret = call.getResult(0);
    Value dataPtr = evmB.genDataAddrPtr(ret, sol::DataLocation::Memory, loc);
    Value len = b.create<yul::MLoadOp>(loc, ret);
    b.create<yul::ReturnOp>(loc, dataPtr, len);
  } else {
    b.create<yul::StopOp>(loc);
  }
}

void Lowering::lowerContract() {
  // The code generated here is at the contract's location, except the
  // dispatch cases and the constructor's part of the creation code, which are
  // at their function's.
  Location loc = contr.getLoc();

  std::string runtimeObjName = std::string(contr.getName()) + "_deployed";
  b.setInsertionPoint(contr);
  auto obj = b.create<yul::ObjectOp>(
      loc, contr.getRuntime() ? StringRef(runtimeObjName) : contr.getName());

  ContractFns fns;
  for (auto fn : contr.getBody()->getOps<sol::FuncOp>()) {
    if (auto selector = fn.getSelector()) {
      fns.selectors.push_back(*selector);
      fns.ifc.push_back(fn);
    }
    if (fn.getKind() == sol::FunctionKind::Constructor) {
      assert(!fns.ctor);
      fns.ctor = fn;
    } else if (fn.getKind() == sol::FunctionKind::Receive) {
      assert(!fns.receive);
      fns.receive = fn;
    } else if (fn.getKind() == sol::FunctionKind::Fallback) {
      assert(!fns.fallback);
      fns.fallback = fn;
    }
  }

  StringRef entryName = yul::FuncOp::entryName;
  b.setInsertionPointToStart(obj.getBody());
  auto entryFn = b.create<yul::FuncOp>(
      evm::fuseArtificialSubprogram(mod, entryName, mod.getLoc()), entryName,
      b.getFunctionType({}, {}));
  b.createBlock(&entryFn.getBody());
  if (contr.getRuntime())
    genRuntimeCode(fns, loc);
  else
    genCreationCode(fns.ctor, runtimeObjName, loc);

  for (auto fn :
       llvm::make_early_inc_range(contr.getBody()->getOps<sol::FuncOp>()))
    fn.erase();

  // The functions and the string literal globals follow the entry function,
  // the last one first, which keeps the layout of the object and so its
  // bytecode.
  for (Operation &op :
       llvm::make_early_inc_range(llvm::reverse(*contr.getBody()))) {
    if (isa<yul::FuncOp, LLVM::GlobalOp>(op))
      op.moveBefore(obj.getBody(), obj.getBody()->end());
    else
      assert((isa<sol::StateVarOp, sol::ImmutableOp>(op)));
  }

  contr.erase();
}

//===----------------------------------------------------------------------===//
// Pass
//===----------------------------------------------------------------------===//

namespace {

struct ConvertSolToYulPass
    : public impl::ConvertSolToYulPassBase<ConvertSolToYulPass> {
  void runOnOperation() override {
    ModuleOp mod = getOperation();
    // The module lowers to the object of its one contract, and a nested
    // module's contract would lower without its creation func refs.
    auto contracts = mod.getOps<sol::ContractOp>();
    if (!llvm::hasSingleElement(contracts) || !mod.getOps<ModuleOp>().empty()) {
      mod.emitOpError("expects one sol.contract and no nested module");
      signalPassFailure();
      return;
    }
    Lowering(*contracts.begin()).run();
  }
};

} // namespace
