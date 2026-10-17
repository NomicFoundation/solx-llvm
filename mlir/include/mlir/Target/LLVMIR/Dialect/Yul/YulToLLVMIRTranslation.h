//===- YulToLLVMIRTranslation.h - Yul Dialect to LLVM IR --------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This provides registration calls for Yul dialect to LLVM IR translation.
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_TARGET_LLVMIR_DIALECT_YUL_YULTOLLVMIRTRANSLATION_H
#define MLIR_TARGET_LLVMIR_DIALECT_YUL_YULTOLLVMIRTRANSLATION_H

namespace mlir {

class DialectRegistry;
class MLIRContext;

/// Register the translation from the Yul dialect to the LLVM IR in the given
/// registry.
void registerYulDialectTranslation(DialectRegistry &registry);

/// Register the translation from the Yul dialect in the registry associated
/// with the given context.
void registerYulDialectTranslation(MLIRContext &context);

} // namespace mlir

#endif // MLIR_TARGET_LLVMIR_DIALECT_YUL_YULTOLLVMIRTRANSLATION_H
