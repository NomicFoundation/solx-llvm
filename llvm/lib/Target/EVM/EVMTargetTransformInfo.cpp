//===----------- EVMTargetTransformInfo.cpp - EVM-specific TTI -*- C++ -*--===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines the EVM-specific TargetTransformInfo
// implementation.
//
//===----------------------------------------------------------------------===//

#include "EVMTargetTransformInfo.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/IntrinsicsEVM.h"
#include "llvm/Support/KnownBits.h"
#include "llvm/Transforms/InstCombine/InstCombiner.h"
using namespace llvm;
using namespace llvm::PatternMatch;

#define DEBUG_TYPE "evmtti"

static std::optional<Instruction *> instCombineSignExtend(InstCombiner &IC,
                                                          IntrinsicInst &II) {
  // Fold signextend(b, signextend(b, x)) -> signextend(b, x)
  Value *B = nullptr, *X = nullptr;
  if (match(&II, m_Intrinsic<Intrinsic::evm_signextend>(
                     m_Value(B), m_Intrinsic<Intrinsic::evm_signextend>(
                                     m_Deferred(B), m_Value(X)))))
    return IC.replaceInstUsesWith(II, II.getArgOperand(1));

  const APInt *NumByte = nullptr;
  if (!match(II.getArgOperand(0), m_APInt(NumByte)))
    return std::nullopt;

  // Fold signextend(b, x) -> x, when b >= 31 or x already has the sign bits
  // of an (8 * b + 8)-bit value
  Value *Val = II.getArgOperand(1);
  unsigned BitWidth = II.getType()->getIntegerBitWidth();
  if (NumByte->uge(BitWidth / 8 - 1))
    return IC.replaceInstUsesWith(II, Val);
  unsigned ShiftAmt = BitWidth - (NumByte->getZExtValue() + 1) * 8;
  if (IC.ComputeNumSignBits(Val, &II) > ShiftAmt)
    return IC.replaceInstUsesWith(II, Val);

  // Fold signextend(b, lshr(x, 248 - 8 * b)) -> ashr(x, 248 - 8 * b)
  if (match(Val, m_LShr(m_Value(X), m_SpecificInt(ShiftAmt))))
    return IC.replaceInstUsesWith(II, IC.Builder.CreateAShr(X, ShiftAmt));

  return std::nullopt;
}

static std::optional<Instruction *> instCombineAddModMulMod(InstCombiner &IC,
                                                            IntrinsicInst &II) {
  Value *X = II.getArgOperand(0);
  Value *Y = II.getArgOperand(1);
  Value *Mod = II.getArgOperand(2);
  Type *Ty = II.getType();
  bool IsMulMod = II.getIntrinsicID() == Intrinsic::evm_mulmod;

  // Fold addmod/mulmod(x, y, 0 or 1) -> 0, and mulmod(0, y, m) -> 0
  if (match(Mod, m_ZeroInt()) || match(Mod, m_One()) ||
      (IsMulMod && (match(X, m_ZeroInt()) || match(Y, m_ZeroInt()))))
    return IC.replaceInstUsesWith(II, Constant::getNullValue(Ty));

  // Fold addmod(x, 0, m) -> mod(x, m), and mulmod(x, 1, m) -> mod(x, m)
  // The sum or product is x, which needs no more than 256 bits.
  auto IsIdentity = [IsMulMod](Value *V) {
    return IsMulMod ? match(V, m_One()) : match(V, m_ZeroInt());
  };
  if (IsIdentity(X) || IsIdentity(Y))
    return IC.replaceInstUsesWith(
        II, IC.Builder.CreateIntrinsic(Intrinsic::evm_mod,
                                       {IsIdentity(X) ? Y : X, Mod}));

  return std::nullopt;
}

static std::optional<Instruction *> instCombineBalance(InstCombiner &IC,
                                                       IntrinsicInst &II) {
  // Fold balance(address()) -> selfbalance()
  if (match(II.getArgOperand(0), m_Intrinsic<Intrinsic::evm_address>()))
    return IC.replaceInstUsesWith(
        II, IC.Builder.CreateIntrinsic(Intrinsic::evm_selfbalance, {}));

  return std::nullopt;
}

