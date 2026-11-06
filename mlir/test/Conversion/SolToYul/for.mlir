// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
module {
  sol.contract @C {
    // The carried values become the Yul loop's, and each exit carries them on.
    // CHECK-LABEL: yul.func @carried
    // CHECK-NEXT:  ^bb0(%[[X:.*]]: i256, %[[B:.*]]: i256, %[[K:.*]]: i256):
    // CHECK-NEXT:    %[[R:.*]] = yul.for %[[X]] : i256 -> i256 cond {
    // CHECK-NEXT:    ^bb0(%[[I:.*]]: i256):
    // CHECK-NEXT:      yul.condition %[[B]], %[[I]] : i256
    // CHECK-NEXT:    } body {
    // CHECK-NEXT:    ^bb0(%[[J:.*]]: i256):
    // CHECK-NEXT:      yul.if %[[B]] {
    // CHECK-NEXT:        yul.break %[[J]] : i256
    // CHECK:           yul.if %[[K]] {
    // CHECK-NEXT:        yul.continue %[[J]] : i256
    // CHECK:           yul.yield %[[J]] : i256
    // CHECK-NEXT:    } step {
    // CHECK-NEXT:    ^bb0(%[[S:.*]]: i256):
    // CHECK-NEXT:      yul.yield %[[S]] : i256
    // CHECK-NEXT:    }
    // CHECK-NEXT:    yul.func_return %[[R]] : i256

    // CHECK-LABEL: yul.func @f
    // CHECK-NEXT:  ^bb0(%[[C:.*]]: i256, %[[B:.*]]: i256, %[[K:.*]]: i256):
    // CHECK:         yul.for cond {
    // CHECK-NEXT:      yul.condition %[[C]]
    // CHECK:         } body {
    // CHECK:           yul.if %[[B]] {
    // CHECK-NEXT:        yul.break
    // CHECK:           yul.if %[[K]] {
    // CHECK-NEXT:        yul.continue
    // CHECK:         } step {
    // CHECK-NEXT:      yul.yield
    // CHECK-NEXT:    }
    sol.func @f(%c: i1, %b: i1, %k: i1) {
      sol.for cond {
        sol.condition %c
      } body {
        sol.if %b {
          sol.break
        } else {
        }
        sol.if %k {
          sol.continue
        } else {
        }
        sol.yield
      } step {
        sol.yield
      }
      sol.return
    }
    sol.func @carried(%x: ui256, %b: i1, %k: i1) -> ui256 {
      %r = sol.for %x : ui256 -> ui256 cond {
      ^bb0(%i: ui256):
        sol.condition %b, %i : ui256
      } body {
      ^bb0(%j: ui256):
        sol.if %b {
          sol.break %j : ui256
        } else {
        }
        sol.if %k {
          sol.continue %j : ui256
        } else {
        }
        sol.yield %j : ui256
      } step {
      ^bb0(%s: ui256):
        sol.yield %s : ui256
      }
      sol.return %r : ui256
    }
  } {kind = #Contract, runtime}
}
