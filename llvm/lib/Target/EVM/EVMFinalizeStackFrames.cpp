//===----- EVMFinalizeStackFrames.cpp - Finalize stack frames --*- C++ -*--===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass calculates stack size for each function and replaces frame indices
// with their offsets.
//
//===----------------------------------------------------------------------===//

#include "EVM.h"
#include "MCTargetDesc/EVMMCTargetDesc.h"
#include "TargetInfo/EVMTargetInfo.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineModuleInfo.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/CodeGen/TargetInstrInfo.h"
#include "llvm/CodeGen/TargetSubtargetInfo.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Module.h"
#include "llvm/InitializePasses.h"

using namespace llvm;

#define DEBUG_TYPE "evm-finalize-stack-frames"
#define PASS_NAME "EVM finalize stack frames"

namespace {
class EVMFinalizeStackFrames : public ModulePass {
public:
  static char ID;

  EVMFinalizeStackFrames() : ModulePass(ID) {
    initializeEVMFinalizeStackFramesPass(*PassRegistry::getPassRegistry());
  }

  bool runOnModule(Module &M) override;

  StringRef getPassName() const override { return PASS_NAME; }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<MachineModuleInfoWrapperPass>();
    AU.addPreserved<MachineModuleInfoWrapperPass>();
    AU.setPreservesAll();
    ModulePass::getAnalysisUsage(AU);
  }

private:
  /// Calculate the stack allocation offsets for all stack objects.
  uint64_t calculateFrameObjectOffsets(MachineFunction &MF) const;

  /// Replace frame indices with their corresponding offsets.
  void replaceFrameIndices(MachineFunction &MF,
                           uint64_t StackRegionStart) const;
};
} // end anonymous namespace

char EVMFinalizeStackFrames::ID = 0;

INITIALIZE_PASS_BEGIN(EVMFinalizeStackFrames, DEBUG_TYPE, PASS_NAME, false,
                      false)
INITIALIZE_PASS_DEPENDENCY(MachineModuleInfoWrapperPass)
INITIALIZE_PASS_END(EVMFinalizeStackFrames, DEBUG_TYPE, PASS_NAME, false, false)

ModulePass *llvm::createEVMFinalizeStackFrames() {
  return new EVMFinalizeStackFrames();
}

uint64_t
EVMFinalizeStackFrames::calculateFrameObjectOffsets(MachineFunction &MF) const {
  // Bail out if there are no stack objects.
  auto &MFI = MF.getFrameInfo();
  if (!MFI.hasStackObjects())
    return 0;

  // Set the stack offsets for each object.
  uint64_t StackSize = 0;
  for (int I = 0, E = MFI.getObjectIndexEnd(); I != E; ++I) {
    if (MFI.isDeadObjectIndex(I))
      continue;

    MFI.setObjectOffset(I, StackSize);
    StackSize += MFI.getObjectSize(I);
  }

  assert(StackSize % 32 == 0 && "Stack size must be a multiple of 32 bytes");
  return StackSize;
}

void EVMFinalizeStackFrames::replaceFrameIndices(
    MachineFunction &MF, uint64_t StackRegionStart) const {
  auto &MFI = MF.getFrameInfo();
  assert(MFI.hasStackObjects() &&
         "Cannot replace frame indices without stack objects");

  const TargetInstrInfo *TII = MF.getSubtarget().getInstrInfo();
  for (MachineBasicBlock &MBB : MF) {
    for (MachineInstr &MI : make_early_inc_range(MBB)) {
      if (MI.getOpcode() != EVM::PUSH_FRAME)
        continue;

      assert(MI.getNumOperands() == 1 && "PUSH_FRAME must have one operand");
      MachineOperand &FIOp = MI.getOperand(0);
      assert(FIOp.isFI() && "Expected a frame index operand");

      // Replace the frame index with the corresponding stack offset.
      APInt Offset(256,
                   StackRegionStart + MFI.getObjectOffset(FIOp.getIndex()));
      unsigned PushOpc = EVM::getPUSHOpcode(Offset);
      auto NewMI = BuildMI(MBB, MI, MI.getDebugLoc(),
                           TII->get(EVM::getStackOpcode(PushOpc)));
      if (PushOpc != EVM::PUSH0)
        NewMI.addCImm(ConstantInt::get(MF.getFunction().getContext(), Offset));

      MI.eraseFromParent();
    }
  }
}