static std::optional<Instruction *> instCombineExp(InstCombiner &IC,
                                                   IntrinsicInst &II) {
  const APInt *Base = nullptr;
  if (!match(II.getArgOperand(0), m_APInt(Base)))
    return std::nullopt;

  Value *X = II.getArgOperand(1);
  Type *Ty = II.getType();

  // Fold exp(0, x) -> iszero(x)
  if (Base->isZero())
    return IC.replaceInstUsesWith(
        II, IC.Builder.CreateZExt(IC.Builder.CreateIsNull(X), Ty));

  // Fold exp(1, x) -> 1
  if (Base->isOne())
    return IC.replaceInstUsesWith(II, ConstantInt::get(Ty, 1));

  // Fold exp(2, x) -> shl(x, 1)
  // The EVM shift gives 0 for x >= 256, where the LLVM one is poison.
  if (*Base == 2)
    return IC.replaceInstUsesWith(
        II, IC.Builder.CreateIntrinsic(Intrinsic::evm_shl,
                                       {X, ConstantInt::get(Ty, 1)}));

  // Fold exp(-1, x) -> x is odd ? -1 : 1
  if (Base->isAllOnes()) {
    Value *IsOdd = IC.Builder.CreateTrunc(X, IC.Builder.getInt1Ty());
    return IC.replaceInstUsesWith(
        II, IC.Builder.CreateSelect(IsOdd, Constant::getAllOnesValue(Ty),
                                    ConstantInt::get(Ty, 1)));
  }

  return std::nullopt;
}

/// Returns the LLVM operation that gives the same result as the intrinsic,
/// for the operands where the LLVM one is defined.
static Instruction::BinaryOps getLLVMOpcode(Intrinsic::ID ID) {
  switch (ID) {
  case Intrinsic::evm_shl:
    return Instruction::Shl;
  case Intrinsic::evm_shr:
    return Instruction::LShr;
  case Intrinsic::evm_sar:
    return Instruction::AShr;
  case Intrinsic::evm_div:
    return Instruction::UDiv;
  case Intrinsic::evm_sdiv:
    return Instruction::SDiv;
  case Intrinsic::evm_mod:
    return Instruction::URem;
  case Intrinsic::evm_smod:
    return Instruction::SRem;
  default:
    llvm_unreachable("No LLVM operation for the intrinsic");
  }
}

static std::optional<Instruction *> instCombineShift(InstCombiner &IC,
                                                     IntrinsicInst &II) {
  Intrinsic::ID ID = II.getIntrinsicID();
  Value *Shift = II.getArgOperand(0);
  Value *Val = II.getArgOperand(1);
  Type *Ty = II.getType();
  unsigned BitWidth = Ty->getIntegerBitWidth();
  KnownBits Known = IC.computeKnownBits(Shift, &II);

  // Fold shl/shr/sar(s, x) -> x <</>> s, when s < 256
  if (Known.getMaxValue().ult(BitWidth))
    return IC.replaceInstUsesWith(
        II, IC.Builder.CreateBinOp(getLLVMOpcode(ID), Val, Shift));

  if (Known.getMinValue().uge(BitWidth)) {
    // Fold sar(s, x) -> x >> 255, when s >= 256
    if (ID == Intrinsic::evm_sar)
      return IC.replaceInstUsesWith(II,
                                    IC.Builder.CreateAShr(Val, BitWidth - 1));

    // Fold shl/shr(s, x) -> 0, when s >= 256
    return IC.replaceInstUsesWith(II, Constant::getNullValue(Ty));
  }

  return std::nullopt;
}

static std::optional<Instruction *> instCombineDivRem(InstCombiner &IC,
                                                      IntrinsicInst &II) {
  Intrinsic::ID ID = II.getIntrinsicID();
  Value *X = II.getArgOperand(0);
  Value *Y = II.getArgOperand(1);
  Type *Ty = II.getType();
  bool IsSigned = ID == Intrinsic::evm_sdiv || ID == Intrinsic::evm_smod;

  // Fold div/sdiv/mod/smod(x, 0) -> 0
  if (match(Y, m_Zero()))
    return IC.replaceInstUsesWith(II, Constant::getNullValue(Ty));

  if (IsSigned && match(Y, m_AllOnes())) {
    // Fold sdiv(x, -1) -> 0 - x
    // The negation wraps the minimum to itself, as sdiv does.
    if (ID == Intrinsic::evm_sdiv)
      return IC.replaceInstUsesWith(II, IC.Builder.CreateNeg(X));

    // Fold smod(x, -1) -> 0
    return IC.replaceInstUsesWith(II, Constant::getNullValue(Ty));
  }

  if (isKnownNonZero(Y, IC.getSimplifyQuery().getWithInstruction(&II))) {
    // Fold div/mod(x, y) -> udiv/urem(x, y), when y != 0
    if (!IsSigned)
      return IC.replaceInstUsesWith(
          II, IC.Builder.CreateBinOp(getLLVMOpcode(ID), X, Y));

    // Fold sdiv/smod(x, y) -> sdiv/srem(x, y), when y != 0 and y != -1
    // A known zero bit rules out -1.
    if (!IC.computeKnownBits(Y, &II).Zero.isZero())
      return IC.replaceInstUsesWith(
          II, IC.Builder.CreateBinOp(getLLVMOpcode(ID), X, Y));
  }

  return std::nullopt;
}

