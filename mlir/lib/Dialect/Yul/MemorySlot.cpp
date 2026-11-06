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
// Region ops
//===----------------------------------------------------------------------===//

/// The bridge of the dialect a slot that isn't a Yul value belongs to, which a
/// Yul op carries the slot's value through, or null.
static const BridgeInterface *getBridge(const MemorySlot &slot) {
  if (isI256OrI256LLVMStruct(slot.elemType))
    return nullptr;
  return slot.ptr.getType().getDialect().getRegisteredInterface<BridgeInterface>();
}

/// Whether a Yul op can carry the slot's value out of a region that stores it.
static bool isCarriable(const MemorySlot &slot) {
  return isI256OrI256LLVMStruct(slot.elemType) || getBridge(slot);
}

/// The Yul value a Yul op carries for `value` of the slot.
static Value toCarried(const MemorySlot &slot, Value value,
                       OpBuilder &builder) {
  if (const BridgeInterface *bridge = getBridge(slot))
    return bridge->toYul(builder, value.getLoc(), value);
  return value;
}

/// The slot's value that `carried` stands for.
static Value fromCarried(const MemorySlot &slot, Value carried,
                         OpBuilder &builder) {
  if (const BridgeInterface *bridge = getBridge(slot))
    return bridge->fromYul(builder, carried.getLoc(), carried, slot.elemType);
  return carried;
}

/// Adds to the terminator of `block`, as a new last operand, what a Yul op
/// carries for the slot's value at the end of the block, or `entry` when the
/// block leaves it as it entered.
static void carryAtEnd(const MemorySlot &slot, Block *block, Value entry,
                       const DenseMap<Block *, Value> &reachingAtBlockEnd,
                       OpBuilder &builder) {
  Operation *terminator = block->getTerminator();
  Value carried = entry;
  if (Value reachingDef = reachingAtBlockEnd.lookup(block)) {
    OpBuilder::InsertionGuard guard(builder);
    builder.setInsertionPoint(terminator);
    carried = toCarried(slot, reachingDef, builder);
  }
  terminator->insertOperands(terminator->getNumOperands(), {carried});
}

/// Carries the slot's value out of each block of `region` that yields. A block
/// ending in another terminator leaves the region where nothing reads the slot
/// again.
static void yieldSlotValue(const MemorySlot &slot, Region &region, Value entry,
                           const DenseMap<Block *, Value> &reachingAtBlockEnd,
                           OpBuilder &builder) {
  for (Block &block : region)
    if (isa<YieldOp>(block.getTerminator()))
      carryAtEnd(slot, &block, entry, reachingAtBlockEnd, builder);
}

/// Replaces `op` with one that also returns the carried value of the slot, of
/// `carriedType`, and returns the slot's value after it.
static Value addCarriedResult(const MemorySlot &slot, Operation *op,
                              Type carriedType, OpBuilder &builder) {
  IRRewriter rewriter(builder);
  SmallVector<Type> resultTypes(op->getResultTypes());
  resultTypes.push_back(carriedType);
  Operation *newOp =
      memoryslot::replaceWithNewResults(rewriter, op, resultTypes);
  OpBuilder::InsertionGuard guard(builder);
  builder.setInsertionPointAfter(newOp);
  return fromCarried(slot, newOp->getResults().back(), builder);
}

//===----------------------------------------------------------------------===//
// IfOp
//===----------------------------------------------------------------------===//

bool IfOp::isRegionPromotable(const MemorySlot &slot, Region *region,
                              bool hasValueStores) {
  return !hasValueStores || isCarriable(slot);
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

  OpBuilder::InsertionGuard guard(builder);
  builder.setInsertionPoint(*this);
  Value entry = toCarried(slot, reachingDef, builder);
  yieldSlotValue(slot, getThenRegion(), entry, reachingAtBlockEnd, builder);
  if (getElseRegion().empty()) {
    builder.createBlock(&getElseRegion());
    YieldOp::create(builder, getLoc(), ValueRange{entry});
  } else {
    yieldSlotValue(slot, getElseRegion(), entry, reachingAtBlockEnd, builder);
  }
  return addCarriedResult(slot, *this, entry.getType(), builder);
}

//===----------------------------------------------------------------------===//
// SwitchOp
//===----------------------------------------------------------------------===//

bool SwitchOp::isRegionPromotable(const MemorySlot &slot, Region *region,
                                  bool hasValueStores) {
  return !hasValueStores || isCarriable(slot);
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

  OpBuilder::InsertionGuard guard(builder);
  builder.setInsertionPoint(*this);
  Value entry = toCarried(slot, reachingDef, builder);
  for (Region *region : getRegions())
    yieldSlotValue(slot, *region, entry, reachingAtBlockEnd, builder);
  return addCarriedResult(slot, *this, entry.getType(), builder);
}

//===----------------------------------------------------------------------===//
// ForOp
//===----------------------------------------------------------------------===//

bool ForOp::isRegionPromotable(const MemorySlot &slot, Region *region,
                               bool hasValueStores) {
  return !hasValueStores || isCarriable(slot);
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

  OpBuilder builder(*this);
  Value init = toCarried(slot, reachingDef, builder);
  getInitArgsMutable().append(init);
  for (Region &region : (*this)->getRegions()) {
    Value carried = region.addArgument(init.getType(), slot.ptr.getLoc());
    builder.setInsertionPointToStart(&region.front());
    regionsToProcess.insert({&region, fromCarried(slot, carried, builder)});
  }
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
        carryAtEnd(slot, &block, carried, reachingAtBlockEnd, builder);
  }
  SmallVector<Operation *> exits;
  getEarlyExits(&getBody(), exits);
  for (Operation *exit : exits)
    carryAtEnd(slot, exit->getBlock(), getBody().getArguments().back(),
               reachingAtBlockEnd, builder);

  return addCarriedResult(slot, *this, getInitArgs().back().getType(),
                          builder);
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
