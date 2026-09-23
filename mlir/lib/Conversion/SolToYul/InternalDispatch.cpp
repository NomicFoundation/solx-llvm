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
#include "mlir/Conversion/SolToYul/HelperSymbols.h"
#include "mlir/Conversion/SolToYul/SolToYul.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/Sol/DebugInfo.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/Dialect/Yul/Yul.h"
#include "mlir/IR/Builders.h"

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

/// Returns the number of words `tys` lower to.
static unsigned getNumWords(TypeRange tys) {
  unsigned numWords = 0;
  for (Type ty : tys) {
    if (auto structTy = dyn_cast<LLVM::LLVMStructType>(ty))
      numWords += getNumWords(structTy.getBody());
    else
      ++numWords;
  }
  return numWords;
}

/// Returns the word counts of `ty`, a lowered function type.
static evm::InternalDispatch::WordCounts getWordCounts(FunctionType ty) {
  return {getNumWords(ty.getInputs()), getNumWords(ty.getResults())};
}

/// Appends the words of `val` to `words`.
static void appendWords(Value val, SmallVectorImpl<Value> &words, Location loc,
                        OpBuilder &b) {
  auto structTy = dyn_cast<LLVM::LLVMStructType>(val.getType());
  if (!structTy) {
    words.push_back(val);
    return;
  }
  ArrayRef<Type> fieldTys = structTy.getBody();
  for (int64_t i = 0, e = fieldTys.size(); i < e; ++i)
    appendWords(b.create<LLVM::ExtractValueOp>(loc, fieldTys[i], val,
                                               b.getDenseI64ArrayAttr({i})),
                words, loc, b);
}

/// Builds a value of `ty` from the words at the front of `words`, and drops
/// them.
static Value takeWords(Type ty, ArrayRef<Value> &words, Location loc,
                       OpBuilder &b) {
  auto structTy = dyn_cast<LLVM::LLVMStructType>(ty);
  if (!structTy) {
    Value word = words.front();
    assert(word.getType() == ty && "a word keeps its type");
    words = words.drop_front();
    return word;
  }
  SmallVector<Value> fields;
  for (Type fieldTy : structTy.getBody())
    fields.push_back(takeWords(fieldTy, words, loc, b));
  return solgen::BuilderExt(b, loc).genLLVMStruct(fields);
}

/// Returns `vals` as values of `tys`. A retyped pointer can reach a target
/// whose values group the same words differently.
static SmallVector<Value> regroup(ValueRange vals, TypeRange tys, Location loc,
                                  OpBuilder &b) {
  if (TypeRange(vals) == tys)
    return SmallVector<Value>(vals);
  SmallVector<Value> words;
  for (Value val : vals)
    appendWords(val, words, loc, b);
  ArrayRef<Value> rest = words;
  SmallVector<Value> regrouped;
  for (Type ty : tys)
    regrouped.push_back(takeWords(ty, rest, loc, b));
  assert(rest.empty() && "a target takes and returns the words of its call");
  return regrouped;
}

void evm::InternalDispatch::addCreationFuncRefs(sol::ContractOp contr) {
  for (auto sym : contr.getCreationFuncRefs().getAsRange<FlatSymbolRefAttr>())
    addTarget(contr.lookupSymbol<sol::FuncOp>(sym));
}

void evm::InternalDispatch::addTarget(sol::FuncOp fn) {
  auto loweredTy = cast<FunctionType>(tyConv.convertType(fn.getFunctionType()));
  targets[getWordCounts(loweredTy)].insert(fn);
}

yul::FuncOp evm::InternalDispatch::getOrCreateDispatchFn(
    sol::ICallOp icall, FunctionType dispatchFnTy, PatternRewriter &r) {
  auto [it, inserted] = requests.try_emplace(dispatchFnTy);
  Request &request = it->second;
  if (inserted) {
    auto caller = icall->getParentOfType<sol::FuncOp>();
    ModuleOp mod = getModule(caller);
    std::string name = evm::helpersym::internalDispatch(requests.size() - 1);
    // The dispatch function is shared by every call of its signature: its
    // subprogram is artificial at the line of the module hosting it.
    OpBuilder::InsertionGuard insertGuard(r);
    r.setInsertionPointAfter(caller);
    auto fn = r.create<yul::FuncOp>(
        evm::fuseArtificialSubprogram(mod, name, mod.getLoc()), name,
        dispatchFnTy);
    request = {fn, caller};
  }
  return request.fn;
}

void evm::InternalDispatch::genDispatchFns() {
  for (auto &[dispatchFnTy, request] : requests) {
    ModuleOp mod = getModule(request.caller);
    // The body and arguments are at line 0 of the artificial subprogram.
    Location loc = evm::artificialLoc(mod.getLoc());
    OpBuilder b(mod.getContext());
    evm::Builder evmB(mod, b, loc);

    yul::FuncOp fn = request.fn;
    // The dispatch takes the pointer ahead of the callee's arguments.
    auto calleeTy = FunctionType::get(mod.getContext(),
                                      dispatchFnTy.getInputs().drop_front(),
                                      dispatchFnTy.getResults());

    SmallVector<int64_t> caseIds;
    SmallVector<sol::FuncOp> caseFns;
    auto found = targets.find(getWordCounts(calleeTy));
    if (found != targets.end()) {
      for (sol::FuncOp target : found->second) {
        caseIds.push_back(*target.getId());
        caseFns.push_back(target);
      }
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
      FunctionType targetTy = caseFns[i].getFunctionType();
      auto call = b.create<yul::FuncCallOp>(
          loc, targetTy.getResults(), FlatSymbolRefAttr::get(caseFns[i]),
          regroup(calleeArgs, targetTy.getInputs(), loc, b));
      b.create<yul::YieldOp>(loc, regroup(call.getResults(), resTys, loc, b));
    }

    b.setInsertionPointToStart(&switchOp.getDefaultRegion().emplaceBlock());
    // The dispatch is built after stage 2, outside any contract, so no helper
    // can serve it: the panic stays inline.
    evmB.genPanicInline(
        solgen::BuilderExt(b, loc).genI256Const(static_cast<int64_t>(
            mlir::evm::PanicCode::InvalidInternalFunction)),
        loc);
    b.create<yul::YieldOp>(loc, genUndefs(resTys, loc, b));

    b.setInsertionPointToEnd(entry);
    b.create<yul::FuncReturnOp>(loc, switchOp.getResults());
  }
}
