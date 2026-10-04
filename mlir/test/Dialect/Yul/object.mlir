// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK:      yul.object @Empty {
// CHECK-NEXT: }
yul.object @Empty {
}

// CHECK:      yul.object @Outer {
// CHECK-NEXT:   yul.object @Inner {
// CHECK-NEXT:   }
// CHECK-NEXT:   yul.constant 1
// CHECK-NEXT: }
yul.object @Outer {
  yul.object @Inner {
  }
  %c1 = yul.constant 1
}
