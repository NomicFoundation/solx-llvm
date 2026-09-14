//===--- EVMStackifyCodeEmitter.h - Create stackified MIR -------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file transforms MIR to the 'stackified' MIR.
//
//===----------------------------------------------------------------------===//

#include "EVMStackifyCodeEmitter.h"
#include "EVMStackShuffler.h"
#include "EVMStackSolver.h"
#include "TargetInfo/EVMTargetInfo.h"
#include "llvm/CodeGen/LiveStacks.h"
#include "llvm/MC/MCContext.h"

using namespace llvm;

#define DEBUG_TYPE "evm-stackify-code-emitter"

// Return the number of input arguments of the call instruction.
static size_t getCallNumArgs(const MachineInstr *Call) {
  assert(Call->getOpcode() == EVM::FCALL && "Unexpected call instruction");
  assert(Call->explicit_uses().begin()->isGlobal() &&
         "First operand must be a function");
  size_t NumArgs = Call->getNumExplicitOperands() - Call->getNumExplicitDefs();
  // The first operand is a function, so don't count it.
  NumArgs = NumArgs - 1;
  // If function will return, we need to account for the return label.
  return isNoReturnCallMI(*Call) ? NumArgs : NumArgs + 1;
}

static std::string getUnreachableStackSlotError(const MachineFunction &MF,
                                                const Stack &CurrentStack,
                                                const StackSlot *Slot,
                                                size_t Depth, bool isSwap) {
  return (MF.getName() + Twine(": cannot ") + (isSwap ? "swap " : "dup ") +
          std::to_string(Depth) + "-th stack item, " + Slot->toString() +
          ".\nItem it located too deep in the stack: " +
          CurrentStack.toString())
      .str();
}

size_t EVMStackifyCodeEmitter::CodeEmitter::stackHeight() const {
  return StackHeight;
}

void EVMStackifyCodeEmitter::CodeEmitter::enterMBB(MachineBasicBlock *MBB,
                                                   int Height) {
  StackHeight = Height;
  CurMBB = MBB;
  LLVM_DEBUG(dbgs() << "\n"
                    << "Set stack height: " << StackHeight << "\n");
  LLVM_DEBUG(dbgs() << "Setting current location to: " << MBB->getNumber()
                    << "." << MBB->getName() << "\n");
}

