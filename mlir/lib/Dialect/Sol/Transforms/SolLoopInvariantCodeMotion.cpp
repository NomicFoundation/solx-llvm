//===- SolLoopInvariantCodeMotion.cpp - LICM for Sol dialect --------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Moves the loop-invariant storage and transient addresses of Sol loops out of
// them, and keeps a slot that a loop accesses through a loop-invariant address
// in a stack slot across the loop. The loop stores to the stack slot and sets a
// written flag, and the stack slot goes back to storage after the loop and
// before each return out of it only if the flag is set, so a loop that stores
// on no path still stores nothing. A revert discards storage writes, so a
// reverting path needs no write-back. mem2reg then turns the stack slots into
// values the loop carries.
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/Dialect/Sol/Transforms/Passes.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Dominance.h"
#include "mlir/IR/Matchers.h"
#include "mlir/Interfaces/DataLayoutInterfaces.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"
#include "mlir/Transforms/LoopInvariantCodeMotionUtils.h"
#include "mlir/Transforms/Mem2Reg.h"
#include "llvm/ADT/SetVector.h"

namespace mlir {
namespace sol {
#define GEN_PASS_DEF_LOOPINVARIANTCODEMOTIONPASS
#include "mlir/Dialect/Sol/Transforms/Passes.h.inc"
} // namespace sol
} // namespace mlir

using namespace mlir;
using namespace mlir::sol;

namespace {

/// A storage or transient access in a loop. The address is null when the
/// access names none.
struct Access {
  SideEffects::Resource *resource;
  Value addr;
  Operation *op;
};

/// What a loop does that matters for keeping a slot out of storage.
struct LoopAccesses {
  SmallVector<Access> accesses;
  /// The sol.return and sol.leave ops that leave the loop.
  SmallVector<Operation *> exits;
  /// Whether an op of the loop may touch storage in a way not known.
  bool hasUnknownEffects = false;
};

/// The state variable an address derives from and the gep and map ops that
/// derive it, outermost first. The root is null for an address from anywhere
/// else, such as an argument.
struct AddressPath {
  FlatSymbolRefAttr root;
  SmallVector<Operation *> steps;
};

} // namespace

static bool isStorageResource(SideEffects::Resource *resource) {
  return isa<StorageResource, TransientResource>(resource);
}

/// Whether an effect on the resource leaves storage and transient storage
/// alone.
static bool isUnrelatedResource(SideEffects::Resource *resource) {
  return isa<StackResource, CallDataResource, MemoryResource, ImmutableResource,
             ValidationResource, LogResource,
             SideEffects::AutomaticAllocationScopeResource>(resource);
}

/// Whether a sol.leave leaves the loop, since it exits the nearest enclosing
/// sol.scope.
static bool leavesLoop(LeaveOp leave, Operation *loop) {
  auto scope = leave->getParentOfType<ScopeOp>();
  return !scope || !loop->isProperAncestor(scope);
}

static LoopAccesses collectAccesses(Operation *loop) {
  LoopAccesses result;
  loop->walk<WalkOrder::PreOrder>([&](Operation *op) {
    if (op == loop)
      return WalkResult::advance();

    if (auto leave = dyn_cast<LeaveOp>(op)) {
      if (leavesLoop(leave, loop))
        result.exits.push_back(op);
    } else if (isa<ReturnOp>(op)) {
      result.exits.push_back(op);
    }

    if (auto effectOp = dyn_cast<MemoryEffectOpInterface>(op)) {
      SmallVector<MemoryEffects::EffectInstance> effects;
      effectOp.getEffects(effects);
      for (MemoryEffects::EffectInstance &effect : effects) {
        if (isStorageResource(effect.getResource()))
          result.accesses.push_back(
              {effect.getResource(), effect.getValue(), op});
        else if (!isUnrelatedResource(effect.getResource()))
          result.hasUnknownEffects = true;
      }
      return WalkResult::advance();
    }

    // A terminator passes values on, and a region branch op only runs its
    // regions, whose ops the walk visits.
    if (op->hasTrait<OpTrait::IsTerminator>() ||
        isa<RegionBranchOpInterface>(op))
      return WalkResult::advance();

    result.hasUnknownEffects = true;
    return WalkResult::interrupt();
  });
  return result;
}

static AddressPath getAddressPath(Value addr) {
  AddressPath path;
  while (Operation *def = addr.getDefiningOp()) {
    if (auto gep = dyn_cast<GepOp>(def)) {
      path.steps.push_back(def);
      addr = gep.getBaseAddr();
      continue;
    }
    if (auto map = dyn_cast<MapOp>(def)) {
      path.steps.push_back(def);
      addr = map.getMapping();
      continue;
    }
    if (auto addrOf = dyn_cast<AddrOfOp>(def))
      path.root = addrOf.getVarAttr();
    break;
  }
  std::reverse(path.steps.begin(), path.steps.end());
  return path;
}

