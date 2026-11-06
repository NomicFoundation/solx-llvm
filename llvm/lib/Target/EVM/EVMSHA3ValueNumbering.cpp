//===-- EVMSHA3ValueNumbering.cpp - Merge equal sha3 calls ------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// A sha3 call reads memory, so every mapping access stores its key and slot
// to the same scratch words before hashing them. After inlining, one function
// writes and hashes the same words again for every access, and a nested or
// interleaved access writes other values to them in between. This pass works
// on what the memory holds:
//
// 1. A sha3 call over constant addresses whose words hold the same values as
//    the words of a dominating sha3 call returns that call's result.
// 2. A store to a constant address of the value its word already holds is
//    removed.
//
// A word's value is the value of the store that MemorySSA finds as the last
// write to all of it. Any other last write, such as a call, a partial store
// or a merge of paths, leaves the word unknown and the call or store as is.
//
//===----------------------------------------------------------------------===//

#include "EVM.h"
#include "llvm/ADT/PostOrderIterator.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/MemorySSA.h"
#include "llvm/Analysis/MemorySSAUpdater.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/IntrinsicsEVM.h"
#include <map>

using namespace llvm;

#define DEBUG_TYPE "evm-sha3-value-numbering"

STATISTIC(NumSHA3Merged, "Number of sha3 calls merged");
STATISTIC(NumStoresRemoved, "Number of stores of a value already in memory");

namespace {

constexpr uint64_t WordSize = 32;

/// The heap address of \p Ptr when it is a constant.
std::optional<uint64_t> getConstantAddress(const Value *Ptr) {
  if (isa<ConstantPointerNull>(Ptr))
    return 0;
  const auto *CE = dyn_cast<ConstantExpr>(Ptr);
  if (!CE || CE->getOpcode() != Instruction::IntToPtr)
    return std::nullopt;
  const auto *Addr = dyn_cast<ConstantInt>(CE->getOperand(0));
  if (!Addr || Addr->getValue().getActiveBits() > 64)
    return std::nullopt;
  return Addr->getZExtValue();
}

class SHA3ValueNumbering {
public:
  SHA3ValueNumbering(Function &F, MemorySSA &MSSA, DominatorTree &DT)
      : F(F), MSSA(MSSA), DT(DT), Updater(&MSSA),
        HeapPtrTy(PointerType::get(F.getContext(), EVMAS::AS_HEAP)),
        WordTy(IntegerType::get(F.getContext(), WordSize * 8)) {}

  bool run() {
    bool Changed = false;
    ReversePostOrderTraversal<Function *> RPOT(&F);
    for (BasicBlock *BB : RPOT)
      for (Instruction &I : make_early_inc_range(*BB))
        if (auto *II = dyn_cast<IntrinsicInst>(&I);
            II && II->getIntrinsicID() == Intrinsic::evm_sha3)
          Changed |= mergeSHA3(II);

    for (BasicBlock *BB : RPOT)
      for (Instruction &I : make_early_inc_range(*BB))
        if (auto *SI = dyn_cast<StoreInst>(&I))
          Changed |= removeStoreOfExistingValue(SI);
    return Changed;
  }

private:
  Function &F;
  MemorySSA &MSSA;
  DominatorTree &DT;
  MemorySSAUpdater Updater;
  PointerType *HeapPtrTy;
  IntegerType *WordTy;

  /// The sha3 calls seen so far, by their length and the values of their
  /// words.
  std::map<std::vector<Value *>, SmallVector<IntrinsicInst *, 2>> Hashes;

  /// The value the heap word at \p Addr holds where \p Start is the memory
  /// state, if a store wrote all of it last.
  Value *getWord(MemoryAccess *Start, uint64_t Addr) {
    Constant *Ptr =
        ConstantExpr::getIntToPtr(ConstantInt::get(WordTy, Addr), HeapPtrTy);
    MemoryLocation Loc(Ptr, LocationSize::precise(WordSize));
    MemoryAccess *Clobber =
        MSSA.getWalker()->getClobberingMemoryAccess(Start, Loc);
    auto *Def = dyn_cast<MemoryDef>(Clobber);
    if (!Def || MSSA.isLiveOnEntryDef(Def))
      return nullptr;
    auto *SI = dyn_cast_or_null<StoreInst>(Def->getMemoryInst());
    if (!SI || !SI->isSimple() ||
        SI->getPointerAddressSpace() != EVMAS::AS_HEAP ||
        SI->getValueOperand()->getType() != WordTy ||
        getConstantAddress(SI->getPointerOperand()) != Addr)
      return nullptr;
    return SI->getValueOperand();
  }

  bool mergeSHA3(IntrinsicInst *Call) {
    std::optional<uint64_t> Addr = getConstantAddress(Call->getArgOperand(0));
    auto *Len = dyn_cast<ConstantInt>(Call->getArgOperand(1));
    if (!Addr || !Len || Len->isZero() ||
        Len->getValue().getActiveBits() > 64 || Len->getZExtValue() % WordSize)
      return false;

    MemoryAccess *Start = MSSA.getMemoryAccess(Call)->getDefiningAccess();
    std::vector<Value *> Key{Len};
    for (uint64_t Offset = 0; Offset < Len->getZExtValue();
         Offset += WordSize) {
      Value *Word = getWord(Start, *Addr + Offset);
      if (!Word)
        return false;
      Key.push_back(Word);
    }

    SmallVector<IntrinsicInst *, 2> &Earlier = Hashes[Key];
    auto Dominating = find_if(
        Earlier, [&](IntrinsicInst *Hash) { return DT.dominates(Hash, Call); });
    if (Dominating == Earlier.end()) {
      Earlier.push_back(Call);
      return false;
    }

    LLVM_DEBUG(dbgs() << "Merging " << *Call << " into " << **Dominating
                      << '\n');
    Call->replaceAllUsesWith(*Dominating);
    Updater.removeMemoryAccess(Call);
    Call->eraseFromParent();
    ++NumSHA3Merged;
    return true;
  }

  bool removeStoreOfExistingValue(StoreInst *SI) {
    std::optional<uint64_t> Addr = getConstantAddress(SI->getPointerOperand());
    if (!Addr || !SI->isSimple() ||
        SI->getPointerAddressSpace() != EVMAS::AS_HEAP ||
        SI->getValueOperand()->getType() != WordTy)
      return false;

    MemoryAccess *Start = MSSA.getMemoryAccess(SI)->getDefiningAccess();
    if (getWord(Start, *Addr) != SI->getValueOperand())
      return false;

    LLVM_DEBUG(dbgs() << "Removing store of existing value " << *SI << '\n');
    Updater.removeMemoryAccess(SI);
    SI->eraseFromParent();
    ++NumStoresRemoved;
    return true;
  }
};

} // namespace

PreservedAnalyses EVMSHA3ValueNumberingPass::run(Function &F,
                                                 FunctionAnalysisManager &AM) {
  auto &MSSA = AM.getResult<MemorySSAAnalysis>(F).getMSSA();
  auto &DT = AM.getResult<DominatorTreeAnalysis>(F);
  if (!SHA3ValueNumbering(F, MSSA, DT).run())
    return PreservedAnalyses::all();

  PreservedAnalyses PA;
  PA.preserveSet<CFGAnalyses>();
  PA.preserve<MemorySSAAnalysis>();
  return PA;
}
