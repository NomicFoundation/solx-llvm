// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @object
// CHECK:       func.func @__entry()
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  }

module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown"} {
  yul.object @object {
  }
}
