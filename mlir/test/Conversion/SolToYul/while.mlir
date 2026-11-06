// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @carried : (i256, i256) -> i256
// CHECK-NEXT:  ^bb0(%[[C:.*]]: i256, %[[X:.*]]: i256):
// CHECK-NEXT:    %[[R:.*]] = yul.do %[[X]] : i256 -> i256 {
// CHECK-NEXT:    ^bb0(%[[I:.*]]: i256):
// CHECK-NEXT:      yul.yield %[[I]] : i256
// CHECK-NEXT:    } while {
// CHECK-NEXT:    ^bb0(%[[J:.*]]: i256):
// CHECK-NEXT:      yul.condition %[[C]], %[[J]] : i256
// CHECK-NEXT:    }
// CHECK-NEXT:    yul.func_return %[[R]] : i256

// CHECK-LABEL: yul.func @f : (i256, i256) -> ()
// CHECK-NEXT:  ^bb0(%[[C:.*]]: i256, %[[X:.*]]: i256):
// CHECK:         yul.while {
// CHECK-NEXT:      yul.condition %[[C]]
// CHECK-NEXT:    } do {
// CHECK-NEXT:      yul.func_call @g(%[[X]])
// CHECK-NEXT:      yul.yield
// CHECK-NEXT:    }
// CHECK-NEXT:    yul.do {
// CHECK-NEXT:      yul.func_call @g(%[[X]])
// CHECK-NEXT:      yul.yield
// CHECK-NEXT:    } while {
// CHECK-NEXT:      yul.condition %[[C]]
// CHECK-NEXT:    }

module {
  sol.contract @C {
    sol.func @g(%x: ui256) {
      sol.return
    }
    sol.func @f(%c: i1, %x: ui256) {
      sol.while {
        sol.condition %c
      } do {
        sol.call @g(%x) : (ui256) -> ()
        sol.yield
      }
      sol.do {
        sol.call @g(%x) : (ui256) -> ()
        sol.yield
      } while {
        sol.condition %c
      }
      sol.return
    }
    sol.func @carried(%c: i1, %x: ui256) -> ui256 {
      %0 = sol.do %x : ui256 -> ui256 {
      ^bb0(%i: ui256):
        sol.yield %i : ui256
      } while {
      ^bb0(%j: ui256):
        sol.condition %c, %j : ui256
      }
      sol.return %0 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