/// The index of a gep or the key of a map.
static Value getStepIndex(Operation *step) {
  if (auto gep = dyn_cast<GepOp>(step))
    return gep.getIdx();
  return cast<MapOp>(step).getKey();
}

/// Whether two addresses name disjoint data. Distinct state variables, struct
/// members, array elements and mapping values have distinct slots, given no
/// keccak256 collision.
static bool isDisjoint(Value lhs, Value rhs) {
  AddressPath lhsPath = getAddressPath(lhs);
  AddressPath rhsPath = getAddressPath(rhs);
  if (!lhsPath.root || !rhsPath.root)
    return false;
  if (lhsPath.root != rhsPath.root)
    return true;
  for (auto [lhsStep, rhsStep] : llvm::zip(lhsPath.steps, rhsPath.steps)) {
    if (lhsStep->getName() != rhsStep->getName())
      return false;
    Value lhsIndex = getStepIndex(lhsStep);
    Value rhsIndex = getStepIndex(rhsStep);
    if (lhsIndex == rhsIndex)
      continue;
    APInt lhsConst, rhsConst;
    if (!matchPattern(lhsIndex, m_ConstantInt(&lhsConst)) ||
        !matchPattern(rhsIndex, m_ConstantInt(&rhsConst)))
      return false;
    unsigned width = std::max(lhsConst.getBitWidth(), rhsConst.getBitWidth());
    if (lhsConst.zext(width) != rhsConst.zext(width))
      return true;
  }
  return false;
}

/// Whether a loop can keep the slot an address names in a stack slot: a
/// scalar in storage or transient storage. An enum is left alone, since
/// storing an out-of-range enum panics and only the last store would be left.
static bool isPromotableAddress(Value addr) {
  auto ptrTy = dyn_cast<PointerType>(addr.getType());
  if (!ptrTy)
    return false;
  DataLocation dataLoc = ptrTy.getDataLocation();
  Type valueTy = ptrTy.getPointeeType();
  return (dataLoc == DataLocation::Storage ||
          dataLoc == DataLocation::Transient) &&
         isScalar(valueTy) && !isa<EnumType>(valueTy);
}

static bool isStorageAddress(Value addr) {
  auto ptrTy = dyn_cast<PointerType>(addr.getType());
  return ptrTy && (ptrTy.getDataLocation() == DataLocation::Storage ||
                   ptrTy.getDataLocation() == DataLocation::Transient);
}

/// Moves the ops of a loop that compute the address of a storage or transient
/// load or store, have no effects and use only values from outside the loop
/// to before it, from the ifs, switches and scopes in it too. LLVM cannot move
/// the keccak256 of a mapping slot, which writes scratch memory, and it places
/// the other invariant ops with the EVM stack in view.
static size_t hoistInvariantAddresses(Operation *loop) {
  SmallVector<Region *> regions;
  SmallVector<Value> addresses;
  loop->walk<WalkOrder::PreOrder>([&](Operation *op) {
    if (auto load = dyn_cast<LoadOp>(op))
      addresses.push_back(load.getAddr());
    else if (auto store = dyn_cast<StoreOp>(op))
      addresses.push_back(store.getAddr());
    if (!isa<RegionBranchOpInterface>(op))
      return op->getNumRegions() ? WalkResult::skip() : WalkResult::advance();
    for (Region &region : op->getRegions())
      regions.push_back(&region);
    return WalkResult::advance();
  });

  llvm::SmallPtrSet<Operation *, 16> addressOps;
  llvm::erase_if(addresses, [](Value addr) { return !isStorageAddress(addr); });
  while (!addresses.empty()) {
    Operation *def = addresses.pop_back_val().getDefiningOp();
    if (!def || !loop->isProperAncestor(def) || !addressOps.insert(def).second)
      continue;
    llvm::append_range(addresses, def->getOperands());
  }
  if (addressOps.empty())
    return 0;

  auto loopLike = cast<LoopLikeOpInterface>(loop);
  return moveLoopInvariantCode(
      regions,
      [&](Value value, Region *) {
        return loopLike.isDefinedOutsideOfLoop(value);
      },
      [&](Operation *op, Region *) {
        return addressOps.contains(op) && isMemoryEffectFree(op) &&
               isSpeculatable(op);
      },
      [&](Operation *op, Region *) { op->moveBefore(loop); });
}

