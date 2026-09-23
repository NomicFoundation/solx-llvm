// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Every enum value read is range-checked against the max member (2), with
// panic 0x21 on failure through the contract's panic helper.

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.panic : (i256) -> ()
    // CHECK-NEXT:  ^bb0(%[[CODE:.*]]: i256):
    // CHECK:         yul.mstore %{{.*}}, %[[CODE]]
    // CHECK:         yul.revert
    // CHECK-LABEL: yul.func @cmp : (i256, i256) -> (i256, i256)
    // CHECK:         %[[MAX:.*]] = yul.constant 2{{$}}
    // CHECK:         %[[BAD:.*]] = yul.cmp ugt, %arg0, %[[MAX]]
    // CHECK:         yul.if %[[BAD]] {
    // CHECK:           %[[PANIC:.*]] = yul.constant 33{{$}}
    // CHECK:           yul.func_call @__sol.panic(%[[PANIC]])
    // CHECK:         yul.cmp ugt, %arg1, %{{.*}}
    // CHECK:         %[[EQ:.*]] = yul.cmp eq, %arg0, %arg1
    // CHECK:         %[[LT:.*]] = yul.cmp ult, %arg0, %arg1
    // CHECK:         yul.func_return %[[EQ]], %[[LT]] : i256, i256
    sol.func @cmp(%arg0: !sol.enum<2>, %arg1: !sol.enum<2>) -> (i1, i1) {
      %0 = sol.cmp eq, %arg0, %arg1 : !sol.enum<2>
      %1 = sol.cmp lt, %arg0, %arg1 : !sol.enum<2>
      sol.return %0, %1 : i1, i1
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @fromUint : (i256) -> i256
    // CHECK:         %[[MAX:.*]] = yul.constant 2{{$}}
    // CHECK:         %[[BAD:.*]] = yul.cmp ugt, %arg0, %[[MAX]]
    // CHECK:         yul.if %[[BAD]] {
    // CHECK:           %[[PANIC:.*]] = yul.constant 33{{$}}
    // CHECK:           yul.func_call @__sol.panic(%[[PANIC]])
    // CHECK:         yul.func_return %arg0 : i256
    sol.func @fromUint(%arg0: ui256) -> !sol.enum<2> {
      %0 = sol.enum_cast %arg0 : ui256 to !sol.enum<2>
      sol.return %0 : !sol.enum<2>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @toUint : (i256) -> i256
    // CHECK:         %[[MAX:.*]] = yul.constant 2{{$}}
    // CHECK:         %[[BAD:.*]] = yul.cmp ugt, %arg0, %[[MAX]]
    // CHECK:         yul.if %[[BAD]] {
    // CHECK:           %[[PANIC:.*]] = yul.constant 33{{$}}
    // CHECK:           yul.func_call @__sol.panic(%[[PANIC]])
    // CHECK:         yul.func_return %arg0 : i256
    sol.func @toUint(%arg0: !sol.enum<2>) -> ui256 {
      %0 = sol.enum_cast %arg0 : !sol.enum<2> to ui256
      sol.return %0 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
