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
#include "mlir-c/Target/LLVMIR.h"
#include "llvm-c/Core.h"

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

// CHECK-LABEL: testYulToLLVMIRTranslations
static void testYulToLLVMIRTranslations(MlirContext ctx) {
  fprintf(stderr, "testYulToLLVMIRTranslations\n");

  MlirModule module = mlirModuleCreateParse(
      ctx, mlirStringRefCreateFromCString(
               "module { yul.object @O { "
               "yul.func @__entry : () -> () { yul.stop } } }"));
  if (mlirModuleIsNull(module)) {
    fprintf(stderr, "Module parsing failed\n");
    exit(EXIT_FAILURE);
  }
  MlirOperation moduleOp = mlirModuleGetOperation(module);
  LLVMContextRef llvmCtx = LLVMContextCreate();

  if (mlirTranslateModuleToLLVMIR(moduleOp, llvmCtx)) {
    fprintf(stderr, "Module translated before registration\n");
    exit(EXIT_FAILURE);
  }
  // CHECK: translation failed before registration
  fprintf(stderr, "translation failed before registration\n");

  mlirRegisterYulToLLVMIRTranslations(ctx);

  LLVMModuleRef llvmModule = mlirTranslateModuleToLLVMIR(moduleOp, llvmCtx);
  if (!llvmModule) {
    fprintf(stderr, "Module translation failed after registration\n");
    exit(EXIT_FAILURE);
  }
  // CHECK: translation succeeded after registration
  fprintf(stderr, "translation succeeded after registration\n");

  LLVMDisposeModule(llvmModule);
  LLVMContextDispose(llvmCtx);
  mlirModuleDestroy(module);
}

int main(void) {
  MlirContext ctx = mlirContextCreate();
  testYulDialectHandle(ctx);
  testYulToLLVMIRTranslations(ctx);
  mlirContextDestroy(ctx);
  return 0;
}
