//===--- EVMStackifyCodeEmitter.h - Create stackified MIR  ------*- C++ -*-===//
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

#ifndef LLVM_LIB_TARGET_EVM_EVMSTACKIFYCODEEMITTER_H
#define LLVM_LIB_TARGET_EVM_EVMSTACKIFYCODEEMITTER_H

#include "EVMStackModel.h"
#include "EVMSubtarget.h"

namespace llvm {

class MachineInstr;
class MCSymbol;
class LiveStacks;

class EVMStackifyCodeEmitter {
public:
  EVMStackifyCodeEmitter(const EVMStackModel &StackModel, MachineFunction &MF,
                         VirtRegMap &VRM, LiveStacks &LSS, LiveIntervals &LIS)
      : Emitter(MF, VRM, LSS, LIS), StackModel(StackModel), MF(MF) {}

  /// Stackify instructions, starting from the first MF's MBB.
  void run();

private:
  class CodeEmitter {
  public:
    explicit CodeEmitter(MachineFunction &MF, VirtRegMap &VRM, LiveStacks &LSS,
                         const LiveIntervals &LIS)
        : MF(MF), VRM(VRM), LSS(LSS), LIS(LIS),
          TII(MF.getSubtarget<EVMSubtarget>().getInstrInfo()) {}
    size_t stackHeight() const;
    void enterMBB(MachineBasicBlock *MBB, int Height);
    void emitInst(const MachineInstr *MI);
    void emitSWAP(unsigned Depth);
    void emitDUP(unsigned Depth);
    void emitPOP();
    void emitConstant(const APInt &Val);
    void emitConstant(uint64_t Val);
    void emitSymbol(const MachineInstr *MI, MCSymbol *Symbol);
    void emitFuncCall(const MachineInstr *MI);
    void emitRet(const MachineInstr *MI);
    void emitCondJump(const MachineInstr *MI, MachineBasicBlock *Target);
    void emitUncondJump(const MachineInstr *MI, MachineBasicBlock *Target);
    void emitLabelReference(const MachineInstr *Call);
    void emitReload(Register Reg);
    void emitSpill(Register Reg, unsigned DupIdx);
    /// Emit the fused callee-save and spill of the argument \p Reg, which
    /// sits at \p Depth on the stack. The previous contents of the spill
    /// slot surface, trade places with the argument, and the argument enters
    /// the slot. The loaded word ends up in the argument's stack position,
    /// so the stack height does not change.
    void emitCalleeSaveSpill(Register Reg, unsigned Depth);
    /// Push the previous contents of \p Reg's spill slot onto the stack.
    void emitCalleeSaveLoad(Register Reg);
    /// Pop the stack top into \p Reg's spill slot.
    void emitCalleeSaveRestore(Register Reg);
    /// Remove all the instructions that are not in stack form.
    void finalize();

  private:
    MachineFunction &MF;
    VirtRegMap &VRM;
    LiveStacks &LSS;
    const LiveIntervals &LIS;
    const EVMInstrInfo *TII;
    size_t StackHeight = 0;
    MachineBasicBlock *CurMBB = nullptr;
    DenseMap<const MachineInstr *, MCSymbol *> CallReturnSyms;

    void verify(const MachineInstr *MI) const;
    /// Push the current contents of the stack slot \p FI.
    void emitFrameLoad(int FI);
    /// Pop the stack top into the stack slot \p FI.
    void emitFrameStore(int FI);
    /// Get or create the spill slot (frame index) of \p Reg. The
    /// register's live interval is registered with LiveStacks, mirroring
    /// InlineSpiller, so that StackSlotColoring can shrink the spill area
    /// afterwards.
    int getStackSlot(Register Reg);
    /// Same as getStackSlot, but also mark the whole function live in the
    /// slot's LiveStacks interval. A callee-saved slot's memory word is
    /// occupied from the prologue to the epilogue, so StackSlotColoring
    /// must not share the slot.
    int getCalleeSaveStackSlot(Register Reg);
  };

  CodeEmitter Emitter;
  const EVMStackModel &StackModel;
  MachineFunction &MF;
  Stack CurrentStack;

  /// Emit stack operations to turn CurrentStack into \p TargetStack.
  void emitStackPermutations(const Stack &TargetStack);

  /// Creates the MI's entry stack from the 'CurrentStack' taking into
  /// account commutative property of the instruction.
  void emitMIEntryStack(const MachineInstr &MI);

  /// Remove the arguments from the stack and push the return values.
  void adjustStackForInst(const MachineInstr *MI, size_t NumArgs);

  /// Generate code for the instruction.
  void emitMI(const MachineInstr &MI);

  /// Emit spill instructions for the \p Defs, if needed. With
  /// \p SkipCalleeSaved set, registers that have a callee-saved slot are not
  /// stored. This is used for the entry block, where such arguments are
  /// stored by the fused triple in emitCalleeSaves instead.
  void emitSpills(const MachineBasicBlock &MBB,
                  MachineBasicBlock::const_iterator Start, const Stack &Defs,
                  bool SkipCalleeSaved = false);

  /// Emit the prologue of a recursive function with spills. It loads the
  /// previous contents of every spill slot onto the value stack. For a
  /// spilled argument the save is fused with the argument's spill store
  /// into a swap triple. This way the previous slot contents are saved in
  /// the same step that overwrites them. The loaded words are consumed by
  /// the return path. It stores each word back to its slot just before the
  /// return jump.
  void emitCalleeSaves();
};

} // namespace llvm

#endif // LLVM_LIB_TARGET_EVM_EVMSTACKIFYCODEEMITTER_H
