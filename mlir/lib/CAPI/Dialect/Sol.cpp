//===- Sol.cpp - C API for Sol dialect ------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "mlir-c/Dialect/Sol.h"
#include "mlir/CAPI/IR.h"
#include "mlir/CAPI/Registration.h"
#include "mlir/CAPI/Wrap.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/Dialect/Sol/Utils.h"

MLIR_DEFINE_CAPI_DIALECT_REGISTRATION(Sol, sol, mlir::sol::SolDialect)

MlirType mlirSolGetEltType(MlirType ty, uint64_t structFieldIdx) {
  return wrap(mlir::sol::getEltType(unwrap(ty), structFieldIdx));
}

MlirType mlirSolGepGetResultType(MlirType baseAddrTy, MlirType elementType) {
  return wrap(
      mlir::sol::GepOp::getResultType(unwrap(baseAddrTy), unwrap(elementType)));
}

MlirValue mlirSolGenDefaultVal(MlirBlock block, MlirOperation insertBefore,
                               MlirType ty, MlirLocation loc) {
  mlir::OpBuilder b(unwrap(ty).getContext());
  if (!mlirOperationIsNull(insertBefore))
    b.setInsertionPoint(unwrap(insertBefore));
  else
    b.setInsertionPointToEnd(unwrap(block));
  return wrap(mlir::sol::genDefaultVal(b, unwrap(ty), unwrap(loc)));
}
