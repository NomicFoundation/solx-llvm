// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test
// CHECK:         func.func @__entry()
// CHECK:           call @halt() : () -> ()
// CHECK-NEXT:      llvm.unreachable

module {
  yul.object @Test {
    yul.func @halt : () -> () {
      yul.invalid
    }
    yul.func @__entry : () -> () {
      yul.func_call @halt() : () -> ()
      yul.unreachable
    }
  }
}
