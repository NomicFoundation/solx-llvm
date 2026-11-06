// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @results
// CHECK-NEXT:  ^bb0(%[[C:.*]]: i256, %[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK-NEXT:    %[[R:.*]] = yul.if %[[C]] -> i256 {
// CHECK-NEXT:      yul.yield %[[A]] : i256
// CHECK-NEXT:    } else {
// CHECK-NEXT:      yul.yield %[[B]] : i256
// CHECK-NEXT:    }
// CHECK-NEXT:    yul.func_return %[[R]] : i256

// CHECK-LABEL: yul.func @if_else
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK:         %[[C:.*]] = yul.cmp eq, %[[A]], %[[B]]
// CHECK:         yul.if %[[C]] {
// CHECK-NEXT:      yul.func_call @g(%[[A]])
// CHECK-NEXT:      yul.yield
// CHECK-NEXT:    } else {
// CHECK-NEXT:      yul.func_call @g(%[[B]])
// CHECK-NEXT:      yul.yield
// CHECK-NEXT:    }

module {
  sol.contract @C {
    sol.func @g(%x: ui256) {
      sol.return
    }
    sol.func @if_else(%a: ui256, %b: ui256) {
      %0 = sol.cmp eq, %a, %b : ui256
      sol.if %0 {
        sol.call @g(%a) : (ui256) -> ()
        sol.yield
      } else {
        sol.call @g(%b) : (ui256) -> ()
        sol.yield
      }
      sol.return
    }
    sol.func @results(%c: i1, %a: ui256, %b: ui256) -> ui256 {
      %0 = sol.if %c -> ui256 {
        sol.yield %a : ui256
      } else {
        sol.yield %b : ui256
      }
      sol.return %0 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
