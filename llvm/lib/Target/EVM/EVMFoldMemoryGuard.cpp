//===----- EVMFoldMemoryGuard.cpp - Fold the memory guard -------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass folds the front end's evm.memoryguard marker to the sum of the
// "evm-memory-guard" and "evm-stack-region-size" module flags, i.e. to the
// address just past the spill region EVMFinalizeStackFrames lays out from the
// same two flags.
//
// It must run before optimization so that the free memory pointer's
// initializer is a plain constant. EVMVerifier catches a marker that was
// never folded.
//
//===----------------------------------------------------------------------===//

#include "EVM.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/IntrinsicsEVM.h"
#include "llvm/IR/Module.h"

using namespace llvm;

static uint64_t getFlag(const Module &M, StringRef Name) {
  if (auto *Value = mdconst::extract_or_null<ConstantInt>(M.getModuleFlag(Name)))
    return Value->getZExtValue();
  return 0;
}

static bool foldMemoryGuard(Module &M) {
  Function *Decl =
      Intrinsic::getDeclarationIfExists(&M, Intrinsic::evm_memoryguard);
  if (!Decl)
    return false;

  assert(Decl->hasOneUser() && "Expected a single memoryguard call");
  auto *Call = cast<CallInst>(*Decl->user_begin());
  uint64_t HeapStart = getFlag(M, "evm-memory-guard") +
                       getFlag(M, "evm-stack-region-size");
  Call->replaceAllUsesWith(ConstantInt::get(Call->getType(), HeapStart));
  Call->eraseFromParent();
  Decl->eraseFromParent();
  return true;
}

PreservedAnalyses EVMFoldMemoryGuardPass::run(Module &M,
                                              ModuleAnalysisManager &) {
  if (!foldMemoryGuard(M))
    return PreservedAnalyses::all();
  return PreservedAnalyses::none();
}