void EVMStackifyCodeEmitter::CodeEmitter::emitInst(const MachineInstr *MI) {
  unsigned Opc = MI->getOpcode();
  assert(Opc != EVM::JUMP && Opc != EVM::JUMPI && Opc != EVM::JUMP_UNLESS &&
         Opc != EVM::ARGUMENT && Opc != EVM::RET && Opc != EVM::CONST_I256 &&
         Opc != EVM::COPY_I256 && Opc != EVM::FCALL &&
         Opc != EVM::IMPLICIT_DEF && "Unexpected instruction");

  size_t NumInputs = MI->getNumExplicitOperands() - MI->getNumExplicitDefs();
  assert(StackHeight >= NumInputs && "Not enough operands on the stack");
  StackHeight -= NumInputs;
  StackHeight += MI->getNumExplicitDefs();

  auto NewMI = BuildMI(*CurMBB, CurMBB->end(), MI->getDebugLoc(),
                       TII->get(EVM::getStackOpcode(Opc)));
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitSWAP(unsigned Depth) {
  assert(StackHeight >= (Depth + 1) &&
         "Not enough operands on the stack for SWAP");
  unsigned Opc = EVM::getSWAPOpcode(Depth);
  auto NewMI = BuildMI(*CurMBB, CurMBB->end(), DebugLoc(),
                       TII->get(EVM::getStackOpcode(Opc)));
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitDUP(unsigned Depth) {
  assert(StackHeight >= Depth && "Not enough operands on the stack for DUP");
  StackHeight += 1;
  unsigned Opc = EVM::getDUPOpcode(Depth);
  auto NewMI = BuildMI(*CurMBB, CurMBB->end(), DebugLoc(),
                       TII->get(EVM::getStackOpcode(Opc)));
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitPOP() {
  assert(StackHeight > 0 && "Expected at least one operand on the stack");
  StackHeight -= 1;
  auto NewMI =
      BuildMI(*CurMBB, CurMBB->end(), DebugLoc(), TII->get(EVM::POP_S));
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitConstant(const APInt &Val) {
  StackHeight += 1;
  unsigned Opc = EVM::getPUSHOpcode(Val);
  auto NewMI = BuildMI(*CurMBB, CurMBB->end(), DebugLoc(),
                       TII->get(EVM::getStackOpcode(Opc)));
  if (Opc != EVM::PUSH0)
    NewMI.addCImm(ConstantInt::get(MF.getFunction().getContext(), Val));
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitConstant(uint64_t Val) {
  emitConstant(APInt(256, Val));
}

void EVMStackifyCodeEmitter::CodeEmitter::emitSymbol(const MachineInstr *MI,
                                                     MCSymbol *Symbol) {
  assert((isLinkerPseudoMI(*MI) || MI->getOpcode() == EVM::CODECOPY) &&
         "Unexpected symbol instruction");

  StackHeight += 1;
  unsigned Opc = isLinkerPseudoMI(*MI) ? EVM::getStackOpcode(MI->getOpcode())
                                       : EVM::PUSH_LABEL;
  auto NewMI = BuildMI(*CurMBB, CurMBB->end(), MI->getDebugLoc(), TII->get(Opc))
                   .addSym(Symbol);
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitLabelReference(
    const MachineInstr *Call) {
  assert(Call->getOpcode() == EVM::FCALL && "Unexpected call instruction");
  StackHeight += 1;
  auto [It, Inserted] = CallReturnSyms.try_emplace(Call);
  if (Inserted)
    It->second = MF.getContext().createTempSymbol("FUNC_RET", true);
  auto NewMI =
      BuildMI(*CurMBB, CurMBB->end(), DebugLoc(), TII->get(EVM::PUSH_LABEL))
          .addSym(It->second);
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitFuncCall(const MachineInstr *MI) {
  assert(MI->getOpcode() == EVM::FCALL && "Unexpected call instruction");
  assert(CurMBB == MI->getParent());

  size_t NumInputs = getCallNumArgs(MI);
  assert(StackHeight >= NumInputs && "Not enough operands on the stack");
  StackHeight -= NumInputs;

  // PUSH_LABEL increases the stack height on 1, but we don't increase it
  // explicitly here, as the label will be consumed by the following JUMP.
  StackHeight += MI->getNumExplicitDefs();

  // Create pseudo jump to the function, that will be expanded into PUSH and
  // JUMP instructions in the AsmPrinter.
  auto NewMI = BuildMI(*CurMBB, CurMBB->end(), MI->getDebugLoc(),
                       TII->get(EVM::PseudoCALL))
                   .addGlobalAddress(MI->explicit_uses().begin()->getGlobal());

  // If this function returns, add a return label so we can emit it together
  // with JUMPDEST. This is taken care in the AsmPrinter.
  if (!isNoReturnCallMI(*MI))
    NewMI.addSym(CallReturnSyms.at(MI));
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitRet(const MachineInstr *MI) {
  assert(MI->getOpcode() == EVM::RET && "Unexpected ret instruction");
  auto NewMI = BuildMI(*CurMBB, CurMBB->end(), MI->getDebugLoc(),
                       TII->get(EVM::PseudoRET));
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitUncondJump(
    const MachineInstr *MI, MachineBasicBlock *Target) {
  assert(MI->getOpcode() == EVM::JUMP &&
         "Unexpected unconditional jump instruction");
  auto NewMI = BuildMI(*CurMBB, CurMBB->end(), MI->getDebugLoc(),
                       TII->get(EVM::PseudoJUMP))
                   .addMBB(Target);
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitCondJump(
    const MachineInstr *MI, MachineBasicBlock *Target) {
  assert(MI->getOpcode() == EVM::JUMPI ||
         MI->getOpcode() == EVM::JUMP_UNLESS &&
             "Unexpected conditional jump instruction");
  assert(StackHeight > 0 && "Expected at least one operand on the stack");
  StackHeight -= 1;
  auto NewMI =
      BuildMI(*CurMBB, CurMBB->end(), MI->getDebugLoc(),
              TII->get(MI->getOpcode() == EVM::JUMPI ? EVM::PseudoJUMPI
                                                     : EVM::PseudoJUMP_UNLESS))
          .addMBB(Target);
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitFrameLoad(int FI) {
  StackHeight += 1;
  auto NewMI =
      BuildMI(*CurMBB, CurMBB->end(), DebugLoc(), TII->get(EVM::PUSH_FRAME))
          .addFrameIndex(FI);
  verify(NewMI);
  NewMI = BuildMI(*CurMBB, CurMBB->end(), DebugLoc(), TII->get(EVM::MLOAD_S));
  NewMI->setAsmPrinterFlag(MachineInstr::ReloadReuse);
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitFrameStore(int FI) {
  assert(StackHeight > 0 && "Expected at least one operand on the stack");

  // The stack top is consumed by the MSTORE instruction.
  StackHeight -= 1;
  auto NewMI =
      BuildMI(*CurMBB, CurMBB->end(), DebugLoc(), TII->get(EVM::PUSH_FRAME))
          .addFrameIndex(FI);
  verify(NewMI);
  NewMI = BuildMI(*CurMBB, CurMBB->end(), DebugLoc(), TII->get(EVM::MSTORE_S));
  NewMI->setAsmPrinterFlag(MachineInstr::ReloadReuse);
  verify(NewMI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitReload(Register Reg) {
  emitFrameLoad(getStackSlot(Reg));
}

void EVMStackifyCodeEmitter::CodeEmitter::emitCalleeSaveSpill(Register Reg,
                                                              unsigned Depth) {
  int FI = getCalleeSaveStackSlot(Reg);
  emitFrameLoad(FI);
  emitSWAP(Depth + 1);
  emitFrameStore(FI);
}

void EVMStackifyCodeEmitter::CodeEmitter::emitCalleeSaveLoad(Register Reg) {
  emitFrameLoad(getCalleeSaveStackSlot(Reg));
}

void EVMStackifyCodeEmitter::CodeEmitter::emitCalleeSaveRestore(Register Reg) {
  emitFrameStore(getStackSlot(Reg));
}

void EVMStackifyCodeEmitter::CodeEmitter::emitSpill(Register Reg,
                                                    unsigned DupIdx) {
  if (DupIdx != 0) {
    assert(StackHeight >= DupIdx &&
           "Not enough operands on the stack for DUP while spilling");

    // Register is used after spill, so we need to duplicate it. The copy is
    // consumed by the store, so the net stack height does not change.
    emitDUP(DupIdx);
  }
  emitFrameStore(getStackSlot(Reg));
}

int EVMStackifyCodeEmitter::CodeEmitter::getStackSlot(Register Reg) {
  int StackSlot = VRM.getStackSlot(Reg);
  if (StackSlot != VirtRegMap::NO_STACK_SLOT)
    return StackSlot;

  // Generate a new stack slot for the register and add register's live interval
  // to the stack slot. This is the same thing what InlineSpiller does, and this
  // is needed to StackSlotColoring afterwards to reduce the stack area.
  StackSlot = VRM.assignVirt2StackSlot(Reg);
  auto &StackInt =
      LSS.getOrCreateInterval(StackSlot, MF.getRegInfo().getRegClass(Reg));
  StackInt.getNextValue(SlotIndex(), LSS.getVNInfoAllocator());
  assert(StackInt.getNumValNums() == 1 && "Bad stack interval values");
  StackInt.MergeSegmentsInAsValue(LIS.getInterval(Reg),
                                  StackInt.getValNumInfo(0));
  return StackSlot;
}

int EVMStackifyCodeEmitter::CodeEmitter::getCalleeSaveStackSlot(Register Reg) {
  int FI = getStackSlot(Reg);
  // The callee-saved word makes the slot's memory live for the whole
  // function and not just for the spilled register's live range. Record
  // that so StackSlotColoring does not share the slot.
  auto &StackInt =
      LSS.getOrCreateInterval(FI, MF.getRegInfo().getRegClass(Reg));
  const SlotIndexes *Indexes = LIS.getSlotIndexes();
  StackInt.addSegment(LiveInterval::Segment(
      Indexes->getMBBStartIdx(&MF.front()), Indexes->getMBBEndIdx(&MF.back()),
      StackInt.getValNumInfo(0)));
  return FI;
}

// Verify that a stackified instruction doesn't have registers and dump it.
void EVMStackifyCodeEmitter::CodeEmitter::verify(const MachineInstr *MI) const {
  assert(EVMInstrInfo::isStack(MI) &&
         "Only stackified instructions are allowed");
  assert(all_of(MI->operands(),
                [](const MachineOperand &MO) { return !MO.isReg(); }) &&
         "Registers are not allowed in stackified instructions");

  LLVM_DEBUG(dbgs() << "Adding: " << *MI << "stack height: " << StackHeight
                    << "\n");
}
void EVMStackifyCodeEmitter::CodeEmitter::finalize() {
  for (MachineBasicBlock &MBB : MF)
    for (MachineInstr &MI : make_early_inc_range(MBB))
      // Remove all the instructions that are not stackified.
      // TODO: #749: Fix debug info for stackified instructions and don't
      // remove debug instructions.
      if (!EVMInstrInfo::isStack(&MI))
        MI.eraseFromParent();
}

void EVMStackifyCodeEmitter::adjustStackForInst(const MachineInstr *MI,
                                                size_t NumArgs) {
  // Remove arguments from CurrentStack.
  CurrentStack.erase(CurrentStack.end() - NumArgs, CurrentStack.end());

  // Push return values to CurrentStack.
  append_range(CurrentStack, StackModel.getSlotsForInstructionDefs(MI));
  assert(Emitter.stackHeight() == CurrentStack.size());
}

void EVMStackifyCodeEmitter::emitMI(const MachineInstr &MI) {
  assert(Emitter.stackHeight() == CurrentStack.size());

  if (MI.getOpcode() == EVM::FCALL) {
    size_t NumArgs = getCallNumArgs(&MI);
    assert(CurrentStack.size() >= NumArgs);

    // Assert that we got the correct return label on stack.
    if (!isNoReturnCallMI(MI)) {
      [[maybe_unused]] const auto *ReturnLabelSlot = dyn_cast<CallerReturnSlot>(
          CurrentStack[CurrentStack.size() - NumArgs]);
      assert(ReturnLabelSlot && ReturnLabelSlot->getCall() == &MI);
    }
    Emitter.emitFuncCall(&MI);
    adjustStackForInst(&MI, NumArgs);
  } else if (!isPushOrDupLikeMI(MI)) {
    size_t NumArgs = MI.getNumExplicitOperands() - MI.getNumExplicitDefs();
    assert(CurrentStack.size() >= NumArgs);
    // TODO: assert that we got a correct stack for the call.

    Emitter.emitInst(&MI);
    adjustStackForInst(&MI, NumArgs);
  }

  // If the MI doesn't define anything, we are done.
  if (!MI.getNumExplicitDefs())
    return;

  // Invalidate occurrences of the assigned variables.
  for (auto *&CurrentSlot : CurrentStack)
    if (const auto *RegSlot = dyn_cast<RegisterSlot>(CurrentSlot))
      if (MI.definesRegister(RegSlot->getReg(), /*TRI=*/nullptr))
        CurrentSlot = EVMStackModel::getUnusedSlot();

  // Assign variables to current stack top.
  assert(CurrentStack.size() >= MI.getNumExplicitDefs());
  llvm::copy(StackModel.getSlotsForInstructionDefs(&MI),
             CurrentStack.end() - MI.getNumExplicitDefs());
}

void EVMStackifyCodeEmitter::emitCalleeSaves() {
  ArrayRef<const CalleeSavedSlot *> Saves = StackModel.getCalleeSavedSlots();
  assert(!Saves.empty() && "Expected callee-saved slots");

  // First handle the spilled function arguments. For each of them the save
  // is fused with the argument's spill store into a swap triple. The previous
  // slot contents and the argument swap places, with the argument entering the
  // slot. The saved word is placed in the argument's stack position. The stack
  // height remains unchanged, and the remaining arguments retain their
  // original entry depths.
  for (const CalleeSavedSlot *Save : Saves) {
    Register Reg = Save->getReg();
    auto *It = llvm::find(CurrentStack, StackModel.getRegisterSlot(Reg));
    if (It == CurrentStack.end())
      continue;
    unsigned Depth = std::distance(std::next(It), CurrentStack.end());
    if (Depth + 1 > StackModel.stackDepthLimit())
      report_fatal_error("EVMStackifyCodeEmitter: spilled argument of '" +
                         MF.getName() + "' is out of reach for its save");
    Emitter.emitCalleeSaveSpill(Reg, Depth);
    *It = Save;
  }

  // Then load the previous contents of the remaining spill slots. Their
  // registers are defined later. The spill stores happen at the definitions
  // in emitSpills, safely after these loads.
  for (const CalleeSavedSlot *Save : Saves) {
    if (is_contained(CurrentStack, Save))
      continue;
    Emitter.emitCalleeSaveLoad(Save->getReg());
    CurrentStack.push_back(Save);
  }
  assert(Emitter.stackHeight() == CurrentStack.size());
}

void EVMStackifyCodeEmitter::emitSpills(const MachineBasicBlock &MBB,
                                        MachineBasicBlock::const_iterator Start,
                                        const Stack &Defs) {
  // Check if we have any spillable registers.
  if (find_if(Defs, [](const StackSlot *Slot) { return isSpillReg(Slot); }) ==
      Defs.end())
    return;

  // In case of a single definition, we can remove it from the stack
  // if it is not used after spill.
  if (Defs.size() == 1) {
    // Find the first instruction from which we can get entry stack.
    while (Start != MBB.end() && StackModel.skipMI(*Start))
      ++Start;

    // Find the next target stack, as we need to check if the register
    // is used after spill.
    const Stack &NextTargetStack =
        Start != MBB.end() && !EVMInstrInfo::isStack(&*Start)
            ? StackModel.getInstEntryStack(&*Start)
            : StackModel.getMBBExitStack(&MBB);
    const auto *RegSlot = cast<RegisterSlot>(Defs[0]);

    // Find if if the register is used after spill. If it is we need to
    // emit DUP instruction to keep it on the stack.
    bool UsedAfter = is_contained(NextTargetStack, RegSlot);
    Emitter.emitSpill(RegSlot->getReg(), UsedAfter);

    // Remove the register from the current stack, if it is not used
    // after spill.
    if (!UsedAfter)
      CurrentStack.pop_back();
  } else {
    // TODO: In case definition are not used after spill, we can
    // remove them from the current stack, and not emit DUP. This
    // is more complex when we have multiple definitions, as we
    // need to do stack manipulation to keep the stack in sync
    // with the target stack.
    for (auto [DefIdx, Def] : enumerate(reverse(Defs)))
      if (isSpillReg(Def))
        Emitter.emitSpill(cast<RegisterSlot>(Def)->getReg(), DefIdx + 1);
  }
  assert(Emitter.stackHeight() == CurrentStack.size());
}

// Checks if it's valid to transition from \p SourceStack to \p TargetStack,
// that is \p SourceStack matches each slot in \p TargetStack that is not a
// UnusedSlot exactly.
[[maybe_unused]] static bool match(const Stack &Source, const Stack &Target) {
  return Source.size() == Target.size() &&
         all_of(zip_equal(Source, Target), [](const auto &Pair) {
           const auto [Src, Tgt] = Pair;
           return isa<UnusedSlot>(Tgt) || (Src == Tgt);
         });
}

void EVMStackifyCodeEmitter::emitStackPermutations(const Stack &TargetStack) {
  assert(Emitter.stackHeight() == CurrentStack.size());
  const unsigned StackDepthLimit = StackModel.stackDepthLimit();

  calculateStack(
      CurrentStack, TargetStack, StackDepthLimit,
      // Swap.
      [&](unsigned I) {
        assert(CurrentStack.size() == Emitter.stackHeight());
        assert(I > 0 && I < CurrentStack.size());
        if (I <= StackDepthLimit) {
          Emitter.emitSWAP(I);
          return;
        }
        const StackSlot *Slot = CurrentStack[CurrentStack.size() - I - 1];
        std::string ErrMsg = getUnreachableStackSlotError(
            MF, CurrentStack, Slot, I + 1, /* isSwap */ true);
        report_fatal_error(ErrMsg.c_str());
      },
      // Push or dup.
      [&](const StackSlot *Slot) {
        assert(CurrentStack.size() == Emitter.stackHeight());

        // Prefer to emit PUSH0 instead of DUP, as it is cheaper.
        if (isa<LiteralSlot>(Slot) &&
            cast<LiteralSlot>(Slot)->getValue().isZero()) {
          Emitter.emitConstant(0);
          return;
        }

        // Dup the slot, if already on stack and reachable.
        auto SlotIt = llvm::find(llvm::reverse(CurrentStack), Slot);
        if (SlotIt != CurrentStack.rend()) {
          unsigned Depth = std::distance(CurrentStack.rbegin(), SlotIt);
          if (Depth < StackDepthLimit) {
            Emitter.emitDUP(static_cast<unsigned>(Depth + 1));
            return;
          }
          if (!Slot->isRematerializable() && !isSpillReg(Slot)) {
            std::string ErrMsg = getUnreachableStackSlotError(
                MF, CurrentStack, Slot, Depth + 1, /* isSwap */ false);
            report_fatal_error(ErrMsg.c_str());
          }
        }

        // A callee-saved word exists only on the stack once its spill slot
        // has been overwritten. It is materialized exactly once, in
        // emitCalleeSaves. Reaching this point means the layouts lost it.
        assert(!isa<CalleeSavedSlot>(Slot) &&
               "Callee-saved word of a spill slot cannot be rematerialized");

        // Rematerialize the slot.
        assert(Slot->isRematerializable() || isSpillReg(Slot));
        if (const auto *L = dyn_cast<LiteralSlot>(Slot)) {
          Emitter.emitConstant(L->getValue());
        } else if (const auto *S = dyn_cast<SymbolSlot>(Slot)) {
          Emitter.emitSymbol(S->getMachineInstr(), S->getSymbol());
        } else if (const auto *CallRet = dyn_cast<CallerReturnSlot>(Slot)) {
          Emitter.emitLabelReference(CallRet->getCall());
        } else if (const auto *Spill = dyn_cast<RegisterSlot>(Slot)) {
          Emitter.emitReload(Spill->getReg());
        } else {
          assert(isa<UnusedSlot>(Slot));
          // Note: this will always be popped, so we can push anything.
          Emitter.emitConstant(0);
        }
      },
      // Pop.
      [&]() { Emitter.emitPOP(); });

  assert(Emitter.stackHeight() == CurrentStack.size());
}

// Emit the stack required for enterting the MI.
void EVMStackifyCodeEmitter::emitMIEntryStack(const MachineInstr &MI) {
  // Check if we can choose cheaper stack shuffling if the MI is commutable.
  const Stack &TargetStack = StackModel.getInstEntryStack(&MI);
  bool SwapCommutable = false;
  if (MI.isCommutable()) {
    assert(TargetStack.size() > 1);

    size_t DefaultCost =
        calculateStackTransformCost(CurrentStack, TargetStack,
                                    StackModel.stackDepthLimit())
            .value_or(std::numeric_limits<unsigned>::max());

    // Swap the commutable stack items and measure the stack shuffling cost.
    // Commutable operands always take top two stack slots.
    Stack CommutedTargetStack = TargetStack;
    std::swap(CommutedTargetStack[CommutedTargetStack.size() - 1],
              CommutedTargetStack[CommutedTargetStack.size() - 2]);
    size_t CommutedCost =
        calculateStackTransformCost(CurrentStack, CommutedTargetStack,
                                    StackModel.stackDepthLimit())
            .value_or(std::numeric_limits<unsigned>::max());

    // Choose the cheapest transformation.
    SwapCommutable = CommutedCost < DefaultCost;
    emitStackPermutations(SwapCommutable ? CommutedTargetStack : TargetStack);
  } else {
    emitStackPermutations(TargetStack);
  }

#ifndef NDEBUG
  // Assert that we have the inputs of the MI on stack top.
  const Stack &SavedInput = StackModel.getMIInput(MI);
  assert(CurrentStack.size() == Emitter.stackHeight());
  assert(CurrentStack.size() >= SavedInput.size());
  Stack Input(CurrentStack.end() - SavedInput.size(), CurrentStack.end());

  // Adjust the Input if needed.
  if (SwapCommutable)
    std::swap(Input[Input.size() - 1], Input[Input.size() - 2]);

  assert(match(Input, SavedInput));
#endif // NDEBUG
}

void EVMStackifyCodeEmitter::run() {
  assert(CurrentStack.empty() && Emitter.stackHeight() == 0);

  SmallPtrSet<MachineBasicBlock *, 32> Visited;
  SmallVector<MachineBasicBlock *, 32> WorkList{&MF.front()};
  while (!WorkList.empty()) {
    auto *MBB = WorkList.pop_back_val();
    if (!Visited.insert(MBB).second)
      continue;

    CurrentStack = StackModel.getMBBEntryStack(MBB);
    // The callee-saved words in the entry stack are materialized by
    // emitCalleeSaves below. Physically, at function entry a spilled argument
    // still occupies the position of its saved word, and the saved words
    // loaded on top of the parameters do not exist yet.
    if (MBB == &MF.front()) {
      while (!CurrentStack.empty()) {
        const auto *Save = dyn_cast<CalleeSavedSlot>(CurrentStack.back());
        if (!Save || StackModel.isArgumentSave(Save))
          break;
        CurrentStack.pop_back();
      }
      for (const StackSlot *&Slot : CurrentStack)
        if (const auto *Save = dyn_cast<CalleeSavedSlot>(Slot))
          Slot = StackModel.getRegisterSlot(Save->getReg());
    }
    Emitter.enterMBB(MBB, CurrentStack.size());

    // Get branch information before we start to change the BB.
    auto [BranchTy, TBB, FBB, BrInsts, Condition] = getBranchInfo(MBB);
    bool HasReturn = MBB->isReturnBlock();
    const MachineInstr *ReturnMI = HasReturn ? &MBB->back() : nullptr;

    if (MBB == &MF.front()) {
      if (!StackModel.getCalleeSavedSlots().empty())
        // This is a recursive function with spills. Callee-save the previous
        // contents of the spill slots. This also stores the spilled
        // arguments.
        emitCalleeSaves();
      else
        // Emit the spills for the arguments, if needed.
        emitSpills(*MBB, MBB->begin(), StackModel.getMBBEntryStack(MBB));
    }

    for (const auto &MI : StackModel.instructionsToProcess(MBB)) {
      // We are done if the MI is in the stack form.
      if (EVMInstrInfo::isStack(&MI))
        break;

      emitMIEntryStack(MI);

      [[maybe_unused]] size_t BaseHeight =
          CurrentStack.size() - StackModel.getMIInput(MI).size();

      emitMI(MI);

#ifndef NDEBUG
      // Assert that the MI produced its proclaimed output.
      size_t NumDefs = MI.getNumExplicitDefs();
      size_t StackSize = CurrentStack.size();
      assert(StackSize == Emitter.stackHeight());
      assert(StackSize == BaseHeight + NumDefs);
      assert(StackSize >= NumDefs);
      // Check that the top NumDefs slots are the MI defs.
      for (size_t I = StackSize - NumDefs; I < StackSize; ++I)
        assert(MI.definesRegister(cast<RegisterSlot>(CurrentStack[I])->getReg(),
                                  /*TRI=*/nullptr));
#endif // NDEBUG

      // Emit spills for the instruction definitions, if needed.
      emitSpills(*MBB, std::next(MI.getIterator()),
                 StackModel.getSlotsForInstructionDefs(&MI));
    }

    // Exit the block.
    if (BranchTy == EVMInstrInfo::BT_None) {
      if (HasReturn) {
        assert(!MF.getFunction().hasFnAttribute(Attribute::NoReturn));
        assert(StackModel.getReturnArguments(*ReturnMI) ==
               StackModel.getMBBExitStack(MBB));
        // Create the function return stack and jump.
        emitStackPermutations(StackModel.getMBBExitStack(MBB));
        // The callee-saved words sit on top of the return address. Store
        // each of them back to its spill slot. This restores the enclosing
        // activation's view of the spill area.
        while (!CurrentStack.empty() &&
               isa<CalleeSavedSlot>(CurrentStack.back())) {
          const auto *Save = cast<CalleeSavedSlot>(CurrentStack.back());
          Emitter.emitCalleeSaveRestore(Save->getReg());
          CurrentStack.pop_back();
        }
        Emitter.emitRet(ReturnMI);
      }
    } else if (BranchTy == EVMInstrInfo::BT_Uncond ||
               BranchTy == EVMInstrInfo::BT_NoBranch) {
      if (!MBB->succ_empty()) {
        // Create the stack expected at the jump target.
        emitStackPermutations(StackModel.getMBBEntryStack(TBB));
        assert(match(CurrentStack, StackModel.getMBBEntryStack(TBB)));

        if (!BrInsts.empty())
          Emitter.emitUncondJump(BrInsts[0], TBB);

        WorkList.push_back(TBB);
      }
    } else {
      assert(BranchTy == EVMInstrInfo::BT_Cond ||
             BranchTy == EVMInstrInfo::BT_CondUncond);
      // Create the shared entry stack of the jump targets, which is
      // stored as exit stack of the current MBB.
      emitStackPermutations(StackModel.getMBBExitStack(MBB));
      assert(!CurrentStack.empty() &&
             CurrentStack.back() == StackModel.getStackSlot(*Condition));

      // Emit the conditional jump to the non-zero label and update the
      // stored stack.
      assert(!BrInsts.empty());
      Emitter.emitCondJump(BrInsts[BrInsts.size() - 1], TBB);
      CurrentStack.pop_back();

      // Assert that we have a valid stack for both jump targets.
      assert(match(CurrentStack, StackModel.getMBBEntryStack(TBB)));
      assert(match(CurrentStack, StackModel.getMBBEntryStack(FBB)));

      // Generate unconditional jump if needed.
      if (BrInsts.size() == 2)
        Emitter.emitUncondJump(BrInsts[0], FBB);

      WorkList.push_back(TBB);
      WorkList.push_back(FBB);
    }
  }
  Emitter.finalize();
}
