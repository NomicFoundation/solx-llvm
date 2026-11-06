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
  return true;
}

void ScopeOp::getEarlyExits(Region *region,
                            SmallVectorImpl<Operation *> &exits) {
  region->walk([&](LeaveOp leave) {
    if (leave->getParentOfType<ScopeOp>() == *this)
      exits.push_back(leave);
  });
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
  SmallVector<Operation *> exits;
  getEarlyExits(&getBodyRegion(), exits);
  for (Operation *exit : exits)
    memoryslot::updateTerminator(exit->getBlock(), reachingDef,
                                 reachingAtBlockEnd);

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

//===----------------------------------------------------------------------===//
// Loops
//===----------------------------------------------------------------------===//

/// The sol.break and sol.continue ops below `region` that exit `loop`.
static void collectLoopExits(Operation *loop, Region *region,
                             SmallVectorImpl<Operation *> &exits) {
  region->walk<WalkOrder::PreOrder>([&](Operation *op) {
    if (op != loop && isa<LoopOpInterface>(op))
      return WalkResult::skip();
    if (isa<BreakOp, ContinueOp>(op))
      exits.push_back(op);
    return WalkResult::advance();
  });
}

/// A slot stored in the loop is carried from one iteration to the next: an
/// init arg, then an argument of each region.
template <typename LoopOp>
static void
setupLoopPromotion(LoopOp loop, const MemorySlot &slot, Value reachingDef,
                   bool hasValueStores,
                   llvm::SmallMapVector<Region *, Value, 2> &regionsToProcess) {
  if (!hasValueStores) {
    for (Region &region : loop->getRegions())
      regionsToProcess.insert({&region, reachingDef});
    return;
  }

  loop.getInitArgsMutable().append(reachingDef);
  for (Region &region : loop->getRegions())
    regionsToProcess.insert(
        {&region, region.addArgument(slot.elemType, slot.ptr.getLoc())});
}

/// Passes the slot's value at each exit of a region on: sol.condition to the
/// body and the loop's results, sol.yield to the next region, sol.break to
/// the results and sol.continue to the next iteration.
template <typename LoopOp>
static Value
finalizeLoopPromotion(LoopOp loop, const MemorySlot &slot, Value reachingDef,
                      bool hasValueStores,
                      const llvm::DenseMap<Block *, Value> &reachingAtBlockEnd,
                      OpBuilder &builder) {
  if (!hasValueStores)
    return reachingDef;

  for (Region &region : loop->getRegions()) {
    Value carried = region.getArguments().back();
    for (Block &block : region)
      if (isa<ConditionOp, YieldOp>(block.getTerminator()))
        memoryslot::updateTerminator(&block, carried, reachingAtBlockEnd);
  }
  SmallVector<Operation *> exits;
  collectLoopExits(loop, &loop.getBody(), exits);
  for (Operation *exit : exits)
    memoryslot::updateTerminator(exit->getBlock(),
                                 loop.getBody().getArguments().back(),
                                 reachingAtBlockEnd);

  IRRewriter rewriter(builder);
  SmallVector<Type> resultTypes(loop->getResultTypes());
  resultTypes.push_back(slot.elemType);
  return memoryslot::replaceWithNewResults(rewriter, loop, resultTypes)
      ->getResults()
      .back();
}

//===----------------------------------------------------------------------===//
// WhileOp
//===----------------------------------------------------------------------===//

bool WhileOp::isRegionPromotable(const MemorySlot &slot, Region *region,
                                 bool hasValueStores) {
  return true;
}

void WhileOp::setupPromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    llvm::SmallMapVector<Region *, Value, 2> &regionsToProcess) {
  setupLoopPromotion(*this, slot, reachingDef, hasValueStores,
                     regionsToProcess);
}

Value WhileOp::finalizePromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    const llvm::DenseMap<Block *, Value> &reachingAtBlockEnd,
    OpBuilder &builder) {
  return finalizeLoopPromotion(*this, slot, reachingDef, hasValueStores,
                               reachingAtBlockEnd, builder);
}

void WhileOp::getEarlyExits(Region *region,
                            SmallVectorImpl<Operation *> &exits) {
  collectLoopExits(*this, region, exits);
}

//===----------------------------------------------------------------------===//
// DoWhileOp
//===----------------------------------------------------------------------===//

bool DoWhileOp::isRegionPromotable(const MemorySlot &slot, Region *region,
                                   bool hasValueStores) {
  return true;
}

