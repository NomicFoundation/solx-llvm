//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Pre-emission peephole optimizations.
//
//===----------------------------------------------------------------------===//

#include "EVM.h"
#include "EVMInstrInfo.h"
#include "MCTargetDesc/EVMMCTargetDesc.h"
#include "TargetInfo/EVMTargetInfo.h"
#include "llvm/ADT/APInt.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/TargetInstrInfo.h"
#include "llvm/CodeGen/TargetSubtargetInfo.h"
#include "llvm/IR/Constants.h"
#include "llvm/Support/Debug.h"

#define DEBUG_TYPE "evm-peephole"
#define EVM_PEEPHOLE "EVM Peephole"

using namespace llvm;

STATISTIC(NumFoldedSequences, "Number of folded instruction sequences");

/// Prints the instructions of a matched sequence before it is rewritten.
static void debugPrintFold(StringRef Rule,
                           std::initializer_list<const MachineInstr *> MIs) {
  LLVM_DEBUG({
    dbgs() << "EVMPeephole: " << Rule << ":\n";
    for (const MachineInstr *MI : MIs)
      dbgs() << "    " << *MI;
  });
}

namespace {
/// Perform foldings on stack-form MIR before emission.
///
class EVMPeephole final : public MachineFunctionPass {
public:
  static char ID;
  EVMPeephole() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override { return EVM_PEEPHOLE; }
  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  const TargetInstrInfo *TII = nullptr;

  bool optimizeConditionaJumps(MachineBasicBlock &MBB) const;
  unsigned foldConstantSequences(MachineBasicBlock &MBB) const;
  std::optional<MachineBasicBlock::iterator>
  tryFoldAt(MachineBasicBlock &MBB, MachineBasicBlock::iterator I) const;
};
} // namespace

/// Returns the constant pushed by \p MI if it is a constant PUSH instruction.
static std::optional<APInt> getConstPushValue(const MachineInstr &MI) {
  if (!EVMInstrInfo::isPush(&MI))
    return std::nullopt;
  if (MI.getOpcode() == EVM::PUSH0_S)
    return APInt(256, 0);
  // Guard against pushes of non-constant operands (frame indices, symbols).
  const MachineOperand &MO = MI.getOperand(0);
  if (!MO.isCImm())
    return std::nullopt;
  return MO.getCImm()->getValue().zextOrTrunc(256);
}

/// Returns the code size in bytes of the canonical PUSH of \p Val.
static unsigned getPushByteSize(const APInt &Val) {
  return Val.isZero() ? 1 : 1 + alignTo(Val.getActiveBits(), 8) / 8;
}

static bool isSwap(unsigned Opc) {
  switch (Opc) {
  case EVM::SWAP1_S:
  case EVM::SWAP2_S:
  case EVM::SWAP3_S:
  case EVM::SWAP4_S:
  case EVM::SWAP5_S:
  case EVM::SWAP6_S:
  case EVM::SWAP7_S:
  case EVM::SWAP8_S:
  case EVM::SWAP9_S:
  case EVM::SWAP10_S:
  case EVM::SWAP11_S:
  case EVM::SWAP12_S:
  case EVM::SWAP13_S:
  case EVM::SWAP14_S:
  case EVM::SWAP15_S:
  case EVM::SWAP16_S:
    return true;
  default:
    return false;
  }
}

/// Returns N for SWAPN_S opcodes, 0 otherwise.
static unsigned getSwapDepth(unsigned Opc) {
  switch (Opc) {
    // clang-format off
  case EVM::SWAP1_S: return 1;
  case EVM::SWAP2_S: return 2;
  case EVM::SWAP3_S: return 3;
  case EVM::SWAP4_S: return 4;
  case EVM::SWAP5_S: return 5;
  case EVM::SWAP6_S: return 6;
  case EVM::SWAP7_S: return 7;
  case EVM::SWAP8_S: return 8;
  case EVM::SWAP9_S: return 9;
  case EVM::SWAP10_S: return 10;
  case EVM::SWAP11_S: return 11;
  case EVM::SWAP12_S: return 12;
  case EVM::SWAP13_S: return 13;
  case EVM::SWAP14_S: return 14;
  case EVM::SWAP15_S: return 15;
  case EVM::SWAP16_S: return 16;
  // clang-format on
  default:
    return 0;
  }
}

