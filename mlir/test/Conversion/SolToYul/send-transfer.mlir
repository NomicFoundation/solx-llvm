// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

sol.contract @C {
  // The 2300 stipend applies only to a zero-value transfer.
  // CHECK-LABEL: yul.func @s : (i256, i256) -> i256
  // CHECK:         %[[Z:.*]] = yul.constant 0{{$}}
  // CHECK:         %[[STIPEND:.*]] = yul.constant 2300{{$}}
  // CHECK:         %[[ZV:.*]] = yul.cmp eq, %arg1, %[[Z]]
  // CHECK:         %[[GAS:.*]] = yul.arith_select %[[ZV]], %[[STIPEND]], %[[Z]]
  // CHECK:         %[[M:.*]] = yul.constant 1461501637330902918203684832716283019655932542975
  // CHECK:         %[[ADDR:.*]] = yul.and %arg0, %[[M]]
  // CHECK:         %[[OK:.*]] = yul.call %[[GAS]], %[[ADDR]], %arg1, %[[Z]], %[[Z]], %[[Z]], %[[Z]]
  // CHECK:         %[[B:.*]] = yul.cmp ne, %[[OK]], %[[Z]]
  // CHECK:         yul.func_return %[[B]] : i256
  sol.func @s(%a: !sol.address, %v: ui256) -> i1 {
    %0 = sol.send %a, %v : !sol.address, ui256 -> i1
    sol.return %0 : i1
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // A failed transfer bubbles the return data.
  // CHECK-LABEL: yul.func @t : (i256, i256) -> ()
  // CHECK:         %[[Z:.*]] = yul.constant 0{{$}}
  // CHECK:         %[[OK:.*]] = yul.call %{{.*}}, %{{.*}}, %arg1,
  // CHECK:         %[[FAILED:.*]] = yul.cmp eq, %[[OK]], %[[Z]]
  // CHECK:         yul.if %[[FAILED]] {
  // CHECK:           yul.returndatacopy
  // CHECK:           yul.revert
  sol.func @t(%a: !sol.address, %v: ui256) {
    sol.transfer %a, %v : !sol.address, ui256
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}
