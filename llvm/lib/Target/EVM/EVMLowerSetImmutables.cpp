//===--- EVMLowerSetImmutables.cpp - Lower immutable stores -----*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass lowers each evm.setimmutable to a heap store of the value at each
// offset the "evm.immutables" metadata lists for its id. The offsets exist once
// the runtime code is assembled, so the driver attaches them to the deploy
// code. An immutable the runtime never loads has no offsets, and its
// setimmutable is erased without a store. Without the metadata, no immutable
// has offsets, and every setimmutable is erased.
//
// It must run before optimization so that the stores are optimized like any
// other. EVMVerifier catches a setimmutable that was never lowered.
//
//===----------------------------------------------------------------------===//

#include "EVM.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/IntrinsicsEVM.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/Module.h"

using namespace llvm;

// Named metadata the driver attaches to deploy code: each operand is an
// immutable's id followed by its offsets in the runtime code.
static constexpr StringLiteral ImmutablesMetadata = "evm.immutables";

static StringRef getID(const MDNode *Node) {
  return cast<MDString>(Node->getOperand(0))->getString();
}

// Stores each setimmutable's value at the offsets Immutables lists for its id,
// and erases the call.
static void storeImmutables(Function &Decl, const NamedMDNode &Immutables) {
  StringMap<const MDNode *> ImmutableByID;
  for (const auto *Immutable : Immutables.operands())
    ImmutableByID[getID(Immutable)] = Immutable;

  for (auto *U : make_early_inc_range(Decl.users())) {
    auto *Call = cast<CallInst>(U);
    auto *Addr = Call->getArgOperand(0);
    auto *Val = Call->getArgOperand(1);
    auto *ID = cast<MDNode>(
        cast<MetadataAsValue>(Call->getArgOperand(2))->getMetadata());
    if (const auto *Immutable = ImmutableByID.lookup(getID(ID))) {
      IRBuilder<> Builder(Call);
      for (const auto &Offset : drop_begin(Immutable->operands())) {
        auto *OffsetVal = ConstantInt::get(
            Addr->getType(),
            mdconst::extract<ConstantInt>(Offset)->getZExtValue());
        auto *Ptr = Builder.CreateIntToPtr(Builder.CreateAdd(Addr, OffsetVal),
                                           Builder.getPtrTy(EVMAS::AS_HEAP));
        Builder.CreateAlignedStore(Val, Ptr, Align(1));
      }
    }
    Call->eraseFromParent();
  }
}

// Erases every setimmutable, none of which has offsets to store at.
static void removeSetImmutables(Function &Decl) {
  for (auto *U : make_early_inc_range(Decl.users()))
    cast<CallInst>(U)->eraseFromParent();
}

static bool lowerSetImmutables(Module &M) {
  auto *Decl =
      Intrinsic::getDeclarationIfExists(&M, Intrinsic::evm_setimmutable);
  auto *Immutables = M.getNamedMetadata(ImmutablesMetadata);
  if (Decl) {
    if (Immutables)
      storeImmutables(*Decl, *Immutables);
    else
      removeSetImmutables(*Decl);
    Decl->eraseFromParent();
  }
  if (Immutables)
    M.eraseNamedMetadata(Immutables);
  return Decl || Immutables;
}

PreservedAnalyses EVMLowerSetImmutablesPass::run(Module &M,
                                                 ModuleAnalysisManager &) {
  if (!lowerSetImmutables(M))
    return PreservedAnalyses::all();
  return PreservedAnalyses::none();
}
