//===---- EVMInlinePolicy.cpp - Inlining policy for EVM ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass adds the noinline attribute to the functions of every call graph
// cycle and the alwaysinline attribute to the other functions with one call
// site.
//
//===----------------------------------------------------------------------===//

#include "EVM.h"
#include "llvm/ADT/SCCIterator.h"
#include "llvm/Analysis/CallGraph.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/InitializePasses.h"

#define DEBUG_TYPE "evm-inline-policy"

using namespace llvm;

namespace {

class EVMInlinePolicy final : public ModulePass {
public:
  static char ID; // Pass ID
  EVMInlinePolicy() : ModulePass(ID) {}

  StringRef getPassName() const override { return "EVM inline policy"; }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<CallGraphWrapperPass>();
    ModulePass::getAnalysisUsage(AU);
  }

  bool runOnModule(Module &M) override;
};

} // end anonymous namespace

/// Keep the functions of every call graph cycle out of line. A function that
/// already has the alwaysinline attribute is left alone, because the two
/// attributes exclude each other.
static bool markRecursiveNoInline(CallGraph &CG) {
  bool Changed = false;
  for (auto SCCI = scc_begin(&CG); !SCCI.isAtEnd(); ++SCCI) {
    const auto &SCC = *SCCI;
    if (SCC.size() == 1 && !SCCI.hasCycle())
      continue;
    for (const auto *Node : SCC) {
      Function *F = Node->getFunction();
      if (!F || F->isDeclaration() || F->hasFnAttribute(Attribute::NoInline) ||
          F->hasFnAttribute(Attribute::AlwaysInline))
        continue;
      F->addFnAttr(Attribute::NoInline);
      Changed = true;
    }
  }
  return Changed;
}

/// Inline every function with one call site into its caller. A function of a
/// call graph cycle is already noinline and stays out of line.
static bool markSingleCallAlwaysInline(Module &M) {
  bool Changed = false;
  for (auto &F : M) {
    if (F.isDeclaration() || F.hasOptNone() ||
        F.hasFnAttribute(Attribute::NoInline) || !F.hasOneUse())
      continue;

    auto *Call = dyn_cast<CallInst>(*F.user_begin());

    // Skip non call instructions, recursive calls, or calls with noinline
    // attribute.
    if (!Call || Call->getFunction() == &F || Call->isNoInline())
      continue;

    F.addFnAttr(Attribute::AlwaysInline);
    Changed = true;
  }
  return Changed;
}

static bool runImpl(Module &M, CallGraph &CG) {
  bool Changed = markRecursiveNoInline(CG);
  Changed |= markSingleCallAlwaysInline(M);
  return Changed;
}

bool EVMInlinePolicy::runOnModule(Module &M) {
  if (skipModule(M))
    return false;
  return runImpl(M, getAnalysis<CallGraphWrapperPass>().getCallGraph());
}

char EVMInlinePolicy::ID = 0;

INITIALIZE_PASS_BEGIN(EVMInlinePolicy, "evm-inline-policy",
                      "Set the inlining policy of EVM functions", false, false)
INITIALIZE_PASS_DEPENDENCY(CallGraphWrapperPass)
INITIALIZE_PASS_END(EVMInlinePolicy, "evm-inline-policy",
                    "Set the inlining policy of EVM functions", false, false)

ModulePass *llvm::createEVMInlinePolicyPass() { return new EVMInlinePolicy; }

PreservedAnalyses EVMInlinePolicyPass::run(Module &M,
                                           ModuleAnalysisManager &AM) {
  runImpl(M, AM.getResult<CallGraphAnalysis>(M));
  return PreservedAnalyses::all();
}
