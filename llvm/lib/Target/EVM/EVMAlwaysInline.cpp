//===---- EVMAlwaysInline.cpp - Add alwaysinline attribute ------*- C++ -*-===//
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

#define DEBUG_TYPE "evm-always-inline"

using namespace llvm;

namespace {

class EVMAlwaysInline final : public ModulePass {
public:
  static char ID; // Pass ID
  EVMAlwaysInline() : ModulePass(ID) {}

  StringRef getPassName() const override { return "EVM always inline"; }

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

static bool runImpl(Module &M, CallGraph &CG) {
  bool Changed = markRecursiveNoInline(CG);
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

bool EVMAlwaysInline::runOnModule(Module &M) {
  if (skipModule(M))
    return false;
  return runImpl(M, getAnalysis<CallGraphWrapperPass>().getCallGraph());
}

char EVMAlwaysInline::ID = 0;

INITIALIZE_PASS_BEGIN(EVMAlwaysInline, "evm-always-inline",
                      "Add noinline to recursive functions and alwaysinline "
                      "to functions with one call site",
                      false, false)
INITIALIZE_PASS_DEPENDENCY(CallGraphWrapperPass)
INITIALIZE_PASS_END(EVMAlwaysInline, "evm-always-inline",
                    "Add noinline to recursive functions and alwaysinline "
                    "to functions with one call site",
                    false, false)

ModulePass *llvm::createEVMAlwaysInlinePass() { return new EVMAlwaysInline; }

PreservedAnalyses EVMAlwaysInlinePass::run(Module &M,
                                           ModuleAnalysisManager &AM) {
  runImpl(M, AM.getResult<CallGraphAnalysis>(M));
  return PreservedAnalyses::all();
}
