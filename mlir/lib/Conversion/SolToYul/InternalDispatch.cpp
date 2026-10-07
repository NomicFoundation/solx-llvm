//===- InternalDispatch.cpp - Internal function pointer dispatch ----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The dispatch functions of a module's internal function pointer calls.
//
//===----------------------------------------------------------------------===//

#include "mlir/Conversion/SolToYul/EVMConstants.h"
#include "mlir/Conversion/SolToYul/EVMUtil.h"
#include "mlir/Conversion/SolToYul/SolToYul.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/Sol/DebugInfo.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/Dialect/Yul/Yul.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/SymbolTable.h"

using namespace mlir;
using solgen::getModule;

/// Generates undef values of the given types.
static SmallVector<Value> genUndefs(TypeRange tys, Location loc, OpBuilder &b) {
  SmallVector<Value> undefs;
  undefs.reserve(tys.size());
  for (Type ty : tys)
    undefs.push_back(b.create<LLVM::UndefOp>(loc, ty));
  return undefs;
}

void evm::InternalDispatch::addCreationFuncRefs(sol::ContractOp contr) {
  for (auto sym : contr.getCreationFuncRefs().getAsRange<FlatSymbolRefAttr>()) {
    auto fn = contr.lookupSymbol<sol::FuncOp>(sym);
    addTarget(sol::FuncRefType::get(contr.getContext(), fn.getFunctionType()),
              *fn.getId());
  }
}

void evm::InternalDispatch::addTarget(sol::FuncRefType type, int64_t id) {
  targets[type].insert(id);
}

yul::FuncOp evm::InternalDispatch::getOrCreateDispatchFn(
    sol::ICallOp icall, FunctionType dispatchFnTy, PatternRewriter &r) {
  auto [it, inserted] = requests.try_emplace(icall.getCallee().getType());
  Request &request = it->second;
  if (inserted) {
    auto caller = icall->getParentOfType<sol::FuncOp>();
    ModuleOp mod = getModule(caller);
    std::string name = evm::helpersym::internalDispatch(requests.size() - 1);
    // The dispatch function is shared by every call of its pointer type: its
    // subprogram is artificial at the line of the module hosting it.
    OpBuilder::InsertionGuard insertGuard(r);
    r.setInsertionPointAfter(caller);
    auto fn = r.create<yul::FuncOp>(
        evm::fuseArtificialSubprogram(mod, name, mod.getLoc()), name,
        dispatchFnTy);
    request = {fn, caller};
  }
  assert(request.fn.getFunctionType() == dispatchFnTy &&
         "the calls of a pointer type share a dispatch signature");
  return request.fn;
}

void evm::InternalDispatch::genDispatchFns() {
  for (auto &[key, request] : requests) {
    // The caller moved with the other functions into the object, which holds
    // the targets.
    Operation *symTab = SymbolTable::getNearestSymbolTable(request.caller);
    ModuleOp mod = getModule(request.caller);
    // The body and arguments are at line 0 of the artificial subprogram.
    Location loc = evm::artificialLoc(mod.getLoc());
    OpBuilder b(mod.getContext());
    evm::Builder evmB(mod, b, loc);

    yul::FuncOp fn = request.fn;
    FunctionType dispatchFnTy = fn.getFunctionType();
    // The dispatch takes the pointer ahead of the callee's arguments.
    [[maybe_unused]] auto calleeTy = FunctionType::get(
        mod.getContext(), dispatchFnTy.getInputs().drop_front(),
        dispatchFnTy.getResults());

    // Resolve the targets to their functions, in their order in the symbol
    // table.
    SmallVector<int64_t> caseIds;
    SmallVector<sol::FuncOp> caseFns;
    auto found = targets.find(key);
    if (found != targets.end()) {
      for (auto target : symTab->getRegion(0).getOps<sol::FuncOp>()) {
        if (target.getId() && found->second.contains(*target.getId())) {
          assert(target.getFunctionType() == calleeTy &&
                 "target signature mismatch");
          caseFns.push_back(target);
          caseIds.push_back(*target.getId());
        }
      }
      assert(caseFns.size() == found->second.size() && "unresolvable target");
    }

    fn->moveAfter(request.caller);

    SmallVector<Location> argLocs(dispatchFnTy.getNumInputs(), loc);
    Block *entry = b.createBlock(&fn.getBody(), fn.getBody().end(),
                                 dispatchFnTy.getInputs(), argLocs);
    b.setInsertionPointToStart(entry);
    ValueRange calleeArgs = entry->getArguments().drop_front();
    TypeRange resTys = dispatchFnTy.getResults();

    auto calleeIntTy = cast<IntegerType>(dispatchFnTy.getInput(0));
    SmallVector<APInt> caseVals;
    caseVals.reserve(caseIds.size());
    for (int64_t caseId : caseIds)
      caseVals.emplace_back(calleeIntTy.getWidth(), caseId);
    auto caseIdsAttr = DenseIntElementsAttr::get(
        RankedTensorType::get(static_cast<int64_t>(caseVals.size()),
                              calleeIntTy),
        caseVals);
    auto switchOp = b.create<yul::SwitchOp>(loc, resTys, entry->getArgument(0),
                                            caseIdsAttr, caseIds.size());
    for (size_t i = 0; i < caseFns.size(); ++i) {
      b.setInsertionPointToStart(&switchOp.getCaseRegions()[i].emplaceBlock());
      auto call = b.create<yul::FuncCallOp>(
          loc, resTys, FlatSymbolRefAttr::get(caseFns[i]), calleeArgs);
      b.create<yul::YieldOp>(loc, call.getResults());
    }

    b.setInsertionPointToStart(&switchOp.getDefaultRegion().emplaceBlock());
    evmB.genPanic(mlir::evm::PanicCode::InvalidInternalFunction);
    b.create<yul::YieldOp>(loc, genUndefs(resTys, loc, b));

    b.setInsertionPointToEnd(entry);
    b.create<yul::FuncReturnOp>(loc, switchOp.getResults());
  }
}
