// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-NOT:   yul.object
// CHECK-LABEL: yul.func @ret_42 : () -> i256
// CHECK:         yul.func_return %c42_i256{{.*}} : i256
// CHECK:       } {llvm.linkage = #llvm.linkage<private>}
// CHECK-NOT:   yul.object

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @ret_42() -> ui256 {
    %c42_ui256 = sol.constant 42 : ui256
    sol.return %c42_ui256 : ui256
  }
}
