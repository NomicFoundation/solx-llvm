//===-- Passes.td - Sol pass definition file ---------------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_DIALECT_SOL_TRANSFORMS_PASSES
#define MLIR_DIALECT_SOL_TRANSFORMS_PASSES

include "mlir/Pass/PassBase.td"

def ModifierInliningPass : Pass<"sol-inline-modifiers", "ModuleOp"> {
  let summary = "Inline modifier bodies around modified function bodies";
}

def LoopInvariantCodeMotionPass : Pass<"sol-licm"> {
  let summary = "Loop invariant code motion for the Sol dialect";
}

#endif
