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