void DoWhileOp::setupPromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    llvm::SmallMapVector<Region *, Value, 2> &regionsToProcess) {
  setupLoopPromotion(*this, slot, reachingDef, hasValueStores,
                     regionsToProcess);
}

Value DoWhileOp::finalizePromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    const llvm::DenseMap<Block *, Value> &reachingAtBlockEnd,
    OpBuilder &builder) {
  return finalizeLoopPromotion(*this, slot, reachingDef, hasValueStores,
                               reachingAtBlockEnd, builder);
}

void DoWhileOp::getEarlyExits(Region *region,
                              SmallVectorImpl<Operation *> &exits) {
  collectLoopExits(*this, region, exits);
}

//===----------------------------------------------------------------------===//
// ForOp
//===----------------------------------------------------------------------===//

bool ForOp::isRegionPromotable(const MemorySlot &slot, Region *region,
                               bool hasValueStores) {
  return true;
}

void ForOp::setupPromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    llvm::SmallMapVector<Region *, Value, 2> &regionsToProcess) {
  setupLoopPromotion(*this, slot, reachingDef, hasValueStores,
                     regionsToProcess);
}

Value ForOp::finalizePromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    const llvm::DenseMap<Block *, Value> &reachingAtBlockEnd,
    OpBuilder &builder) {
  return finalizeLoopPromotion(*this, slot, reachingDef, hasValueStores,
                               reachingAtBlockEnd, builder);
}

void ForOp::getEarlyExits(Region *region, SmallVectorImpl<Operation *> &exits) {
  collectLoopExits(*this, region, exits);
}

//===----------------------------------------------------------------------===//
// InlineAsmOp
//===----------------------------------------------------------------------===//

bool InlineAsmOp::isRegionPromotable(const MemorySlot &slot, Region *region,
                                     bool hasValueStores) {
  return true;
}

void InlineAsmOp::setupPromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    llvm::SmallMapVector<Region *, Value, 2> &regionsToProcess) {
  regionsToProcess.insert({&getBody(), reachingDef});
}

/// The body yields the slot's value at its end, unless it halts.
Value InlineAsmOp::finalizePromotion(
    const MemorySlot &slot, Value reachingDef, bool hasValueStores,
    const llvm::DenseMap<Block *, Value> &reachingAtBlockEnd,
    OpBuilder &builder) {
  if (!hasValueStores)
    return reachingDef;

  IRRewriter rewriter(builder);
  Block &body = getBody().front();
  if (body.empty() || !body.back().hasTrait<OpTrait::IsTerminator>()) {
    OpBuilder::InsertionGuard guard(rewriter);
    rewriter.setInsertionPointToEnd(&body);
    YieldOp::create(rewriter, getLoc(), ValueRange{});
  }
  if (isa<YieldOp>(body.back()))
    memoryslot::updateTerminator(&body, reachingDef, reachingAtBlockEnd);

  SmallVector<Type> resultTypes(getResultTypes());
  resultTypes.push_back(slot.elemType);
  return memoryslot::replaceWithNewResults(rewriter, *this, resultTypes)
      ->getResults()
      .back();
}

//===----------------------------------------------------------------------===//
// YulPtrCastOp, YulStorageSlotOp
//===----------------------------------------------------------------------===//

/// The Yul word inline assembly reads and writes the variable as, through the
/// pointer `out`.
static void exposeWord(Value out, SmallVectorImpl<MemorySlot> &newMemorySlots) {
  newMemorySlots.push_back(
      MemorySlot{out, IntegerType::get(out.getContext(), 256)});
}

/// Every use of the pointer `out` reads or writes the variable.
static void blockUses(Value out, SmallVectorImpl<OpOperand *> &newBlockingUses) {
  for (OpOperand &use : out.getUses())
    newBlockingUses.push_back(&use);
}

void YulPtrCastOp::getPromotableSlotAliases(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    SmallVectorImpl<MemorySlot> &newMemorySlots) {
  exposeWord(getOut(), newMemorySlots);
}

Value YulPtrCastOp::projectSlotValueToAliasValue(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    const MemorySlot &aliasSlot, Value slotValue, OpBuilder &builder) {
  return YulValCastOp::create(builder, getLoc(), slotValue).getOut().front();
}