/// Stores the stack slot's value to the address if the written flag is set.
static void writeBack(OpBuilder &builder, Location loc, Value written,
                      Value stackSlot, Value addr) {
  Value wasWritten = builder.create<LoadOp>(loc, written);
  auto ifOp = builder.create<IfOp>(loc, wasWritten);
  OpBuilder::InsertionGuard guard(builder);
  builder.setInsertionPointToStart(&ifOp.getThenRegion().emplaceBlock());
  builder.create<StoreOp>(loc, builder.create<LoadOp>(loc, stackSlot), addr);
  builder.create<YieldOp>(loc);
}

/// Keeps each slot the loop accesses only through one loop-invariant address
/// in a stack slot, and returns the number of slots kept.
static size_t
promoteSlots(Operation *loop,
             SmallVectorImpl<PromotableAllocationOpInterface> &stackSlots) {
  LoopAccesses loopAccesses = collectAccesses(loop);
  if (loopAccesses.hasUnknownEffects)
    return 0;

  auto loopLike = cast<LoopLikeOpInterface>(loop);
  llvm::SetVector<Value> candidates;
  for (Access &access : loopAccesses.accesses)
    if (access.addr && isa<LoadOp, StoreOp>(access.op) &&
        isPromotableAddress(access.addr) &&
        loopLike.isDefinedOutsideOfLoop(access.addr))
      candidates.insert(access.addr);

  MLIRContext *ctx = loop->getContext();
  Location loc = loop->getLoc();
  Type i1Ty = IntegerType::get(ctx, 1);
  size_t numPromoted = 0;
  for (Value addr : candidates) {
    auto ptrTy = cast<PointerType>(addr.getType());
    SideEffects::Resource *resource = getResource(ptrTy.getDataLocation());
    SmallVector<LoadOp> loads;
    SmallVector<StoreOp> stores;
    bool promotable = true;
    for (Access &access : loopAccesses.accesses) {
      if (access.resource != resource)
        continue;
      if (access.addr == addr) {
        if (auto load = dyn_cast<LoadOp>(access.op))
          loads.push_back(load);
        else if (auto store = dyn_cast<StoreOp>(access.op))
          stores.push_back(store);
        else
          promotable = false;
        continue;
      }
      if (!access.addr || !isDisjoint(addr, access.addr))
        promotable = false;
    }
    if (!promotable)
      continue;

    OpBuilder builder(loop);
    auto stackSlot = builder.create<AllocaOp>(
        loc,
        PointerType::get(ctx, ptrTy.getPointeeType(), DataLocation::Stack));
    stackSlots.push_back(stackSlot);
    if (!loads.empty())
      builder.create<StoreOp>(loc, builder.create<LoadOp>(loc, addr),
                              stackSlot);
    for (LoadOp load : loads)
      load.getAddrMutable().set(stackSlot);
    ++numPromoted;
    if (stores.empty())
      continue;

    auto written = builder.create<AllocaOp>(
        loc, PointerType::get(ctx, i1Ty, DataLocation::Stack));
    stackSlots.push_back(written);
    builder.create<StoreOp>(
        loc, builder.create<ConstantOp>(loc, builder.getIntegerAttr(i1Ty, 0)),
        written);
    for (StoreOp store : stores) {
      store.getAddrMutable().set(stackSlot);
      builder.setInsertionPointAfter(store);
      builder.create<StoreOp>(
          store.getLoc(),
          builder.create<ConstantOp>(store.getLoc(),
                                     builder.getIntegerAttr(i1Ty, 1)),
          written);
    }

    builder.setInsertionPointAfter(loop);
    writeBack(builder, loc, written, stackSlot, addr);
    for (Operation *exit : loopAccesses.exits) {
      builder.setInsertionPoint(exit);
      writeBack(builder, exit->getLoc(), written, stackSlot, addr);
    }
  }
  return numPromoted;
}

namespace {

struct LoopInvariantCodeMotionPass
    : public sol::impl::LoopInvariantCodeMotionPassBase<
          LoopInvariantCodeMotionPass> {
  void runOnOperation() override {
    // Inner loops first, so an outer loop sees their write-backs as its own
    // accesses.
    SmallVector<Operation *> loops;
    getOperation()->walk(
        [&](LoopOpInterface loop) { loops.push_back(loop.getOperation()); });

    SmallVector<PromotableAllocationOpInterface> stackSlots;
    for (Operation *loop : loops) {
      numHoisted += hoistInvariantAddresses(loop);
      numPromoted += promoteSlots(loop, stackSlots);
    }
    if (stackSlots.empty())
      return;

    OpBuilder builder(&getContext());
    DominanceInfo dominance;
    (void)tryToPromoteMemorySlots(
        stackSlots, builder, DataLayout::closest(getOperation()), dominance);
  }
};

} // namespace
