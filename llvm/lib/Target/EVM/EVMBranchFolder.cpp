//===------------ EVMBranchFolder.cpp - branch folding for EVM ------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass runs the generic BranchFolder after EVM stackification, but with
// common-code hoisting disabled.
//
//===----------------------------------------------------------------------===//

#include "EVM.h"
#include "llvm/Analysis/ProfileSummaryInfo.h"
#include "llvm/CodeGen/BranchFolding.h"
#include "llvm/CodeGen/MBFIWrapper.h"
#include "llvm/CodeGen/MachineBlockFrequencyInfo.h"
#include "llvm/CodeGen/MachineBranchProbabilityInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/CodeGen/TargetSubtargetInfo.h"
#include "llvm/Target/TargetMachine.h"

using namespace llvm;

#define DEBUG_TYPE "evm-branch-folder"

namespace {
class EVMBranchFolder final : public MachineFunctionPass {
public:
  static char ID;
  EVMBranchFolder() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override { return "EVM branch folder"; }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<MachineBlockFrequencyInfoWrapperPass>();
    AU.addRequired<MachineBranchProbabilityInfoWrapperPass>();
    AU.addRequired<ProfileSummaryInfoWrapperPass>();
    AU.addRequired<TargetPassConfig>();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  MachineFunctionProperties getRequiredProperties() const override {
    return MachineFunctionProperties().setNoPHIs();
  }

  bool runOnMachineFunction(MachineFunction &MF) override;
};
} // end anonymous namespace

char EVMBranchFolder::ID = 0;
INITIALIZE_PASS(EVMBranchFolder, DEBUG_TYPE, "EVM branch folder", false, false)

FunctionPass *llvm::createEVMBranchFolder() { return new EVMBranchFolder(); }

bool EVMBranchFolder::runOnMachineFunction(MachineFunction &MF) {
  if (skipFunction(MF.getFunction()))
    return false;

  auto *PassConfig = &getAnalysis<TargetPassConfig>();
  bool EnableTailMerge = !MF.getTarget().requiresStructuredCFG() &&
                         PassConfig->getEnableTailMerge();
  MBFIWrapper MBBFreqInfo(
      getAnalysis<MachineBlockFrequencyInfoWrapperPass>().getMBFI());
  BranchFolder Folder(
      EnableTailMerge, /*CommonHoist=*/false, MBBFreqInfo,
      getAnalysis<MachineBranchProbabilityInfoWrapperPass>().getMBPI(),
      &getAnalysis<ProfileSummaryInfoWrapperPass>().getPSI());
  return Folder.OptimizeFunction(MF, MF.getSubtarget().getInstrInfo(),
                                 MF.getSubtarget().getRegisterInfo());
}