/// Returns N for DUPN_S opcodes, 0 otherwise.
static unsigned getDupDepth(unsigned Opc) {
  switch (Opc) {
    // clang-format off
  case EVM::DUP1_S: return 1;
  case EVM::DUP2_S: return 2;
  case EVM::DUP3_S: return 3;
  case EVM::DUP4_S: return 4;
  case EVM::DUP5_S: return 5;
  case EVM::DUP6_S: return 6;
  case EVM::DUP7_S: return 7;
  case EVM::DUP8_S: return 8;
  case EVM::DUP9_S: return 9;
  case EVM::DUP10_S: return 10;
  case EVM::DUP11_S: return 11;
  case EVM::DUP12_S: return 12;
  case EVM::DUP13_S: return 13;
  case EVM::DUP14_S: return 14;
  case EVM::DUP15_S: return 15;
  case EVM::DUP16_S: return 16;
  // clang-format on
  default:
    return 0;
  }
}

/// Evaluates a binary stack operation whose both operands are known
/// constants. \p Bot is the value pushed first (µs[1]), \p Top the value
/// pushed second, i.e. the stack top (µs[0]).
static std::optional<APInt> evalBinaryOp(unsigned Opc, const APInt &Bot,
                                         const APInt &Top) {
  const unsigned BitWidth = 256;
  switch (Opc) {
  case EVM::ADD_S:
    return Top + Bot;
  case EVM::MUL_S:
    return Top * Bot;
  case EVM::SUB_S:
    return Top - Bot;
  case EVM::DIV_S:
    return Bot.isZero() ? APInt::getZero(BitWidth) : Top.udiv(Bot);
  case EVM::SDIV_S:
    if (Bot.isZero())
      return APInt::getZero(BitWidth);
    if (Top.isMinSignedValue() && Bot.isAllOnes())
      return Top;
    return Top.sdiv(Bot);
  case EVM::MOD_S:
    return Bot.isZero() ? APInt::getZero(BitWidth) : Top.urem(Bot);
  case EVM::SMOD_S:
    return Bot.isZero() ? APInt::getZero(BitWidth) : Top.srem(Bot);
  case EVM::AND_S:
    return Top & Bot;
  case EVM::OR_S:
    return Top | Bot;
  case EVM::XOR_S:
    return Top ^ Bot;
  case EVM::ULT_S:
    return APInt(BitWidth, Top.ult(Bot));
  case EVM::UGT_S:
    return APInt(BitWidth, Top.ugt(Bot));
  case EVM::LT_S: // EVM SLT: signed less-than.
    return APInt(BitWidth, Top.slt(Bot));
  case EVM::GT_S: // EVM SGT: signed greater-than.
    return APInt(BitWidth, Top.sgt(Bot));
  case EVM::EQ_S:
    return APInt(BitWidth, Top == Bot);
  case EVM::SHL_S:
    return Top.uge(BitWidth) ? APInt::getZero(BitWidth)
                             : Bot.shl(Top.getZExtValue());
  case EVM::SHR_S:
    return Top.uge(BitWidth) ? APInt::getZero(BitWidth)
                             : Bot.lshr(Top.getZExtValue());
  case EVM::SAR_S:
    if (Top.uge(BitWidth))
      return Bot.isNegative() ? APInt::getAllOnes(BitWidth)
                              : APInt::getZero(BitWidth);
    return Bot.ashr(Top.getZExtValue());
  case EVM::BYTE_S:
    if (Top.uge(32))
      return APInt::getZero(BitWidth);
    return Bot.lshr(8 * (31 - Top.getZExtValue())) & APInt(BitWidth, 0xff);
  case EVM::SIGNEXTEND_S:
    if (Top.uge(31))
      return Bot;
    return Bot.trunc(8 * (Top.getZExtValue() + 1)).sext(BitWidth);
  default:
    return std::nullopt;
  }
}

/// Returns true if the binary stack operation is commutative, i.e. swapping
/// its two stack operands does not change the result.
static bool isCommutativeBinOp(unsigned Opc) {
  switch (Opc) {
  case EVM::ADD_S:
  case EVM::MUL_S:
  case EVM::AND_S:
  case EVM::OR_S:
  case EVM::XOR_S:
  case EVM::EQ_S:
    return true;
  default:
    return false;
  }
}

/// Returns the comparison opcode with swapped operands, or 0 if \p Opc is not
/// a comparison.
static unsigned getFlippedComparison(unsigned Opc) {
  switch (Opc) {
  case EVM::ULT_S:
    return EVM::UGT_S;
  case EVM::UGT_S:
    return EVM::ULT_S;
  case EVM::LT_S: // EVM SLT.
    return EVM::GT_S;
  case EVM::GT_S: // EVM SGT.
    return EVM::LT_S;
  default:
    return 0;
  }
}