Value YulPtrCastOp::projectAliasValueToSlotValue(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    const MemorySlot &aliasSlot, Value aliasValue, Value reachingDef,
    OpBuilder &builder) {
  return YulValCastOp::create(builder, getLoc(), parentSlot.elemType,
                              aliasValue)
      .getOut()
      .front();
}

bool YulPtrCastOp::canUsesBeRemoved(
    const SmallPtrSetImpl<OpOperand *> &blockingUses,
    SmallVectorImpl<OpOperand *> &newBlockingUses,
    const DataLayout &dataLayout) {
  blockUses(getOut(), newBlockingUses);
  return true;
}

DeletionKind YulPtrCastOp::removeBlockingUses(
    const SmallPtrSetImpl<OpOperand *> &blockingUses, OpBuilder &builder) {
  return DeletionKind::Delete;
}

void YulStorageSlotOp::getPromotableSlotAliases(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    SmallVectorImpl<MemorySlot> &newMemorySlots) {
  exposeWord(getOut(), newMemorySlots);
}

Value YulStorageSlotOp::projectSlotValueToAliasValue(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    const MemorySlot &aliasSlot, Value slotValue, OpBuilder &builder) {
  return YulValCastOp::create(builder, getLoc(), slotValue).getOut().front();
}

Value YulStorageSlotOp::projectAliasValueToSlotValue(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    const MemorySlot &aliasSlot, Value aliasValue, Value reachingDef,
    OpBuilder &builder) {
  return YulValCastOp::create(builder, getLoc(), parentSlot.elemType,
                              aliasValue)
      .getOut()
      .front();
}

bool YulStorageSlotOp::canUsesBeRemoved(
    const SmallPtrSetImpl<OpOperand *> &blockingUses,
    SmallVectorImpl<OpOperand *> &newBlockingUses,
    const DataLayout &dataLayout) {
  blockUses(getOut(), newBlockingUses);
  return true;
}

DeletionKind YulStorageSlotOp::removeBlockingUses(
    const SmallPtrSetImpl<OpOperand *> &blockingUses, OpBuilder &builder) {
  return DeletionKind::Delete;
}

//===----------------------------------------------------------------------===//
// YulCallDataOffsetOp, YulCallDataLengthOp, YulSelectorOp, YulFuncAddrOp
//===----------------------------------------------------------------------===//

/// Word `index` of the variable's value, which inline assembly reads.
static Value extractWord(Location loc, Value slotValue, unsigned index,
                         OpBuilder &builder) {
  return YulValCastOp::create(builder, loc, slotValue).getOut()[index];
}

/// The variable's value with word `index` replaced by the one inline assembly
/// writes.
static Value insertWord(Location loc, Value reachingDef, Value word,
                        unsigned index, OpBuilder &builder) {
  SmallVector<Value> words =
      llvm::to_vector_of<Value>(
          YulValCastOp::create(builder, loc, reachingDef).getOut());
  words[index] = word;
  return YulValCastOp::create(builder, loc, reachingDef.getType(), words)
      .getOut()
      .front();
}

void YulCallDataOffsetOp::getPromotableSlotAliases(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    SmallVectorImpl<MemorySlot> &newMemorySlots) {
  exposeWord(getOut(), newMemorySlots);
}

Value YulCallDataOffsetOp::projectSlotValueToAliasValue(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    const MemorySlot &aliasSlot, Value slotValue, OpBuilder &builder) {
  return extractWord(getLoc(), slotValue, 0, builder);
}

Value YulCallDataOffsetOp::projectAliasValueToSlotValue(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    const MemorySlot &aliasSlot, Value aliasValue, Value reachingDef,
    OpBuilder &builder) {
  return insertWord(getLoc(), reachingDef, aliasValue, 0, builder);
}

bool YulCallDataOffsetOp::canUsesBeRemoved(
    const SmallPtrSetImpl<OpOperand *> &blockingUses,
    SmallVectorImpl<OpOperand *> &newBlockingUses,
    const DataLayout &dataLayout) {
  blockUses(getOut(), newBlockingUses);
  return true;
}

DeletionKind YulCallDataOffsetOp::removeBlockingUses(
    const SmallPtrSetImpl<OpOperand *> &blockingUses, OpBuilder &builder) {
  return DeletionKind::Delete;
}

void YulCallDataLengthOp::getPromotableSlotAliases(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    SmallVectorImpl<MemorySlot> &newMemorySlots) {
  exposeWord(getOut(), newMemorySlots);
}

