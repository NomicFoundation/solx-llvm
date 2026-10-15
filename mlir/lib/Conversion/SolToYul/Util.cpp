//===- Util.cpp - MLIR Solidity utilities ---------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements MLIR utility classes for Solidity codegen.
//
//===----------------------------------------------------------------------===//

#include "mlir/Conversion/SolToYul/Util.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/LLVMIR/LLVMTypes.h"
#include "mlir/Dialect/Yul/Yul.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Types.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallVector.h"
#include <vector>

using namespace mlir;
using namespace mlir::solgen;

Value BuilderExt::genLLVMStruct(ValueRange vals,
                                std::optional<Location> locArg) {
  Location loc = locArg ? *locArg : defLoc;

  SmallVector<Type> eltTys;
  for (Value v : vals)
    eltTys.push_back(v.getType());
  auto structTy = LLVM::LLVMStructType::getLiteral(b.getContext(), eltTys);

  Value res = b.create<LLVM::UndefOp>(loc, structTy);
  for (auto [i, v] : llvm::enumerate(vals))
    res = b.create<LLVM::InsertValueOp>(loc, structTy, res, v,
                                        b.getDenseI64ArrayAttr(i));
  return res;
}
