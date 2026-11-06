//===- MemorySlot.cpp - Memory slot interfaces for Yul --------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Lets mem2reg promote the variables inline assembly declares to SSA values.
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Yul/Yul.h"
#include "mlir/Interfaces/MemorySlotInterfaces.h"
#include "mlir/Interfaces/Utils/MemorySlotUtils.h"

using namespace mlir;
using namespace mlir::yul;

//===----------------------------------------------------------------------===//
// AllocaOp
//===----------------------------------------------------------------------===//

SmallVector<MemorySlot> AllocaOp::getPromotableSlots() {
  return {MemorySlot{getOut(), IntegerType::get(getContext(), 256)}};
}

Value AllocaOp::getDefaultValue(const MemorySlot &slot, OpBuilder &builder) {
  return ConstantOp::create(builder, getLoc(), slot.elemType,
                            builder.getIntegerAttr(slot.elemType, 0));
}

void AllocaOp::handleBlockArgument(const MemorySlot &slot,
                                   BlockArgument argument, OpBuilder &builder) {
}

std::optional<PromotableAllocationOpInterface>
AllocaOp::handlePromotionComplete(const MemorySlot &slot, Value defaultValue,
                                  OpBuilder &builder) {
  // mem2reg builds the default value for every slot, and it stays unused
  // unless a load is reached before any store.
  if (defaultValue && defaultValue.use_empty())
    defaultValue.getDefiningOp()->erase();
  erase();
  return std::nullopt;
}

//===----------------------------------------------------------------------===//
// LoadOp
//===----------------------------------------------------------------------===//

bool LoadOp::loadsFrom(const MemorySlot &slot) { return getPtr() == slot.ptr; }

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
         (*blockingUses.begin())->get() == slot.ptr && getPtr() == slot.ptr;
}

DeletionKind
LoadOp::removeBlockingUses(const MemorySlot &slot,
                           const SmallPtrSetImpl<OpOperand *> &blockingUses,
                           OpBuilder &builder, Value reachingDefinition,
                           const DataLayout &dataLayout) {
  getOut().replaceAllUsesWith(reachingDefinition);
  return DeletionKind::Delete;
}

//===----------------------------------------------------------------------===//
// StoreOp
//===----------------------------------------------------------------------===//

bool StoreOp::loadsFrom(const MemorySlot &slot) { return false; }

bool StoreOp::storesTo(const MemorySlot &slot) { return getPtr() == slot.ptr; }

Value StoreOp::getStored(const MemorySlot &slot, OpBuilder &builder,
                         Value reachingDef, const DataLayout &dataLayout) {
  return getVal();
}

bool StoreOp::canUsesBeRemoved(const MemorySlot &slot,
                               const SmallPtrSetImpl<OpOperand *> &blockingUses,
                               SmallVectorImpl<OpOperand *> &newBlockingUses,
                               const DataLayout &dataLayout) {
  return blockingUses.size() == 1 &&
         (*blockingUses.begin())->get() == slot.ptr && getPtr() == slot.ptr;
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
// SwitchOp
//===----------------------------------------------------------------------===//

bool SwitchOp::isRegionPromotable(const MemorySlot &slot, Region *region,
                                  bool hasValueStores) {
  return true;
}

void SwitchOp::setupPromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    llvm::SmallMapVector<Region *, Value, 2> &regionsToProcess) {
  for (Region *region : getRegions())
    regionsToProcess.insert({region, reachingDef});
}

Value SwitchOp::finalizePromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    const llvm::DenseMap<Block *, Value> &reachingAtBlockEnd,
    OpBuilder &builder) {
  if (!hasValueStores)
    return reachingDef;

  IRRewriter rewriter(builder);
  for (Region *region : getRegions())
    yieldSlotValue(*region, reachingDef, reachingAtBlockEnd);

  SmallVector<Type> resultTypes(getResultTypes());
  resultTypes.push_back(slot.elemType);
  return memoryslot::replaceWithNewResults(rewriter, *this, resultTypes)
      ->getResults()
      .back();
}

//===----------------------------------------------------------------------===//
// ForOp
//===----------------------------------------------------------------------===//

bool ForOp::isRegionPromotable(const MemorySlot &slot, Region *region,
                               bool hasValueStores) {
  return true;
}

/// A slot stored in the loop is carried from one iteration to the next: an
/// init arg, then an argument of each region.
void ForOp::setupPromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    llvm::SmallMapVector<Region *, Value, 2> &regionsToProcess) {
  if (!hasValueStores) {
    for (Region &region : (*this)->getRegions())
      regionsToProcess.insert({&region, reachingDef});
    return;
  }

  getInitArgsMutable().append(reachingDef);
  for (Region &region : (*this)->getRegions())
    regionsToProcess.insert(
        {&region, region.addArgument(slot.elemType, slot.ptr.getLoc())});
}

/// Passes the slot's value at each exit of a region on: yul.condition to the
/// body and the loop's results, yul.yield to the next region, yul.break to
/// the results and yul.continue to the next iteration.
Value ForOp::finalizePromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    const llvm::DenseMap<Block *, Value> &reachingAtBlockEnd,
    OpBuilder &builder) {
  if (!hasValueStores)
    return reachingDef;

  for (Region &region : (*this)->getRegions()) {
    Value carried = region.getArguments().back();
    for (Block &block : region)
      if (isa<ConditionOp, YieldOp>(block.getTerminator()))
        memoryslot::updateTerminator(&block, carried, reachingAtBlockEnd);
  }
  SmallVector<Operation *> exits;
  getEarlyExits(&getBody(), exits);
  for (Operation *exit : exits)
    memoryslot::updateTerminator(exit->getBlock(),
                                 getBody().getArguments().back(),
                                 reachingAtBlockEnd);

  IRRewriter rewriter(builder);
  SmallVector<Type> resultTypes(getResultTypes());
  resultTypes.push_back(slot.elemType);
  return memoryslot::replaceWithNewResults(rewriter, *this, resultTypes)
      ->getResults()
      .back();
}

/// The yul.break and yul.continue ops below `region` that exit this loop.
void ForOp::getEarlyExits(Region *region, SmallVectorImpl<Operation *> &exits) {
  region->walk<WalkOrder::PreOrder>([&](Operation *op) {
    if (op != getOperation() && isa<LoopOpInterface>(op))
      return WalkResult::skip();
    if (isa<BreakOp, ContinueOp>(op))
      exits.push_back(op);
    return WalkResult::advance();
  });
}
