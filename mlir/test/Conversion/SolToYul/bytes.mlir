// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @index : (i256, i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[I:.*]]: i256):
    // CHECK:         %[[LEN:.*]] = yul.constant 4{{$}}
    // CHECK:         %[[OOB:.*]] = yul.cmp uge, %[[I]], %[[LEN]]
    // CHECK:         yul.if %[[OOB]] {
    // CHECK:           %[[PANIC:.*]] = yul.constant 50{{$}}
    // CHECK:           yul.mstore %{{.*}}, %[[PANIC]]
    // CHECK:         %[[BYTE:.*]] = yul.byte %[[I]], %[[A]]
    // CHECK:         %[[C248:.*]] = yul.constant 248
    // CHECK:         %[[R:.*]] = yul.shl %[[C248]], %[[BYTE]]
    // CHECK:         yul.func_return %[[R]] : i256
    sol.func @index(%a: !sol.fixedbytes<4>, %i: ui256) -> !sol.fixedbytes<1> {
      %0 = sol.fixed_bytes_index %a[%i] : !sol.fixedbytes<4>, ui256 -> !sol.fixedbytes<1>
      sol.return %0 : !sol.fixedbytes<1>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // Narrowing to bytes4 leaves the value as is.
    // CHECK-LABEL: yul.func @b54 : (i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
    // CHECK-NEXT:    yul.func_return %[[A]] : i256
    sol.func @b54(%a: !sol.fixedbytes<5>) -> !sol.fixedbytes<4> {
      %0 = sol.bytes_cast %a : !sol.fixedbytes<5> to !sol.fixedbytes<4>
      sol.return %0 : !sol.fixedbytes<4>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
