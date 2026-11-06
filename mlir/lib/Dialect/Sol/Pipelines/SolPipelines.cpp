//===- SolPipelines.cpp - Pipelines for the Sol dialect -------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Sol/Pipelines/Passes.h"

#include "mlir/Conversion/SolToYul/SolToYul.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/Dialect/Sol/Transforms/Passes.h"
#include "mlir/Dialect/Yul/Yul.h"
#include "mlir/Pass/PassManager.h"
#include "mlir/Pass/PassRegistry.h"
#include "mlir/Transforms/Passes.h"

//===----------------------------------------------------------------------===//
// Pipeline implementation.
//===----------------------------------------------------------------------===//

void mlir::sol::buildSolToYulPipeline(OpPassManager &pm) {
  // The canonicalizers run per function; there is little to canonicalize
  // outside one.
  pm.addPass(createModifierInliningPass());
  pm.nest<ContractOp>().nest<FuncOp>().addPass(createMem2Reg());
  pm.nest<ContractOp>().nest<FuncOp>().addPass(createCanonicalizerPass());
  pm.addPass(createConvertSolToYulPass());
  pm.nest<yul::ObjectOp>().nest<yul::FuncOp>().addPass(
      createCanonicalizerPass());
}

//===----------------------------------------------------------------------===//
// Pipeline registration.
//===----------------------------------------------------------------------===//

void mlir::sol::registerSolPipelines() {
  PassPipelineRegistration<>(
      "sol-to-yul-pipeline",
      "Lowers a Sol module to the Yul module the LLVM IR translation reads.",
      buildSolToYulPipeline);
}