/// Returns true for pure context getters that cost less than a DUP (2 gas
/// vs 3) and always yield the same value when re-executed immediately.
/// PC and GAS are excluded (their value depends on the execution point),
/// as are getters costing more than a DUP (e.g. SELFBALANCE).
static bool isReexecutableCheapGetter(unsigned Opc) {
  switch (Opc) {
  case EVM::ADDRESS_S:
  case EVM::ORIGIN_S:
  case EVM::CALLER_S:
  case EVM::CALLVALUE_S:
  case EVM::CALLDATASIZE_S:
  case EVM::CODESIZE_S:
  case EVM::GASPRICE_S:
  case EVM::RETURNDATASIZE_S:
  case EVM::COINBASE_S:
  case EVM::TIMESTAMP_S:
  case EVM::NUMBER_S:
  case EVM::GASLIMIT_S:
  case EVM::CHAINID_S:
  case EVM::BASEFEE_S:
    return true;
  default:
    return false;
  }
}

/// Evaluates a unary stack operation on a known constant operand.
static std::optional<APInt> evalUnaryOp(unsigned Opc, const APInt &Op) {
  switch (Opc) {
  case EVM::ISZERO_S:
    return APInt(256, Op.isZero());
  case EVM::NOT_S:
    return ~Op;
  default:
    return std::nullopt;
  }
}

/// Inserts a canonical PUSH of \p Val before \p Before.
static void insertConstPush(MachineBasicBlock &MBB,
                            MachineBasicBlock::iterator Before,
                            const DebugLoc &DL, const TargetInstrInfo *TII,
                            const APInt &Val) {
  unsigned Opc = EVM::getStackOpcode(EVM::getPUSHOpcode(Val));
  auto NewMI = BuildMI(MBB, Before, DL, TII->get(Opc));
  if (Opc != EVM::PUSH0_S)
    NewMI.addCImm(
        ConstantInt::get(MBB.getParent()->getFunction().getContext(), Val));
}

bool EVMPeephole::runOnMachineFunction(MachineFunction &MF) {
  TII = MF.getSubtarget().getInstrInfo();
  // Folds are counted in a local variable and added to the statistic once,
  // to avoid an atomic increment on every folded sequence.
  unsigned FoldedSequences = 0;
  for (MachineBasicBlock &MBB : MF) {
    FoldedSequences += foldConstantSequences(MBB);
    FoldedSequences += optimizeConditionaJumps(MBB) ? 1 : 0;
  }
  NumFoldedSequences += FoldedSequences;
  return FoldedSequences != 0;
}

