// RUN: mlir-opt %s -split-input-file | mlir-opt -split-input-file | FileCheck %s

// CHECK:      yul.object @Empty {
// CHECK-NEXT:   yul.func @__entry : () -> () {
// CHECK-NEXT:     yul.func_return
// CHECK-NEXT:   }
// CHECK-NEXT: }
yul.object @Empty {
  yul.func @__entry : () -> () {
    yul.func_return
  }
}

// -----

// CHECK:      yul.object @Body {
// CHECK-NEXT:   yul.func @__entry : () -> () {
// CHECK-NEXT:     yul.constant 1
// CHECK-NEXT:     yul.func_return
// CHECK-NEXT:   }
// CHECK-NEXT: }
yul.object @Body {
  yul.func @__entry : () -> () {
    %c1 = yul.constant 1
    yul.func_return
  }
}
