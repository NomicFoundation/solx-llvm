//===- yul.c - Test of Yul dialect C API ---------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM
// Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// RUN: mlir-capi-yul-test 2>&1 | FileCheck %s

#include "mlir-c/Dialect/Yul.h"
#include "mlir-c/IR.h"

#include <stdio.h>
#include <stdlib.h>

// CHECK-LABEL: testYulDialectHandle
static void testYulDialectHandle(MlirContext ctx) {
  fprintf(stderr, "testYulDialectHandle\n");

  MlirDialectHandle yulHandle = mlirGetDialectHandle__yul__();
  mlirDialectHandleRegisterDialect(yulHandle, ctx);
  MlirDialect yulDialect = mlirDialectHandleLoadDialect(yulHandle, ctx);

  if (mlirDialectIsNull(yulDialect)) {
    fprintf(stderr, "Yul dialect not loaded\n");
    exit(EXIT_FAILURE);
  }
  // CHECK: Yul dialect loaded successfully
  fprintf(stderr, "Yul dialect loaded successfully\n");

  MlirStringRef yulCaller = mlirStringRefCreateFromCString("yul.caller");
  if (!mlirContextIsRegisteredOperation(ctx, yulCaller)) {
    fprintf(stderr, "yul.caller op not registered\n");
    exit(EXIT_FAILURE);
  }
  // CHECK: yul.caller op registered successfully
  fprintf(stderr, "yul.caller op registered successfully\n");
}

int main(void) {
  MlirContext ctx = mlirContextCreate();
  testYulDialectHandle(ctx);
  mlirContextDestroy(ctx);
  return 0;
}
