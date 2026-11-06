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
  let description = [{
    Moves the loop-invariant storage and transient addresses of Sol loops out
    of them, and keeps the slots a loop accesses through loop-invariant
    addresses in values the loop carries, stored back after it only if the
    loop wrote them.
  }];
  let statistics = [
    Statistic<"numHoisted", "hoisted",
              "Number of address ops moved out of loops">,
    Statistic<"numPromoted", "promoted",
              "Number of storage and transient slots kept in values">
  ];
}

#endif
