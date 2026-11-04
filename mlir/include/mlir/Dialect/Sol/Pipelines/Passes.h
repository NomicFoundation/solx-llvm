//===- Passes.h - Sol pipeline entry points ---------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This header file defines prototypes of all Sol pipelines.
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_DIALECT_SOL_PIPELINES_PASSES_H
#define MLIR_DIALECT_SOL_PIPELINES_PASSES_H

namespace mlir {
class OpPassManager;

namespace sol {

//===----------------------------------------------------------------------===//
// Building and Registering.
//===----------------------------------------------------------------------===//

/// Adds the pipeline that lowers a Sol module to the Yul module the LLVM IR
/// translation reads to the `OpPassManager`.
void buildSolToYulPipeline(OpPassManager &pm);

/// Registers all pipelines for the `sol` dialect. Currently, this includes
/// only the "sol-to-yul-pipeline".
void registerSolPipelines();

} // namespace sol
} // namespace mlir

#endif // MLIR_DIALECT_SOL_PIPELINES_PASSES_H
