// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test
// CHECK:         func.func @__entry()
// CHECK:           "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.stop"}> : () -> ()
// CHECK-NEXT:      llvm.unreachable

module {
  yul.object @Test {
    yul.func @__entry : () -> () {
      yul.stop
      yul.func_return
    }
  }
}

