// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test
// CHECK:         func.func @__entry()
// CHECK:           "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.invalid"}> : () -> ()
// CHECK-NEXT:      call @".unreachable"() : () -> ()
// CHECK-NEXT:      llvm.unreachable

module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown"} {
  yul.object @Test {
    yul.invalid
  }
}

