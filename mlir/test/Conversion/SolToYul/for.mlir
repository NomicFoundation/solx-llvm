// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
module {
  sol.contract @C {
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
        ^bb1:  // no predecessors
          sol.yield
        } else {
        }
        sol.if %k {
          sol.continue
        ^bb1:  // no predecessors
          sol.yield
        } else {
        }
        sol.yield
      } step {
        sol.yield
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}
