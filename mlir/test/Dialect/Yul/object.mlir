// RUN: mlir-opt %s -split-input-file | mlir-opt -split-input-file | FileCheck %s

// CHECK:      yul.object @Empty {
// CHECK-NEXT: }
yul.object @Empty {
}

// -----

// CHECK:      yul.object @Body {
// CHECK-NEXT:   yul.constant 1
// CHECK-NEXT: }
yul.object @Body {
  %c1 = yul.constant 1
}
