// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @ret_42 : () -> i256
// CHECK:         yul.func_return %c42_i256{{.*}} : i256
// CHECK:       } {llvm.linkage = #llvm.linkage<private>}

module {
  sol.contract @C {
    sol.func @ret_42() -> ui256 {
      %c42_ui256 = sol.constant 42 : ui256
      sol.return %c42_ui256 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