Value YulCallDataLengthOp::projectSlotValueToAliasValue(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    const MemorySlot &aliasSlot, Value slotValue, OpBuilder &builder) {
  return extractWord(getLoc(), slotValue, 1, builder);
}

Value YulCallDataLengthOp::projectAliasValueToSlotValue(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    const MemorySlot &aliasSlot, Value aliasValue, Value reachingDef,
    OpBuilder &builder) {
  return insertWord(getLoc(), reachingDef, aliasValue, 1, builder);
}

bool YulCallDataLengthOp::canUsesBeRemoved(
    const SmallPtrSetImpl<OpOperand *> &blockingUses,
    SmallVectorImpl<OpOperand *> &newBlockingUses,
    const DataLayout &dataLayout) {
  blockUses(getOut(), newBlockingUses);
  return true;
}

DeletionKind YulCallDataLengthOp::removeBlockingUses(
    const SmallPtrSetImpl<OpOperand *> &blockingUses, OpBuilder &builder) {
  return DeletionKind::Delete;
}

void YulFuncAddrOp::getPromotableSlotAliases(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    SmallVectorImpl<MemorySlot> &newMemorySlots) {
  exposeWord(getOut(), newMemorySlots);
}

Value YulFuncAddrOp::projectSlotValueToAliasValue(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    const MemorySlot &aliasSlot, Value slotValue, OpBuilder &builder) {
  return extractWord(getLoc(), slotValue, 0, builder);
}

Value YulFuncAddrOp::projectAliasValueToSlotValue(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    const MemorySlot &aliasSlot, Value aliasValue, Value reachingDef,
    OpBuilder &builder) {
  return insertWord(getLoc(), reachingDef, aliasValue, 0, builder);
}

bool YulFuncAddrOp::canUsesBeRemoved(
    const SmallPtrSetImpl<OpOperand *> &blockingUses,
    SmallVectorImpl<OpOperand *> &newBlockingUses,
    const DataLayout &dataLayout) {
  blockUses(getOut(), newBlockingUses);
  return true;
}

DeletionKind YulFuncAddrOp::removeBlockingUses(
    const SmallPtrSetImpl<OpOperand *> &blockingUses, OpBuilder &builder) {
  return DeletionKind::Delete;
}

void YulSelectorOp::getPromotableSlotAliases(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    SmallVectorImpl<MemorySlot> &newMemorySlots) {
  exposeWord(getOut(), newMemorySlots);
}

Value YulSelectorOp::projectSlotValueToAliasValue(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    const MemorySlot &aliasSlot, Value slotValue, OpBuilder &builder) {
  return extractWord(getLoc(), slotValue, 1, builder);
}

Value YulSelectorOp::projectAliasValueToSlotValue(
    OpOperand &aliasedSlotPointerOperand, const MemorySlot &parentSlot,
    const MemorySlot &aliasSlot, Value aliasValue, Value reachingDef,
    OpBuilder &builder) {
  return insertWord(getLoc(), reachingDef, aliasValue, 1, builder);
}

bool YulSelectorOp::canUsesBeRemoved(
    const SmallPtrSetImpl<OpOperand *> &blockingUses,
    SmallVectorImpl<OpOperand *> &newBlockingUses,
    const DataLayout &dataLayout) {
  blockUses(getOut(), newBlockingUses);
  return true;
}

DeletionKind YulSelectorOp::removeBlockingUses(
    const SmallPtrSetImpl<OpOperand *> &blockingUses, OpBuilder &builder) {
  return DeletionKind::Delete;
}

//===----------------------------------------------------------------------===//
// YulStorageOffsetOp
//===----------------------------------------------------------------------===//

/// The offset of a storage reference is 0, whatever the variable holds.
bool YulStorageOffsetOp::canUsesBeRemoved(
    const SmallPtrSetImpl<OpOperand *> &blockingUses,
    SmallVectorImpl<OpOperand *> &newBlockingUses,
    const DataLayout &dataLayout) {
  return true;
}

DeletionKind YulStorageOffsetOp::removeBlockingUses(
    const SmallPtrSetImpl<OpOperand *> &blockingUses, OpBuilder &builder) {
  Type word = getOut().getType();
  getOut().replaceAllUsesWith(yul::ConstantOp::create(
      builder, getLoc(), word, builder.getIntegerAttr(word, 0)));
  return DeletionKind::Delete;
}
