//===- SolToYul.h - Sol to Yul dialect conversion ---------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares the Sol-to-Yul conversion pass and its EVM-specific
// lowering patterns.
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_CONVERSION_SOLTOYUL_SOLTOYUL_H
#define MLIR_CONVERSION_SOLTOYUL_SOLTOYUL_H

#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/Dialect/Yul/Yul.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Transforms/DialectConversion.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/MapVector.h"
#include "llvm/ADT/SetVector.h"
#include "llvm/ADT/StringMap.h"

namespace mlir {

#define GEN_PASS_DECL_CONVERTSOLTOYULPASS
#include "mlir/Conversion/Passes.h.inc"

namespace evm {

class SolTypeConverter : public TypeConverter {
public:
  SolTypeConverter();
};

/// The internal function pointer dispatch of a module. Inline assembly can
/// retype a pointer, so a call reaches every target that takes and returns as
/// many words. The pass records its contract's creation_func_refs before
/// stage 2 erases the contract. Stage 1 records each sol.func_constant's target
/// and turns each sol.icall into a call of its dispatch function, one per
/// lowered signature, declared at its first call. The pass gives the dispatch
/// functions their bodies after stage 2 has moved the functions into their
/// object.
class InternalDispatch {
public:
  /// The words a function takes and returns.
  using WordCounts = std::pair<unsigned, unsigned>;

  explicit InternalDispatch(const TypeConverter &tyConv) : tyConv(tyConv) {}

  /// Records the functions `contr` lists in its creation_func_refs.
  void addCreationFuncRefs(sol::ContractOp contr);

  /// Records `fn` as a target of the calls that take and return as many words
  /// as it does.
  void addTarget(sol::FuncOp fn);

  /// Returns the dispatch function `icall` calls, of `dispatchFnTy`: the
  /// pointer ahead of the callee's arguments, to the callee's results. The
  /// first call of that signature declares it, so every call names an existing
  /// function.
  yul::FuncOp getOrCreateDispatchFn(sol::ICallOp icall,
                                    FunctionType dispatchFnTy,
                                    PatternRewriter &r);

  /// Gives each declared dispatch function its body, a switch over the targets
  /// of its word counts, and places it after its first caller.
  void genDispatchFns();

private:
  struct Request {
    yul::FuncOp fn;
    sol::FuncOp caller;
  };

  const TypeConverter &tyConv;
  /// The targets of the calls of each word counts, in the order they are
  /// recorded, which the cases of a dispatch follow.
  DenseMap<WordCounts, llvm::SmallSetVector<sol::FuncOp, 4>> targets;
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

/// Adds the conversion patterns of unchecked arithmetic ops in the sol dialect.
void populateArithPats(RewritePatternSet &pats, TypeConverter &tyConv);

/// Adds the conversion patterns of internal function pointers: the constants
/// and the calls through them, which `dispatch` records.
void populateInternalFuncPtrPats(RewritePatternSet &pats, TypeConverter &tyConv,
                                 InternalDispatch &dispatch);

/// Adds the conversion patterns of crypto ops in the sol dialect.
void populateCryptoPats(RewritePatternSet &pats, TypeConverter &tyConv);

/// Adds the conversion patterns of checked arithmetic ops in the sol dialect.
void populateCheckedArithPats(RewritePatternSet &pats, TypeConverter &tyConv);

/// Adds the conversion patterns of sol dialect ops dealing with stack, memory
/// and storage allocations. String literals take their globals from
/// `literals`.
///
/// Stack access will have 32-byte alignment while all other access will have
/// 1-byte alignment.
void populateMemPats(RewritePatternSet &pats, TypeConverter &tyConv,
                     StringLiteralPool &literals);

/// Adds the conversion pattern of sol.emit.
void populateEmitPat(RewritePatternSet &pats, TypeConverter &tyConv);

/// Adds the conversion pattern of sol.require.
void populateRequirePat(RewritePatternSet &pats);

/// Adds the conversion patterns for address/block/tx/msg/gas-related ops.
void populateAddrPat(RewritePatternSet &pats, TypeConverter &tyConv);

/// Adds the conversion patterns of abi ops.
void populateAbiPats(RewritePatternSet &pats, TypeConverter &tyConv);

/// Adds the conversion pattern of sol.ext_call.
void populateExtCallPat(RewritePatternSet &pats, TypeConverter &tyConv);

/// Adds the conversion patterns of control flow ops in the sol dialect.
void populateControlFlowPats(RewritePatternSet &pats, TypeConverter &tyConv);

/// Adds the conversion patterns of sol.call and sol.return.
void populateFuncBoundaryPats(RewritePatternSet &pats, TypeConverter &tyConv);

/// Adds the conversion pattern of sol.func.
void populateFuncOpPats(RewritePatternSet &pats, TypeConverter &tyConv);

/// Adds the conversion pattern of sol.contract.
void populateContractPat(RewritePatternSet &pats, const TypeConverter &tyConv);

/// Adds patterns for sol.inline_asm and related ops.
void populateInlineAsmPats(RewritePatternSet &pats, TypeConverter &tyConv);

void populateStage1Pats(RewritePatternSet &pats, TypeConverter &tyConv,
                        InternalDispatch &dispatch,
                        StringLiteralPool &literals);

void populateStage2Pats(RewritePatternSet &pats, const TypeConverter &tyConv);

} // namespace evm
} // namespace mlir

#endif // MLIR_CONVERSION_SOLTOYUL_SOLTOYUL_H
