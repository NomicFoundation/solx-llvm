//===-- EVMCorrelatedValuePropagation.cpp - Range-based EVM folds -*- C++ -*-=//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Simplifies EVM builtins with the value ranges LazyValueInfo derives, which
// InstCombine's known bits cannot express. An EVM division or remainder whose
// divisor is never 0, and for the signed ones never -1 with a dividend of the
// minimum, becomes the LLVM operation that gives the same result there. A sign
// extension of a value that is already sign-extended goes away.
//
//===----------------------------------------------------------------------===//

#include "EVM.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/LazyValueInfo.h"
#include "llvm/IR/ConstantRange.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/IntrinsicsEVM.h"
#include "llvm/IR/PatternMatch.h"

using namespace llvm;
using namespace llvm::PatternMatch;

#define DEBUG_TYPE "evm-correlated-propagation"

STATISTIC(NumDivRem, "Number of EVM divisions and remainders made LLVM ones");
STATISTIC(NumSignExtend, "Number of EVM sign extensions removed");

/// The LLVM operation of the EVM division or remainder `ID`.
static Instruction::BinaryOps getDivRemOpcode(Intrinsic::ID ID) {
  switch (ID) {
  case Intrinsic::evm_div:
    return Instruction::UDiv;
  case Intrinsic::evm_mod:
    return Instruction::URem;
  case Intrinsic::evm_sdiv:
    return Instruction::SDiv;
  case Intrinsic::evm_smod:
    return Instruction::SRem;
  default:
    llvm_unreachable("Not an EVM division or remainder");
  }
}

static bool processDivRem(IntrinsicInst &II, LazyValueInfo &LVI) {
  unsigned BitWidth = II.getType()->getIntegerBitWidth();
  // The divisor is noundef, so an undef one is already undefined behavior.
  ConstantRange Divisor =
      LVI.getConstantRangeAtUse(II.getOperandUse(1), /*UndefAllowed=*/true);
  if (Divisor.contains(APInt::getZero(BitWidth)))
    return false;

  Intrinsic::ID ID = II.getIntrinsicID();
  if ((ID == Intrinsic::evm_sdiv || ID == Intrinsic::evm_smod) &&
      Divisor.contains(APInt::getAllOnes(BitWidth)) &&
      LVI.getConstantRangeAtUse(II.getOperandUse(0), /*UndefAllowed=*/false)
          .contains(APInt::getSignedMinValue(BitWidth)))
    return false;

  auto *DivRem =
      BinaryOperator::Create(getDivRemOpcode(ID), II.getArgOperand(0),
                             II.getArgOperand(1), "", II.getIterator());
  DivRem->takeName(&II);
  DivRem->setDebugLoc(II.getDebugLoc());
  II.replaceAllUsesWith(DivRem);
  II.eraseFromParent();
  ++NumDivRem;
  return true;
}

// signextend(b, x) is x when x is already a sign-extended (8 * b + 8)-bit
// value.
static bool processSignExtend(IntrinsicInst &II, LazyValueInfo &LVI) {
  unsigned BitWidth = II.getType()->getIntegerBitWidth();
  const APInt *NumByte = nullptr;
  if (!match(II.getArgOperand(0), m_APInt(NumByte)) ||
      NumByte->uge(BitWidth / 8 - 1))
    return false;

  unsigned ExtendedBits = (NumByte->getZExtValue() + 1) * 8;
  APInt Min = APInt::getSignedMinValue(ExtendedBits).sext(BitWidth);
  APInt Max = APInt::getSignedMaxValue(ExtendedBits).sext(BitWidth);
  ConstantRange Value =
      LVI.getConstantRangeAtUse(II.getOperandUse(1), /*UndefAllowed=*/false);
  if (!ConstantRange(Min, Max + 1).contains(Value))
    return false;

  II.replaceAllUsesWith(II.getArgOperand(1));
  II.eraseFromParent();
  ++NumSignExtend;
  return true;
}

PreservedAnalyses
EVMCorrelatedValuePropagationPass::run(Function &F,
                                       FunctionAnalysisManager &AM) {
  auto &LVI = AM.getResult<LazyValueAnalysis>(F);
  bool Changed = false;
  for (Instruction &I : make_early_inc_range(instructions(F))) {
    auto *II = dyn_cast<IntrinsicInst>(&I);
    if (!II)
      continue;
    switch (II->getIntrinsicID()) {
    case Intrinsic::evm_div:
    case Intrinsic::evm_mod:
    case Intrinsic::evm_sdiv:
    case Intrinsic::evm_smod:
      Changed |= processDivRem(*II, LVI);
      break;
    case Intrinsic::evm_signextend:
      Changed |= processSignExtend(*II, LVI);
      break;
    default:
      break;
    }
  }
  if (!Changed)
    return PreservedAnalyses::all();

  PreservedAnalyses PA;
  PA.preserveSet<CFGAnalyses>();
  return PA;
}
