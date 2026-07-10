//===- Utils.h - Sol dialect IR-construction utilities ----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Helpers that build Sol dialect IR, shared by the frontend, passes and
// conversions.
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_DIALECT_SOL_UTILS_H_
#define MLIR_DIALECT_SOL_UTILS_H_

#include "mlir/IR/Builders.h"

namespace mlir {
namespace sol {

/// Materialises the Solidity default value for `ty` at the builder's current
/// insertion point.
Value genDefaultVal(OpBuilder &b, Type ty, Location loc);

} // namespace sol
} // namespace mlir

#endif // MLIR_DIALECT_SOL_UTILS_H_
