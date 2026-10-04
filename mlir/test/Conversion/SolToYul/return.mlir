// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// An early return lowers in place inside the yul.if region.

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @f : (i256) -> i256
    // CHECK:       ^bb0(%[[A:.*]]: i256):
    // CHECK:         yul.if %[[A]] {
    // CHECK:           yul.func_return %c2_i256{{.*}} : i256
    // CHECK:         ^bb1:
    // CHECK:           yul.yield
    // CHECK:         } else {
    // CHECK:         }
    // CHECK:         yul.func_return %c0_i256{{.*}} : i256
    sol.func @f(%arg0: i1) -> ui256 attributes {state_mutability = #NonPayable} {
      sol.if %arg0 {
        %c2 = sol.constant 2 : ui256
        sol.return %c2 : ui256
      ^bb1:  // no predecessors
        sol.yield
      } else {
      }
      %c0 = sol.constant 0 : ui256
      sol.return %c0 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @g : (i256) -> ()
    // CHECK:       ^bb0(%[[A:.*]]: i256):
    // CHECK:         yul.if %[[A]] {
    // CHECK-NEXT:      yul.func_return
    // CHECK:         } else {
    // CHECK:         }
    // CHECK-NEXT:    yul.func_return
    sol.func @g(%arg0: i1) attributes {state_mutability = #NonPayable} {
      sol.if %arg0 {
        sol.return
      ^bb1:  // no predecessors
        sol.yield
      } else {
      }
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
