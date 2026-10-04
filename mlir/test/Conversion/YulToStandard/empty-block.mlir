// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @object
// CHECK:       func.func @__entry()
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  }

module {
  yul.object @object {
  }
}