/// Tries to fold the instruction sequence starting at \p I. On success,
/// returns the iterator to resume scanning from; the resume point is placed
/// one instruction before the rewritten region so that newly created
/// adjacencies are re-examined.
std::optional<MachineBasicBlock::iterator>
EVMPeephole::tryFoldAt(MachineBasicBlock &MBB,
                       MachineBasicBlock::iterator I) const {
  MachineBasicBlock::iterator End = MBB.end();
  auto Second = std::next(I);
  if (Second == End)
    return std::nullopt;

  // Compute the resume point: the instruction preceding the region, or the
  // block start.
  auto ResumePoint = [&]() {
    return I == MBB.begin() ? MBB.begin() : std::prev(I);
  };

  // SWAPn SWAPn -> (nothing).
  if (isSwap(I->getOpcode()) && I->getOpcode() == Second->getOpcode()) {
    debugPrintFold("removing SWAPn, SWAPn pair", {&*I, &*Second});
    auto Resume = ResumePoint();
    bool AtBegin = I == MBB.begin();
    Second->eraseFromParent();
    I->eraseFromParent();
    return AtBegin ? MBB.begin() : Resume;
  }

  if (I->getOpcode() == EVM::SWAP1_S) {
    // SWAP1 before a commutative binary operation is redundant.
    if (isCommutativeBinOp(Second->getOpcode())) {
      debugPrintFold("removing SWAP1 before a commutative operation",
                     {&*I, &*Second});
      auto Resume = ResumePoint();
      bool AtBegin = I == MBB.begin();
      I->eraseFromParent();
      return AtBegin ? MBB.begin() : Resume;
    }
    // SWAP1 before a comparison flips the comparison instead.
    if (unsigned Flipped = getFlippedComparison(Second->getOpcode())) {
      debugPrintFold("flipping the comparison to remove SWAP1",
                     {&*I, &*Second});
      auto Resume = ResumePoint();
      bool AtBegin = I == MBB.begin();
      Second->setDesc(TII->get(Flipped));
      I->eraseFromParent();
      return AtBegin ? MBB.begin() : Resume;
    }
  }

  // GETTER, DUP1 -> GETTER, GETTER: re-executing a cheap pure context getter
  // is cheaper than duplicating its result (2 gas vs 3, same code size).
  // Only valid because the two instructions are adjacent, so no state can
  // change in between.
  if (isReexecutableCheapGetter(I->getOpcode()) &&
      Second->getOpcode() == EVM::DUP1_S) {
    debugPrintFold("replacing DUP1 with a re-executed getter", {&*I, &*Second});
    Second->setDesc(TII->get(I->getOpcode()));
    return ResumePoint();
  }

  // GETTER, GETTER, SWAP1 -> GETTER, GETTER: the two topmost values are
  // equal, so the swap is a no-op.
  if (isReexecutableCheapGetter(I->getOpcode()) &&
      Second->getOpcode() == I->getOpcode()) {
    if (auto Third = std::next(Second);
        Third != End && Third->getOpcode() == EVM::SWAP1_S) {
      debugPrintFold("removing SWAP1 of two identical getter results",
                     {&*I, &*Second, &*Third});
      Third->eraseFromParent();
      return ResumePoint();
    }
  }

  // DUPn SWAPn -> DUPn: after DUPn the top and the (n+1)-th stack elements
  // are equal, so swapping them is a no-op.
  if (unsigned DupDepth = getDupDepth(I->getOpcode());
      DupDepth != 0 && DupDepth == getSwapDepth(Second->getOpcode())) {
    debugPrintFold("removing SWAPn after DUPn", {&*I, &*Second});
    Second->eraseFromParent();
    return ResumePoint();
  }

  std::optional<APInt> First = getConstPushValue(*I);
  if (!First)
    return std::nullopt;

  // PUSH a, unop -> PUSH (unop a), if the result push is not longer.
  if (auto Result = evalUnaryOp(Second->getOpcode(), *First)) {
    if (getPushByteSize(*Result) <= getPushByteSize(*First) + 1) {
      debugPrintFold("constant-folding a unary operation", {&*I, &*Second});
      LLVM_DEBUG(dbgs() << "    -> PUSH " << *Result << '\n');
      auto Resume = ResumePoint();
      bool AtBegin = I == MBB.begin();
      insertConstPush(MBB, I, Second->getDebugLoc(), TII, *Result);
      Second->eraseFromParent();
      I->eraseFromParent();
      return AtBegin ? MBB.begin() : Resume;
    }
  }

  if (std::optional<APInt> SecondVal = getConstPushValue(*Second)) {
    auto Third = std::next(Second);

    // PUSH a, PUSH b, binop -> PUSH (binop b a), if the result push is not
    // longer than the folded sequence.
    if (Third != End) {
      if (auto Result = evalBinaryOp(Third->getOpcode(), *First, *SecondVal)) {
        if (getPushByteSize(*Result) <=
            getPushByteSize(*First) + getPushByteSize(*SecondVal) + 1) {
          debugPrintFold("constant-folding a binary operation",
                         {&*I, &*Second, &*Third});
          LLVM_DEBUG(dbgs() << "    -> PUSH " << *Result << '\n');
          auto Resume = ResumePoint();
          bool AtBegin = I == MBB.begin();
          insertConstPush(MBB, I, Third->getDebugLoc(), TII, *Result);
          Third->eraseFromParent();
          Second->eraseFromParent();
          I->eraseFromParent();
          return AtBegin ? MBB.begin() : Resume;
        }
      }

      // PUSH a, PUSH b, SWAP1 -> PUSH b, PUSH a.
      if (Third->getOpcode() == EVM::SWAP1_S) {
        debugPrintFold("reordering PUSH, PUSH, SWAP1",
                       {&*I, &*Second, &*Third});
        auto Resume = ResumePoint();
        bool AtBegin = I == MBB.begin();
        MBB.splice(Third, &MBB, I);
        Third->eraseFromParent();
        return AtBegin ? MBB.begin() : Resume;
      }
    }

    // PUSH a, PUSH a -> PUSH a, DUP1, if the push is wider than one byte.
    if (*First == *SecondVal && getPushByteSize(*First) >= 2) {
      debugPrintFold("rewriting an identical PUSH pair to PUSH, DUP1",
                     {&*I, &*Second});
      Second->setDesc(TII->get(EVM::DUP1_S));
      Second->removeOperand(0);
      return ResumePoint();
    }
  }

  // Folds with an unknown value below the pushed constant zero on the stack.
  if (First->isZero()) {
    unsigned SecondOpc = Second->getOpcode();
    // PUSH 0, {ADD,OR,XOR} -> (nothing): identity on the unknown operand.
    if (SecondOpc == EVM::ADD_S || SecondOpc == EVM::OR_S ||
        SecondOpc == EVM::XOR_S) {
      debugPrintFold("removing an identity operation with zero",
                     {&*I, &*Second});
      auto Resume = ResumePoint();
      bool AtBegin = I == MBB.begin();
      Second->eraseFromParent();
      I->eraseFromParent();
      return AtBegin ? MBB.begin() : Resume;
    }
    // PUSH 0, {AND,MUL} -> POP, PUSH 0: the result is always zero, but the
    // unknown operand must still be consumed.
    if (SecondOpc == EVM::AND_S || SecondOpc == EVM::MUL_S) {
      debugPrintFold("folding a zero-absorbing operation to POP, PUSH0",
                     {&*I, &*Second});
      auto Resume = ResumePoint();
      bool AtBegin = I == MBB.begin();
      BuildMI(MBB, I, Second->getDebugLoc(), TII->get(EVM::POP_S));
      insertConstPush(MBB, I, Second->getDebugLoc(), TII, APInt::getZero(256));
      Second->eraseFromParent();
      I->eraseFromParent();
      return AtBegin ? MBB.begin() : Resume;
    }
  }

  return std::nullopt;
}

