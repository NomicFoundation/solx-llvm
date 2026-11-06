//===- MemorySlot.cpp - Memory slot interfaces for Sol --------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Lets mem2reg promote the stack slots of locals, parameters and return
// variables to SSA values.
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/Dialect/Sol/Utils.h"
#include "mlir/Interfaces/MemorySlotInterfaces.h"
#include "mlir/Interfaces/Utils/MemorySlotUtils.h"

using namespace mlir;
using namespace mlir::sol;

//===----------------------------------------------------------------------===//
// AllocaOp
//===----------------------------------------------------------------------===//

SmallVector<MemorySlot> AllocaOp::getPromotableSlots() {
  if (!isStackPtr(getAddr().getType()))
    return {};
  return {MemorySlot{getAddr(), getEltType(getAddr().getType())}};
}

Value AllocaOp::getDefaultValue(const MemorySlot &slot, OpBuilder &builder) {
  return genDefaultVal(builder, slot.elemType, getLoc());
}

void AllocaOp::handleBlockArgument(const MemorySlot &slot,
                                   BlockArgument argument, OpBuilder &builder) {
}

std::optional<PromotableAllocationOpInterface>
AllocaOp::handlePromotionComplete(const MemorySlot &slot, Value defaultValue,
                                  OpBuilder &builder) {
  // mem2reg builds the default value for every slot, and it stays unused
  // unless a load is reached before any store. Some types build it from
  // several ops, which go with it.
  if (defaultValue && defaultValue.use_empty()) {
    SmallVector<Operation *> dead{defaultValue.getDefiningOp()};
    while (!dead.empty()) {
      Operation *op = dead.pop_back_val();
      SmallVector<Value> operands(op->getOperands());
      op->erase();
      for (Value operand : operands)
        if (Operation *definition = operand.getDefiningOp())
          if (definition->use_empty())
            dead.push_back(definition);
    }
  }
  erase();
  return std::nullopt;
}

//===----------------------------------------------------------------------===//
// LoadOp
//===----------------------------------------------------------------------===//

bool LoadOp::loadsFrom(const MemorySlot &slot) { return getAddr() == slot.ptr; }

bool LoadOp::storesTo(const MemorySlot &slot) { return false; }

Value LoadOp::getStored(const MemorySlot &slot, OpBuilder &builder,
                        Value reachingDef, const DataLayout &dataLayout) {
  llvm_unreachable("a load stores nothing");
}

bool LoadOp::canUsesBeRemoved(const MemorySlot &slot,
                              const SmallPtrSetImpl<OpOperand *> &blockingUses,
                              SmallVectorImpl<OpOperand *> &newBlockingUses,
                              const DataLayout &dataLayout) {
  return blockingUses.size() == 1 &&
         (*blockingUses.begin())->get() == slot.ptr && getAddr() == slot.ptr;
}

DeletionKind
LoadOp::removeBlockingUses(const MemorySlot &slot,
                           const SmallPtrSetImpl<OpOperand *> &blockingUses,
                           OpBuilder &builder, Value reachingDefinition,
                           const DataLayout &dataLayout) {
  getResult().replaceAllUsesWith(reachingDefinition);
  return DeletionKind::Delete;
}

//===----------------------------------------------------------------------===//
// StoreOp
//===----------------------------------------------------------------------===//

bool StoreOp::loadsFrom(const MemorySlot &slot) { return false; }

bool StoreOp::storesTo(const MemorySlot &slot) { return getAddr() == slot.ptr; }

Value StoreOp::getStored(const MemorySlot &slot, OpBuilder &builder,
                         Value reachingDef, const DataLayout &dataLayout) {
  return getVal();
}

bool StoreOp::canUsesBeRemoved(const MemorySlot &slot,
                               const SmallPtrSetImpl<OpOperand *> &blockingUses,
                               SmallVectorImpl<OpOperand *> &newBlockingUses,
                               const DataLayout &dataLayout) {
  return blockingUses.size() == 1 &&
         (*blockingUses.begin())->get() == slot.ptr && getAddr() == slot.ptr;
}

DeletionKind
StoreOp::removeBlockingUses(const MemorySlot &slot,
                            const SmallPtrSetImpl<OpOperand *> &blockingUses,
                            OpBuilder &builder, Value reachingDefinition,
                            const DataLayout &dataLayout) {
  return DeletionKind::Delete;
}

//===----------------------------------------------------------------------===//
// IfOp
//===----------------------------------------------------------------------===//

