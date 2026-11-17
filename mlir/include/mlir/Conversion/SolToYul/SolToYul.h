//===- SolToYul.h - Sol to Yul lowering -------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares the Sol to Yul lowering pass and the state it shares with
// the EVM utilities.
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_CONVERSION_SOLTOYUL_SOLTOYUL_H
#define MLIR_CONVERSION_SOLTOYUL_SOLTOYUL_H

#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/Dialect/Yul/Yul.h"
#include "mlir/Pass/Pass.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/MapVector.h"
#include "llvm/ADT/SetVector.h"
#include "llvm/ADT/StringMap.h"

namespace mlir {

#define GEN_PASS_DECL_CONVERTSOLTOYULPASS
#include "mlir/Conversion/Passes.h.inc"

namespace evm {

/// The internal function pointer dispatch of a contract. Inline assembly can
/// retype a pointer, so a call reaches every target that takes and returns as
/// many words. Each call goes through the dispatch function of its signature,
/// declared at its first call; the bodies are generated once every target is
/// known.
class InternalDispatch {
public:
  /// The words a function takes and returns.
  using WordCounts = std::pair<unsigned, unsigned>;

  /// Records `fn`, of pointer value `id`, as a target of the calls that take
  /// and return as many words as it does.
  void addTarget(yul::FuncOp fn, int64_t id);

  /// Returns the dispatch function of `dispatchFnTy`: the pointer ahead of the
  /// callee's arguments, to the callee's results. The first call, from
  /// `caller`, declares it.
  yul::FuncOp getOrCreateDispatchFn(FunctionType dispatchFnTy,
                                    yul::FuncOp caller, OpBuilder &b);

  /// Gives each declared dispatch function its body, a switch over the targets
  /// of its word counts, and places it after its first caller.
  void genDispatchFns();

private:
  struct Request {
    yul::FuncOp fn;
    yul::FuncOp caller;
  };

  /// The targets of the calls of each word counts, in the order they are
  /// recorded, which the cases of a dispatch follow.
  DenseMap<WordCounts, llvm::SmallSetVector<yul::FuncOp, 4>> targets;
  /// The pointer value of each target.
  DenseMap<yul::FuncOp, int64_t> ids;
  llvm::MapVector<FunctionType, Request> requests;
};

/// The string literal globals of a module, one per distinct literal. A name is
/// the literal's index behind a dot, which no frontend symbol can spell, so it
/// needs no probing of the contract's symbol table.
class StringLiteralPool {
public:
  /// Returns the global holding `literal` in the code section of `contr`,
  /// creating it on the first request.
  LLVM::GlobalOp getOrCreate(StringRef literal, sol::ContractOp contr,
                             OpBuilder &b, Location loc);

private:
  llvm::StringMap<LLVM::GlobalOp> globals;
};

} // namespace evm
} // namespace mlir

#endif // MLIR_CONVERSION_SOLTOYUL_SOLTOYUL_H
