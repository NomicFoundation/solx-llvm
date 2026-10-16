// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A constant in its type's range is not cleaned.

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// CHECK-LABEL: yul.func @dirty
// CHECK:       ^bb0(%[[ARG:.*]]: i256):
// CHECK-NEXT:    yul.constant -1
// CHECK-NEXT:    %[[C255:.*]] = yul.constant 255
// CHECK-NEXT:    %[[MASK:.*]] = yul.constant 255
// CHECK-NEXT:    %[[CLEAN:.*]] = yul.and %[[ARG]], %[[MASK]]
// CHECK-NEXT:    yul.cmp eq, %[[CLEAN]], %[[C255]]
// CHECK-NEXT:    yul.func_return

// CHECK-LABEL: yul.func @out_of_range
// CHECK-NEXT:    %[[C5:.*]] = yul.constant 5
// CHECK-NEXT:    %[[MAX:.*]] = yul.constant 2
// CHECK-NEXT:    %[[COND:.*]] = yul.cmp ugt, %[[C5]], %[[MAX]]
// CHECK-NEXT:    yul.if %[[COND]]
// CHECK:           yul.constant 33
// CHECK:           yul.revert
// CHECK:         yul.func_return %[[C5]]

// CHECK-LABEL: yul.func @lits
// CHECK-NEXT:    %[[T:.*]] = yul.constant 1
// CHECK-NEXT:    %[[E:.*]] = yul.constant 2
// CHECK-NEXT:    yul.func_return %[[T]], %[[E]]

// Only the argument gets the range check.
// CHECK-LABEL: yul.func @is_b
// CHECK:       ^bb0(%[[ARG:.*]]: i256):
// CHECK-NEXT:    %[[B:.*]] = yul.constant 1
// CHECK-NEXT:    %[[MAX:.*]] = yul.constant 2
// CHECK-NEXT:    yul.cmp ugt, %[[ARG]], %[[MAX]]
// CHECK:         yul.revert
// CHECK:         yul.cmp eq, %[[ARG]], %[[B]]
// CHECK-NEXT:    yul.func_return

// CHECK-LABEL: yul.func @not
// CHECK:       ^bb0(%[[ARG:.*]]: i256):
// CHECK-NEXT:    %[[F:.*]] = yul.constant 0
// CHECK-NEXT:    %[[C0:.*]] = yul.constant 0
// CHECK-NEXT:    %[[D:.*]] = yul.cmp ne, %[[ARG]], %[[C0]]
// CHECK-NEXT:    yul.cmp eq, %[[D]], %[[F]]
// CHECK-NEXT:    yul.func_return

module {
  sol.contract @C {
    sol.func @not(%arg0: i1) -> i1 attributes {orig_fn_type = (i1) -> i1, selector = 1 : i32, state_mutability = #Pure} {
      %false = sol.constant false
      %0 = sol.cmp eq, %arg0, %false : i1
      sol.return %0 : i1
    }
    sol.func @is_b(%arg0: !sol.enum<2>) -> i1 attributes {orig_fn_type = (!sol.enum<2>) -> i1, selector = 2 : i32, state_mutability = #Pure} {
      %c1 = sol.constant 1 : ui256
      %0 = sol.enum_cast %c1 : ui256 to !sol.enum<2>
      %1 = sol.cmp eq, %arg0, %0 : !sol.enum<2>
      sol.return %1 : i1
    }
    sol.func @lits() -> (i1, !sol.enum<2>) attributes {orig_fn_type = () -> (i1, !sol.enum<2>), selector = 3 : i32, state_mutability = #Pure} {
      %true = sol.constant true
      %c2 = sol.constant 2 : ui256
      %0 = sol.enum_cast %c2 : ui256 to !sol.enum<2>
      sol.return %true, %0 : i1, !sol.enum<2>
    }
    sol.func @out_of_range() -> !sol.enum<2> attributes {orig_fn_type = () -> !sol.enum<2>, selector = 4 : i32, state_mutability = #Pure} {
      %c5 = sol.constant 5 : ui8
      %0 = sol.enum_cast %c5 : ui8 to !sol.enum<2>
      sol.return %0 : !sol.enum<2>
    }
    sol.func @dirty(%arg0: ui8) -> i1 attributes {orig_fn_type = (ui8) -> i1, selector = 5 : i32, state_mutability = #Pure} {
      %c = sol.constant -1 : si8
      %0 = sol.cast %c : si8 to ui8
      %1 = sol.cmp eq, %arg0, %0 : ui8
      sol.return %1 : i1
    }
  } {kind = #Contract, runtime}
}
