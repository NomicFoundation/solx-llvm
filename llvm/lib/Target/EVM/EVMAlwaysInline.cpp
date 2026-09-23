//===---- EVMAlwaysInline.cpp - Add alwaysinline attribute ------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass adds the alwaysinline attribute to functions with one call site,
// and the noinline attribute to compiler-generated `__sol.*` helpers that are
// shared by two or more call sites and are large enough to pay for the call.
//
// The Sol lowering emits repeated operations (array copies, ABI decoders and
// encoders, allocations, storage array operations) once per type as helper
// functions, and marks each of them with the "evm.sol_helper" attribute. A
// helper with a single call site is folded back by the alwaysinline rule
// below, as any other function. A helper with several call sites saves code
// only while it stays out of line, so the general inliner must not fold it
// back; that decision is per callee and depends on the helper's size against
// the call overhead, which is roughly the threshold option below.
//
//===----------------------------------------------------------------------===//

#include "EVM.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/CommandLine.h"

#define DEBUG_TYPE "evm-always-inline"

using namespace llvm;

/// A shared helper is kept out of line when it has at least this many
/// instructions. One EVM instruction is about 1.6 bytes after stackification,
/// so the default approximates the ~40 bytes at which a two-site helper starts
/// paying for the call overhead.
static cl::opt<unsigned> HelperNoInlineMinInsts(
    "evm-helper-noinline-min-insts", cl::Hidden, cl::init(24),
    cl::desc("Keep a compiler-generated helper with two or more call sites out "
             "of line when it has at least this many instructions"));

/// Set by the Sol lowering on every function it generates for a repeated
/// operation (see kHelperFnAttrName in mlir/Conversion/SolToYul/EVMUtil.h).
static constexpr StringLiteral HelperFnAttrName = "evm.sol_helper";

/// Number of call sites of \p F outside of \p F itself.
static unsigned countExternalCallSites(const Function &F) {
  unsigned N = 0;
  for (const User *U : F.users()) {
    const auto *Call = dyn_cast<CallBase>(U);
    if (Call && Call->getCalledFunction() == &F && Call->getFunction() != &F)
      ++N;
  }
  return N;
}

/// Number of instructions of \p F that produce code (no debug intrinsics, no
/// phis).
static unsigned countCodeInsts(const Function &F) {
  unsigned N = 0;
  for (const BasicBlock &BB : F)
    for (const Instruction &I : BB)
      if (!isa<DbgInfoIntrinsic>(I) && !isa<PHINode>(I))
        ++N;
  return N;
}

namespace {

class EVMAlwaysInline final : public ModulePass {
public:
  static char ID; // Pass ID
  EVMAlwaysInline() : ModulePass(ID) {}

  StringRef getPassName() const override { return "EVM always inline"; }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    ModulePass::getAnalysisUsage(AU);
  }

  bool runOnModule(Module &M) override;
};

} // end anonymous namespace

static bool runImpl(Module &M) {
  bool Changed = false;
  for (auto &F : M) {
    if (F.isDeclaration() || F.hasOptNone() ||
        F.hasFnAttribute(Attribute::NoInline))
      continue;

    // Shared, large enough compiler-generated helper: keep it out of line.
    if (F.hasFnAttribute(HelperFnAttrName) && countExternalCallSites(F) >= 2 &&
        countCodeInsts(F) >= HelperNoInlineMinInsts) {
      F.addFnAttr(Attribute::NoInline);
      Changed = true;
      continue;
    }

    if (!F.hasOneUse())
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
  return runImpl(M);
}

char EVMAlwaysInline::ID = 0;

INITIALIZE_PASS(EVMAlwaysInline, "evm-always-inline",
                "Add alwaysinline attribute to functions with one call site "
                "and noinline to shared compiler-generated helpers",
                false, false)

ModulePass *llvm::createEVMAlwaysInlinePass() { return new EVMAlwaysInline; }

PreservedAnalyses EVMAlwaysInlinePass::run(Module &M,
                                           ModuleAnalysisManager &AM) {
  runImpl(M);
  return PreservedAnalyses::all();
}
