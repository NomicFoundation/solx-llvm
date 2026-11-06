// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @results
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
// CHECK-NEXT:    %[[R:.*]] = yul.scope -> i256 {
// CHECK-NEXT:      yul.yield %[[A]] : i256
// CHECK-NEXT:    }
// CHECK-NEXT:    yul.func_return %[[R]] : i256

module {
  sol.contract @C {
    sol.func @results(%a: ui256) -> ui256 {
      %0 = sol.scope -> ui256 {
        sol.yield %a : ui256
      }
      sol.return %0 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
