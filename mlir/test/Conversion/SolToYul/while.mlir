// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

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
  } {kind = #sol<ContractKind Contract>, runtime}
}