static std::optional<Instruction *> instCombineByte(InstCombiner &IC,
                                                    IntrinsicInst &II) {
  // Fold byte(i, x) -> 0, when i >= 32
  // A smaller index stays one BYTE. Its known bits and range are enough for
  // the users, and as a shift and mask its compares get wide constants.
  const APInt *Index = nullptr;
  if (match(II.getArgOperand(0), m_APInt(Index)) &&
      Index->uge(II.getType()->getIntegerBitWidth() / 8))
    return IC.replaceInstUsesWith(II, Constant::getNullValue(II.getType()));

  // Fold byte(0, x << 248) -> (x << 248) >> 248
  // The shift pair then folds to x & 255, or to x when the shift is nuw.
  unsigned BitWidth = II.getType()->getIntegerBitWidth();
  if (match(II.getArgOperand(0), m_ZeroInt()) &&
      match(II.getArgOperand(1),
            m_OneUse(m_Shl(m_Value(), m_SpecificInt(BitWidth - 8)))))
    return IC.replaceInstUsesWith(
        II, IC.Builder.CreateLShr(II.getArgOperand(1), BitWidth - 8));

  return std::nullopt;
}

std::optional<Instruction *>
EVMTTIImpl::instCombineIntrinsic(InstCombiner &IC, IntrinsicInst &II) const {
  if (II.getIntrinsicID() == Intrinsic::evm_signextend)
    return instCombineSignExtend(IC, II);

  if (II.getIntrinsicID() == Intrinsic::evm_addmod ||
      II.getIntrinsicID() == Intrinsic::evm_mulmod)
    return instCombineAddModMulMod(IC, II);

  if (II.getIntrinsicID() == Intrinsic::evm_balance)
    return instCombineBalance(IC, II);

  if (II.getIntrinsicID() == Intrinsic::evm_exp)
    return instCombineExp(IC, II);

  if (II.getIntrinsicID() == Intrinsic::evm_shl ||
      II.getIntrinsicID() == Intrinsic::evm_shr ||
      II.getIntrinsicID() == Intrinsic::evm_sar)
    return instCombineShift(IC, II);

  if (II.getIntrinsicID() == Intrinsic::evm_div ||
      II.getIntrinsicID() == Intrinsic::evm_sdiv ||
      II.getIntrinsicID() == Intrinsic::evm_mod ||
      II.getIntrinsicID() == Intrinsic::evm_smod)
    return instCombineDivRem(IC, II);

  if (II.getIntrinsicID() == Intrinsic::evm_byte)
    return instCombineByte(IC, II);

  return std::nullopt;
}

std::optional<Value *> EVMTTIImpl::simplifyDemandedUseBitsIntrinsic(
    InstCombiner &IC, IntrinsicInst &II, APInt DemandedMask, KnownBits &Known,
    bool &KnownBitsComputed) const {
  // Fold signextend(b, x) -> x, when the users read only the low 8 * b + 8
  // bits, which the extension leaves as they are
  const APInt *NumByte = nullptr;
  if (II.getIntrinsicID() == Intrinsic::evm_signextend &&
      match(II.getArgOperand(0), m_APInt(NumByte)) &&
      NumByte->ult(DemandedMask.getBitWidth() / 8 - 1) &&
      DemandedMask.getActiveBits() <= (NumByte->getZExtValue() + 1) * 8)
    return II.getArgOperand(1);

  return std::nullopt;
}

unsigned EVMTTIImpl::getAssumedAddrSpace(const Value *V) const {
  const auto *LD = dyn_cast<LoadInst>(V);
  if (!LD)
    return 0;

  return LD->getPointerAddressSpace();
}

InstructionCost EVMTTIImpl::getVectorInstrCost(unsigned Opcode, Type *Val,
                                               TTI::TargetCostKind CostKind,
                                               unsigned Index, const Value *,
                                               const Value *) const {
  InstructionCost Cost = BasicTTIImplBase::getVectorInstrCost(
      Opcode, Val, CostKind, Index, nullptr, nullptr);
  return Cost + 25 * TargetTransformInfo::TCC_Expensive;
}

void EVMTTIImpl::getUnrollingPreferences(Loop *L, ScalarEvolution &SE,
                                         TTI::UnrollingPreferences &UP,
                                         OptimizationRemarkEmitter *ORE) const {
  BaseT::getUnrollingPreferences(L, SE, UP, ORE);

  // Only allow unrolling small loops.
  UP.Threshold = 4;
  UP.MaxIterationsCountToAnalyze = 4;

  // Disable runtime, partial unrolling and unrolling using
  // trip count upper bound.
  UP.Partial = UP.Runtime = UP.UpperBound = false;
  UP.PartialThreshold = 0;

  // Avoid unrolling when optimizing for size.
  UP.OptSizeThreshold = 0;
  UP.PartialOptSizeThreshold = 0;
}

bool EVMTTIImpl::isLSRCostLess(const TargetTransformInfo::LSRCost &C1,
                               const TargetTransformInfo::LSRCost &C2) const {
  return C1.NumRegs < C2.NumRegs;
}

bool EVMTTIImpl::isNumRegsMajorCostOfLSR() const { return true; }
