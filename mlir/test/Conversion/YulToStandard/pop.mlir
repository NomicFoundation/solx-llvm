// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test
// CHECK:         func.func @__entry()
// CHECK-NEXT:      "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.msize"}> : () -> i256
// CHECK-NEXT:      llvm.unreachable

module {
  yul.object @Test {
    %0 = yul.msize
  }
}