bool EVMFinalizeStackFrames::runOnModule(Module &M) {
  LLVM_DEBUG({ dbgs() << "********** Finalize stack frames **********\n"; });

  uint64_t TotalStackSize = 0;
  MachineModuleInfo &MMI = getAnalysis<MachineModuleInfoWrapperPass>().getMMI();
  SmallVector<std::pair<MachineFunction *, uint64_t>, 8> ToReplaceFI;

  // Collect memoryguard instructiions in the module.
  uint64_t MemoryGuard = 128;
  SmallVector<MachineInstr *> MemoryGuardInsts;
  for (Function &F : M) {
    MachineFunction *MF = MMI.getMachineFunction(F);
    if (!MF)
      continue;

    for (MachineBasicBlock &MBB : *MF)
      for (MachineInstr &MI : MBB)
        if (MI.getOpcode() == EVM::MEMORYGUARD_S) {
          // Stack form: the immediate is operand 0 (no def register).
          const APInt &ValImm = MI.getOperand(0).getCImm()->getValue();
          if (ValImm.getActiveBits() > 64)
            report_fatal_error("Memory guard value does not fit in 64 bits.");
          uint64_t Val = ValImm.getZExtValue();
          if (MemoryGuardInsts.empty())
            MemoryGuard = Val;
          else
            assert(Val == MemoryGuard);

          MemoryGuardInsts.push_back(&MI);
        }
  }

  if (MemoryGuard % 32 != 0)
    report_fatal_error("Stack region offset must be a multiple of 32 bytes.");

  // Calculate the stack size for each function.
  for (Function &F : M) {
    MachineFunction *MF = MMI.getMachineFunction(F);
    if (!MF)
      continue;

    uint64_t StackSize = calculateFrameObjectOffsets(*MF);
    if (StackSize == 0)
      continue;

    uint64_t StackRegionStart = MemoryGuard + TotalStackSize;
    ToReplaceFI.emplace_back(MF, StackRegionStart);
    TotalStackSize += StackSize;

    LLVM_DEBUG({
      dbgs() << "Stack size for function " << MF->getName()
             << " is: " << StackSize
             << " and starting offset is: " << StackRegionStart << "\n";
    });
  }
  LLVM_DEBUG({ dbgs() << "Total stack size: " << TotalStackSize << "\n"; });

  // Report the spill area offset and size to the driver via module metadata,
  // so it can label the dumped artifacts of units where spilling occurred.
  // The offset is the memory guard value the area starts at. This is a purely
  // diagnostic channel: dropping the metadata loses the report, not
  // correctness.
  if (TotalStackSize > 0) {
    LLVMContext &Ctx = M.getContext();
    Type *Int64Ty = Type::getInt64Ty(Ctx);
    auto AddReport = [&](StringRef Name, uint64_t Value) {
      NamedMDNode *MD = M.getOrInsertNamedMetadata(Name);
      MD->clearOperands();
      MD->addOperand(MDNode::get(
          Ctx, ConstantAsMetadata::get(ConstantInt::get(Int64Ty, Value))));
    };
    AddReport("evm-spill-area-offset", MemoryGuard);
    AddReport("evm-spill-area-size", TotalStackSize);
  }

  // Replace frame indices with their offsets.
  for (auto &[MF, StackRegionStart] : ToReplaceFI)
    replaceFrameIndices(*MF, StackRegionStart);

  // Rewrite memory guard instructions with updated values.
  APInt NewMemoryGuard(256, MemoryGuard + TotalStackSize);
  for (auto *MI : MemoryGuardInsts) {
    unsigned PushOpc = EVM::getPUSHOpcode(NewMemoryGuard);
    MachineFunction *MF = MI->getMF();
    const TargetInstrInfo *TII = MF->getSubtarget().getInstrInfo();
    auto NewMI = BuildMI(*MI->getParent(), MI, MI->getDebugLoc(),
                         TII->get(EVM::getStackOpcode(PushOpc)));
    assert(PushOpc != EVM::PUSH0);
    NewMI.addCImm(
        ConstantInt::get(MF->getFunction().getContext(), NewMemoryGuard));
    MI->eraseFromParent();
  }

  return TotalStackSize > 0;
}
