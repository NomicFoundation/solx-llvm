// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A division, modulo, addmod or mulmod by a nonzero constant gets no
// division-by-zero check.

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// CHECK-LABEL: yul.func @div_by_variable
// CHECK:       ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK-NEXT:    %[[Z:.*]] = yul.constant 0
// CHECK-NEXT:    yul.cmp eq, %[[B]], %[[Z]]
// CHECK:         yul.func_call @__sol.panic
// CHECK:         yul.arith_div %[[A]], %[[B]]

// A checked division by minus one keeps the overflow check only.
// CHECK-LABEL: yul.func @cdiv_minus_one
// CHECK:       ^bb0(%[[A:.*]]: i256):
// CHECK-NEXT:    %[[C:.*]] = yul.constant -1
// CHECK-NEXT:    %[[MIN:.*]] = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
// CHECK-NEXT:    yul.cmp eq, %[[A]], %[[MIN]]
// CHECK:         yul.func_call @__sol.panic
// CHECK:         yul.arith_sdiv %[[A]], %[[C]]

// CHECK-LABEL: yul.func @mulmod
// CHECK:       ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK-NEXT:    %[[C:.*]] = yul.constant 5
// CHECK-NEXT:    yul.mulmod %[[A]], %[[B]], %[[C]]
// CHECK-NEXT:    yul.func_return

// CHECK-LABEL: yul.func @addmod
// CHECK:       ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK-NEXT:    %[[C:.*]] = yul.constant 5
// CHECK-NEXT:    yul.addmod %[[A]], %[[B]], %[[C]]
// CHECK-NEXT:    yul.func_return

// CHECK-LABEL: yul.func @mod
// CHECK:       ^bb0(%[[A:.*]]: i256):
// CHECK-NEXT:    %[[C:.*]] = yul.constant 3
// CHECK-NEXT:    yul.arith_mod %[[A]], %[[C]]
// CHECK-NEXT:    yul.func_return

// CHECK-LABEL: yul.func @div
// CHECK:       ^bb0(%[[A:.*]]: i256):
// CHECK-NEXT:    %[[C:.*]] = yul.constant 2
// CHECK-NEXT:    yul.arith_div %[[A]], %[[C]]
// CHECK-NEXT:    yul.func_return

module {
  sol.contract @C {
    sol.func @div(%arg0: ui256) -> ui256 attributes {orig_fn_type = (ui256) -> ui256, selector = 1 : i32, state_mutability = #Pure} {
      %c = sol.constant 2 : ui256
      %0 = sol.div %arg0, %c : ui256
      sol.return %0 : ui256
    }
    sol.func @mod(%arg0: ui256) -> ui256 attributes {orig_fn_type = (ui256) -> ui256, selector = 2 : i32, state_mutability = #Pure} {
      %c = sol.constant 3 : ui256
      %0 = sol.mod %arg0, %c : ui256
      sol.return %0 : ui256
    }
    sol.func @addmod(%arg0: ui256, %arg1: ui256) -> ui256 attributes {orig_fn_type = (ui256, ui256) -> ui256, selector = 3 : i32, state_mutability = #Pure} {
      %c = sol.constant 5 : ui256
      %0 = sol.addmod %arg0, %arg1, %c : ui256
      sol.return %0 : ui256
    }
    sol.func @mulmod(%arg0: ui256, %arg1: ui256) -> ui256 attributes {orig_fn_type = (ui256, ui256) -> ui256, selector = 4 : i32, state_mutability = #Pure} {
      %c = sol.constant 5 : ui256
      %0 = sol.mulmod %arg0, %arg1, %c : ui256
      sol.return %0 : ui256
    }
    sol.func @cdiv_minus_one(%arg0: si256) -> si256 attributes {orig_fn_type = (si256) -> si256, selector = 5 : i32, state_mutability = #Pure} {
      %c = sol.constant -1 : si256
      %0 = sol.cdiv %arg0, %c : si256
      sol.return %0 : si256
    }
    sol.func @div_by_variable(%arg0: ui256, %arg1: ui256) -> ui256 attributes {orig_fn_type = (ui256, ui256) -> ui256, selector = 6 : i32, state_mutability = #Pure} {
      %0 = sol.div %arg0, %arg1 : ui256
      sol.return %0 : ui256
    }
  } {kind = #Contract, runtime}
}