/// Returns the number of folded sequences.
unsigned EVMPeephole::foldConstantSequences(MachineBasicBlock &MBB) const {
  unsigned FoldedSequences = 0;
  auto I = MBB.begin();
  while (I != MBB.end()) {
    if (auto Resume = tryFoldAt(MBB, I)) {
      ++FoldedSequences;
      I = *Resume;
      continue;
    }
    ++I;
  }
  return FoldedSequences;
}

static bool isNegatedAndJumpedOn(const MachineBasicBlock &MBB,
                                 MachineBasicBlock::const_iterator I) {
  if (I == MBB.end() || I->getOpcode() != EVM::ISZERO_S)
    return false;
  ++I;
  // When a conditional jump’s predicate is a (possibly nested) bitwise `or`,
  // both operands are eligible for folding. Currently we only fold the operand
  // computed last.
  // TODO: #887 Apply folding to all operands.
  while (I != MBB.end() && I->getOpcode() == EVM::OR_S)
    ++I;
  return I != MBB.end() && I->getOpcode() == EVM::PseudoJUMPI;
}

bool EVMPeephole::optimizeConditionaJumps(MachineBasicBlock &MBB) const {
  MachineBasicBlock::iterator I = MBB.begin();

  while (I != MBB.end()) {
    // Fold ISZERO ISZERO to nothing, only if it's a predicate to JUMPI.
    if (I->getOpcode() == EVM::ISZERO_S &&
        isNegatedAndJumpedOn(MBB, std::next(I))) {
      debugPrintFold("removing an ISZERO, ISZERO jump predicate",
                     {&*I, &*std::next(I)});
      std::next(I)->eraseFromParent();
      I->eraseFromParent();
      return true;
    }

    // Fold EQ ISZERO to SUB, only if it's a predicate to JUMPI.
    if (I->getOpcode() == EVM::EQ_S &&
        isNegatedAndJumpedOn(MBB, std::next(I))) {
      debugPrintFold("folding an EQ, ISZERO jump predicate to SUB",
                     {&*I, &*std::next(I)});
      I->setDesc(TII->get(EVM::SUB_S));
      std::next(I)->eraseFromParent();
      return true;
    }

    // Fold SUB ISZERO to EQ, only if it's a predicate to JUMPI.
    if (I->getOpcode() == EVM::SUB_S &&
        isNegatedAndJumpedOn(MBB, std::next(I))) {
      debugPrintFold("folding a SUB, ISZERO jump predicate to EQ",
                     {&*I, &*std::next(I)});
      I->setDesc(TII->get(EVM::EQ_S));
      std::next(I)->eraseFromParent();
      return true;
    }

    ++I;
  }
  return false;
}

char EVMPeephole::ID = 0;

INITIALIZE_PASS(EVMPeephole, DEBUG_TYPE, EVM_PEEPHOLE, false, false)

FunctionPass *llvm::createEVMPeepholePass() { return new EVMPeephole(); }
