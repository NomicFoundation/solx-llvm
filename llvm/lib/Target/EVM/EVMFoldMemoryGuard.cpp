//===----- EVMFoldMemoryGuard.cpp - Fold the memory guard -------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass folds the front end's evm.memoryguard marker to
// `guard + evm-stack-region-size` and records the guard as the
// "evm-memory-guard" module flag, which EVMFinalizeStackFrames uses as the
// base of the spill region.
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

static constexpr const char *MemoryGuardFlag = "evm-memory-guard";

static bool foldMemoryGuard(Module &M) {
  Function *Decl =
      Intrinsic::getDeclarationIfExists(&M, Intrinsic::evm_memoryguard);
  if (!Decl)
    return false;

  assert(Decl->hasOneUser() && "Expected a single memoryguard call");
  auto *Call = cast<CallInst>(*Decl->user_begin());
  uint64_t Guard = cast<ConstantInt>(Call->getArgOperand(0))->getZExtValue();
  Call->replaceAllUsesWith(
      ConstantInt::get(Call->getType(), Guard + getEVMStackRegionSize()));
  Call->eraseFromParent();
  Decl->eraseFromParent();

  M.addModuleFlag(Module::Error, MemoryGuardFlag,
                  ConstantInt::get(Type::getInt64Ty(M.getContext()), Guard));
  return true;
}

std::optional<uint64_t> llvm::getEVMMemoryGuard(const Module &M) {
  if (auto *Guard = mdconst::extract_or_null<ConstantInt>(
          M.getModuleFlag(MemoryGuardFlag)))
    return Guard->getZExtValue();
  return std::nullopt;
}

PreservedAnalyses EVMFoldMemoryGuardPass::run(Module &M,
                                              ModuleAnalysisManager &) {
  if (!foldMemoryGuard(M))
    return PreservedAnalyses::all();
  return PreservedAnalyses::none();
}
