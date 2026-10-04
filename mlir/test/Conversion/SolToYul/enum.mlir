// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Every enum value read is range-checked against the max member (2), with
// panic 0x21 on failure.
// CHECK-LABEL: yul.func @cmp : (i256, i256) -> (i256, i256)
// CHECK:         %[[MAX:.*]] = yul.constant 2{{$}}
// CHECK:         %[[BAD:.*]] = yul.cmp ugt, %arg0, %[[MAX]]
// CHECK:         yul.if %[[BAD]] {
// CHECK:           %[[PANIC:.*]] = yul.constant 33{{$}}
// CHECK:           yul.mstore %{{.*}}, %[[PANIC]]
// CHECK:           yul.revert
// CHECK:         yul.cmp ugt, %arg1, %{{.*}}
// CHECK:         %[[EQ:.*]] = yul.cmp eq, %arg0, %arg1
// CHECK:         %[[LT:.*]] = yul.cmp ult, %arg0, %arg1
// CHECK:         yul.func_return %[[EQ]], %[[LT]] : i256, i256

// CHECK-LABEL: yul.func @fromUint : (i256) -> i256
// CHECK:         %[[MAX:.*]] = yul.constant 2{{$}}
// CHECK:         %[[BAD:.*]] = yul.cmp ugt, %arg0, %[[MAX]]
// CHECK:         yul.if %[[BAD]] {
// CHECK:           yul.constant 33{{$}}
// CHECK:         yul.func_return %arg0 : i256

// CHECK-LABEL: yul.func @toUint : (i256) -> i256
// CHECK:         %[[MAX:.*]] = yul.constant 2{{$}}
// CHECK:         %[[BAD:.*]] = yul.cmp ugt, %arg0, %[[MAX]]
// CHECK:         yul.if %[[BAD]] {
// CHECK:           yul.constant 33{{$}}
// CHECK:         yul.func_return %arg0 : i256

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @cmp(%arg0: !sol.enum<2>, %arg1: !sol.enum<2>) -> (i1, i1) {
    %0 = sol.cmp eq, %arg0, %arg1 : !sol.enum<2>
    %1 = sol.cmp lt, %arg0, %arg1 : !sol.enum<2>
    sol.return %0, %1 : i1, i1
  }
  sol.func @fromUint(%arg0: ui256) -> !sol.enum<2> {
    %0 = sol.enum_cast %arg0 : ui256 to !sol.enum<2>
    sol.return %0 : !sol.enum<2>
  }
  sol.func @toUint(%arg0: !sol.enum<2>) -> ui256 {
    %0 = sol.enum_cast %arg0 : !sol.enum<2> to ui256
    sol.return %0 : ui256
  }
}