/// Adds the slot's value at the end of each block of `region` that yields, as
/// a new last operand. A block ending in another terminator leaves the region
/// where nothing reads the slot again.
static void yieldSlotValue(Region &region, Value reachingDef,
                           const DenseMap<Block *, Value> &reachingAtBlockEnd) {
  for (Block &block : region)
    if (isa<YieldOp>(block.getTerminator()))
      memoryslot::updateTerminator(&block, reachingDef, reachingAtBlockEnd);
}

bool IfOp::isRegionPromotable(const MemorySlot &slot, Region *region,
                              bool hasValueStores) {
  return true;
}

void IfOp::setupPromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    llvm::SmallMapVector<Region *, Value, 2> &regionsToProcess) {
  regionsToProcess.insert({&getThenRegion(), reachingDef});
  regionsToProcess.insert({&getElseRegion(), reachingDef});
}

Value IfOp::finalizePromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    const llvm::DenseMap<Block *, Value> &reachingAtBlockEnd,
    OpBuilder &builder) {
  if (!hasValueStores)
    return reachingDef;

  IRRewriter rewriter(builder);
  yieldSlotValue(getThenRegion(), reachingDef, reachingAtBlockEnd);
  if (getElseRegion().empty()) {
    OpBuilder::InsertionGuard guard(rewriter);
    rewriter.createBlock(&getElseRegion());
    YieldOp::create(rewriter, getLoc(), ValueRange{reachingDef});
  } else {
    yieldSlotValue(getElseRegion(), reachingDef, reachingAtBlockEnd);
  }

  SmallVector<Type> resultTypes(getResultTypes());
  resultTypes.push_back(slot.elemType);
  return memoryslot::replaceWithNewResults(rewriter, *this, resultTypes)
      ->getResults()
      .back();
}

//===----------------------------------------------------------------------===//
// ScopeOp
//===----------------------------------------------------------------------===//

bool ScopeOp::isRegionPromotable(const MemorySlot &slot, Region *region,
                                 bool hasValueStores) {
  // A sol.leave carries no value, so a slot stored inside a scope that one
  // exits stays in memory.
  if (!hasValueStores)
    return true;
  return !getBodyRegion()
              .walk([&](LeaveOp leave) {
                return leave->getParentOfType<ScopeOp>() == *this
                           ? WalkResult::interrupt()
                           : WalkResult::advance();
              })
              .wasInterrupted();
}

void ScopeOp::setupPromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    llvm::SmallMapVector<Region *, Value, 2> &regionsToProcess) {
  regionsToProcess.insert({&getBodyRegion(), reachingDef});
}

Value ScopeOp::finalizePromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    const llvm::DenseMap<Block *, Value> &reachingAtBlockEnd,
    OpBuilder &builder) {
  if (!hasValueStores)
    return reachingDef;

  IRRewriter rewriter(builder);
  yieldSlotValue(getBodyRegion(), reachingDef, reachingAtBlockEnd);

  SmallVector<Type> resultTypes(getResultTypes());
  resultTypes.push_back(slot.elemType);
  return memoryslot::replaceWithNewResults(rewriter, *this, resultTypes)
      ->getResults()
      .back();
}

//===----------------------------------------------------------------------===//
// TryOp
//===----------------------------------------------------------------------===//

bool TryOp::isRegionPromotable(const MemorySlot &slot, Region *region,
                               bool hasValueStores) {
  return true;
}

void TryOp::setupPromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    llvm::SmallMapVector<Region *, Value, 2> &regionsToProcess) {
  // Each clause runs at most once, entered from before the op.
  for (Region *region : getRegions())
    regionsToProcess.insert({region, reachingDef});
}

Value TryOp::finalizePromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    const llvm::DenseMap<Block *, Value> &reachingAtBlockEnd,
    OpBuilder &builder) {
  if (!hasValueStores)
    return reachingDef;

  IRRewriter rewriter(builder);
  // A missing panic or error clause never runs, and a missing fallback
  // reverts, but a missing success clause falls through.
  for (Region *region : getRegions())
    yieldSlotValue(*region, reachingDef, reachingAtBlockEnd);
  if (getSuccessRegion().empty()) {
    OpBuilder::InsertionGuard guard(rewriter);
    rewriter.createBlock(&getSuccessRegion());
    YieldOp::create(rewriter, getLoc(), ValueRange{reachingDef});
  }

  SmallVector<Type> resultTypes(getResultTypes());
  resultTypes.push_back(slot.elemType);
  return memoryslot::replaceWithNewResults(rewriter, *this, resultTypes)
      ->getResults()
      .back();
}
