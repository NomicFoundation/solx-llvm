//===-- EVMMarkRecursiveFunctions.cpp - Mark recursive fuctions --*- C++-*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass marks all recursive functions in the module with the
// "evm-recursive" attribute by analyzing the call graph. We dont' need to check
// functions to detect unknown calls (as it is implemented in FunctionAttrs.cpp,
// function createSCCNodeSet), because all functions are known at compile time,
// and we don't have any indirect calls.
// Stackification depends on this attribute. Spill slots live at fixed
// memory addresses, so every activation of a recursive function reuses
// them. For marked functions the stackifier callee-saves each spill slot.
//
//===----------------------------------------------------------------------===//

#include "EVM.h"
#include "llvm/ADT/SCCIterator.h"
#include "llvm/Analysis/CallGraph.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/InitializePasses.h"

#define DEBUG_TYPE "evm-mark-recursive-functions"

using namespace llvm;

namespace {

class EVMMarkRecursiveFunctions final : public ModulePass {
public:
  static char ID; // Pass ID
  EVMMarkRecursiveFunctions() : ModulePass(ID) {}

  StringRef getPassName() const override {
    return "EVM mark recursive functions";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<CallGraphWrapperPass>();
    ModulePass::getAnalysisUsage(AU);
  }

  bool runOnModule(Module &M) override;
};

} // end anonymous namespace

static bool runImpl(CallGraph &CG) {
  bool Changed = false;
  unsigned SCCId = 0;
  for (auto SCCI = scc_begin(&CG); !SCCI.isAtEnd(); ++SCCI) {
    const auto &SCC = *SCCI;
    // Only mark indirect recursive functions (size > 1) or self-recursive
    // functions (size == 1 with a cycle). Size can't be zero, since we
    // always have at least one node in the SCC.
    if (SCC.size() == 1 && !SCCI.hasCycle())
      continue;

    // Also mark each function with the id of its call graph cycle. A call
    // into a different cycle can never re-enter the caller. This info is
    // for spilling values in recursive functions.
    const std::string Id = std::to_string(SCCId++);
    for (const auto *Node : SCC) {
      Function *F = Node->getFunction();
      if (!F || F->isDeclaration())
        continue;
      F->addFnAttr("evm-recursive");
      F->addFnAttr("evm-recursive-scc", Id);
      Changed = true;
    }
  }
  return Changed;
}

bool EVMMarkRecursiveFunctions::runOnModule(Module &M) {
  return runImpl(getAnalysis<CallGraphWrapperPass>().getCallGraph());
}

char EVMMarkRecursiveFunctions::ID = 0;

INITIALIZE_PASS_BEGIN(EVMMarkRecursiveFunctions, DEBUG_TYPE,
                      "Mark all recursive functions", false, false)
INITIALIZE_PASS_DEPENDENCY(CallGraphWrapperPass)
INITIALIZE_PASS_END(EVMMarkRecursiveFunctions, DEBUG_TYPE,
                    "Mark all recursive functions", false, false)

ModulePass *llvm::createEVMMarkRecursiveFunctionsPass() {
  return new EVMMarkRecursiveFunctions;
}

PreservedAnalyses
EVMMarkRecursiveFunctionsPass::run(Module &M, ModuleAnalysisManager &AM) {
  runImpl(AM.getResult<CallGraphAnalysis>(M));
  return PreservedAnalyses::all();
}
