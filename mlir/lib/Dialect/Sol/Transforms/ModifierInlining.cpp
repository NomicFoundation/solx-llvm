//===- ModifierInlining.cpp - Inline modifiers into functions -------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Inlines modifiers around the bodies of modified functions, following the
// semantics of solc's legacy codegen:
//
// - A function with modifiers M0 ... Mk-1 stays a single function. Layer i
//   is Mi's body; layer k is the function body. Emitting layer i clones Mi's
//   argument evaluation (from the sol.modifier_invocation region) and Mi's
//   body; each sol.placeholder in the clone recursively emits layer i+1 at
//   that position. A modifier with N placeholders hence duplicates everything
//   inner N times; with none, the inner layers are never emitted.
//
// - The function's results live in zero-initialized stack slots created once
//   at entry and shared by every layer. Each layer is wrapped in a sol.scope;
//   a sol.return inside it stores its operands to the slots and exits only
//   that layer (sol.leave), so enclosing modifier code after the placeholder
//   still runs. The single real return at the end loads the slots.
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/Dialect/Sol/Transforms/Passes.h"
#include "mlir/Dialect/Sol/Utils.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/IRMapping.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/IR/Value.h"
#include "mlir/IR/Visitors.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Support/LLVM.h"
#include "llvm/ADT/STLExtras.h"

namespace mlir {
namespace sol {
#define GEN_PASS_DEF_MODIFIERINLININGPASS
#include "mlir/Dialect/Sol/Transforms/Passes.h.inc"
} // namespace sol
} // namespace mlir

using namespace mlir;

namespace {

/// Inlines the modifiers of one function.
class ModifierInliner {
public:
  ModifierInliner(sol::FuncOp fn, ArrayRef<sol::ModifierInvocationOp> invs)
      : fn(fn), invs(invs) {}

  void run() {
    Block &entry = fn.getBody().front();
    Location loc = fn.getLoc();

    // Split the original body off the entry. Body blocks (the split-off
    // suffix plus any post-return blocks the frontend created) stay parked at
    // the end of the function region as the clone source of layer k.
    entry.splitBlock(std::next(invs.back()->getIterator()));
    for (Block &blk : llvm::drop_begin(fn.getBody()))
      bodyBlks.push_back(&blk);

    OpBuilder b(fn.getContext());
    b.setInsertionPointToEnd(&entry);

    for (Type resTy : fn.getResultTypes()) {
      auto slot = b.create<sol::AllocaOp>(
          loc, sol::PointerType::get(b.getContext(), resTy,
                                     sol::DataLocation::Stack));
      Value defaultVal = sol::genDefaultVal(b, resTy, loc);
      b.create<sol::StoreOp>(loc, defaultVal, slot);
      retSlots.push_back(slot);
    }

    emitLayer(b, /*depth=*/0);

    SmallVector<Value> rets;
    for (Value slot : retSlots)
      rets.push_back(b.create<sol::LoadOp>(loc, slot).getResult());
    b.create<sol::ReturnOp>(loc, rets);

    for (sol::ModifierInvocationOp inv : llvm::reverse(invs))
      inv.erase();
    for (Block *blk : llvm::reverse(bodyBlks))
      blk->erase();
  }

private:
  /// Clones `srcBlks` into `dst`. The entry block's arguments are expected to
  /// be pre-mapped in `map`; trailing blocks (unreachable post-return blocks)
  /// carry no arguments.
  void cloneBlocks(ArrayRef<Block *> srcBlks, Region &dst, IRMapping &map) {
    for (Block *src : srcBlks) {
      assert(src == srcBlks.front() || src->getNumArguments() == 0);
      map.map(src, &dst.emplaceBlock());
    }
    for (Block *src : srcBlks) {
      OpBuilder blkB = OpBuilder::atBlockEnd(map.lookup(src));
      for (Operation &op : *src)
        blkB.clone(op, map);
    }
  }

  /// Emits layer `depth` at the builder's insertion point.
  void emitLayer(OpBuilder &b, unsigned depth) {
    SmallVector<Block *> srcBlks;
    IRMapping map;
    Location loc = fn.getLoc();
    if (depth == invs.size()) {
      srcBlks = bodyBlks;
    } else {
      sol::ModifierInvocationOp inv = invs[depth];
      loc = inv.getLoc();

      // Argument evaluation belongs to layer entry, so it is re-emitted here,
      // once per emission of this layer.
      Block &argsBlk = inv.getArgsRegion().front();
      auto argsYield = cast<sol::YieldOp>(argsBlk.getTerminator());
      IRMapping argMap;
      for (Operation &op : argsBlk.without_terminator())
        b.clone(op, argMap);

      auto modifier = cast<sol::ModifierOp>(
          SymbolTable::lookupNearestSymbolFrom(inv, inv.getCalleeAttr()));
      for (Block &blk : modifier.getBody())
        srcBlks.push_back(&blk);
      for (auto [param, arg] :
           llvm::zip(srcBlks.front()->getArguments(), argsYield.getIns()))
        map.map(param, argMap.lookupOrDefault(arg));
    }

    auto scope = b.create<sol::ScopeOp>(loc);
    cloneBlocks(srcBlks, scope.getBodyRegion(), map);

    // Placeholders and returns of this layer's clone; inner layers don't
    // exist yet, so the walk can't touch theirs.
    SmallVector<sol::PlaceholderOp> placeholders;
    SmallVector<sol::ReturnOp> returns;
    scope.walk([&](sol::PlaceholderOp ph) { placeholders.push_back(ph); });
    scope.walk([&](sol::ReturnOp ret) { returns.push_back(ret); });

    // A return exits the layer after writing the shared result slots.
    for (sol::ReturnOp ret : returns) {
      OpBuilder retB(ret);
      for (auto [val, slot] : llvm::zip(ret.getOperands(), retSlots))
        retB.create<sol::StoreOp>(ret.getLoc(), val, slot);
      retB.create<sol::LeaveOp>(ret.getLoc());
      ret.erase();
    }

    for (sol::PlaceholderOp ph : placeholders) {
      OpBuilder phB(ph);
      emitLayer(phB, depth + 1);
      ph.erase();
    }
  }

  sol::FuncOp fn;
  ArrayRef<sol::ModifierInvocationOp> invs;
  SmallVector<Value> retSlots;
  SmallVector<Block *> bodyBlks;
};

} // namespace

struct ModifierInliningPass
    : public sol::impl::ModifierInliningPassBase<ModifierInliningPass> {

  void inlineModifiers(sol::FuncOp fn) {
    if (fn.getBlocks().empty())
      return;

    SmallVector<sol::ModifierInvocationOp> invs;
    for (Operation &op : fn.getBlocks().front())
      if (auto inv = dyn_cast<sol::ModifierInvocationOp>(op))
        invs.push_back(inv);
    if (invs.empty())
      return;

    ModifierInliner(fn, invs).run();
  }

  void runOnOperation() override {
    getOperation().walk([&](sol::FuncOp fn) { inlineModifiers(fn); });
    getOperation().walk([&](sol::ModifierOp modifier) { modifier.erase(); });
  }
};
