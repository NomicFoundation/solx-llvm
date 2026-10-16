//===- Folders.h - Constant folding of integer ops --------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_DIALECT_YUL_FOLDERS_H
#define MLIR_DIALECT_YUL_FOLDERS_H

#include "mlir/Dialect/CommonFolders.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "llvm/ADT/APInt.h"

#include <optional>

namespace mlir::yul {

template <typename Fn>
Attribute foldUnary(ArrayRef<Attribute> operands, Fn compute) {
  return constFoldUnaryOp<IntegerAttr, APInt, /*PoisonAttr=*/void>(operands,
                                                                   compute);
}

/// `compute` returns an APInt, or a std::optional<APInt> that is empty where
/// the op does not fold.
template <typename Fn>
Attribute foldBinary(ArrayRef<Attribute> operands, Fn compute) {
  return constFoldBinaryOpConditional<IntegerAttr, APInt, /*PoisonAttr=*/void>(
      operands, [&](const APInt &a, const APInt &b) -> std::optional<APInt> {
        return compute(a, b);
      });
}

/// Folds a three-operand op with every operand constant.
template <typename Fn>
Attribute foldTernary(ArrayRef<Attribute> operands, Fn compute) {
  SmallVector<APInt, 3> vals;
  for (Attribute operand : operands) {
    auto intAttr = dyn_cast_or_null<IntegerAttr>(operand);
    if (!intAttr)
      return {};
    vals.push_back(intAttr.getValue());
  }
  return IntegerAttr::get(cast<IntegerAttr>(operands.front()).getType(),
                          compute(vals[0], vals[1], vals[2]));
}

} // namespace mlir::yul

#endif // MLIR_DIALECT_YUL_FOLDERS_H
