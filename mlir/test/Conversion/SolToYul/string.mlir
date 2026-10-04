// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @f : (i256, i256) -> i256
// CHECK:         %[[BV:.*]] = yul.arith_shl %arg1
// CHECK:         %[[LEN:.*]] = yul.mload %arg0
// CHECK:         %[[OOB:.*]] = yul.cmp uge, %[[IDX:.*]], %[[LEN]]
// CHECK:         yul.if %[[OOB]] {
// CHECK:           yul.constant 50
// CHECK:         %[[DATA:.*]] = yul.add %arg0, %{{.*}}
// CHECK:         %[[ADDR:.*]] = yul.add %[[DATA]], %[[IDX]]
// CHECK:         %[[B:.*]] = yul.byte %{{.*}}, %[[BV]]
// CHECK:         yul.mstore8 %[[ADDR]], %[[B]]
// CHECK:         %[[W:.*]] = yul.mload
// CHECK:         yul.constant -452312848583266388373324160190187140051835877600158453279131187530910662656
// CHECK:         %[[C248:.*]] = yul.constant 248
// CHECK:         %[[R:.*]] = yul.arith_shr %{{.*}}, %[[C248]]
// CHECK:         yul.func_return %[[R]] : i256

// CHECK-LABEL: yul.func @g : (i256) -> i256
// CHECK:         %[[LEN:.*]] = yul.mload %arg0
// CHECK:         yul.func_return %[[LEN]] : i256

#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @f(%arg0: !sol.string<Memory>, %arg1: ui8) -> ui8 attributes {state_mutability = #NonPayable} {
    %0 = sol.bytes_cast %arg1 : ui8 to !sol.fixedbytes<1>
    %c0 = sol.constant 0 : ui8
    %1 = sol.gep %arg0, %c0 : !sol.string<Memory>, ui8, !sol.ptr<!sol.byte, Memory>
    %2 = sol.bytes_cast %0 : !sol.fixedbytes<1> to !sol.byte
    sol.store %2, %1 : !sol.byte, !sol.ptr<!sol.byte, Memory>
    %3 = sol.gep %arg0, %c0 : !sol.string<Memory>, ui8, !sol.ptr<!sol.byte, Memory>
    %4 = sol.load %3 : !sol.ptr<!sol.byte, Memory>, !sol.byte
    %5 = sol.bytes_cast %4 : !sol.byte to ui8
    sol.return %5 : ui8
  }
  sol.func @g(%arg0: !sol.string<Memory>) -> ui256 attributes {state_mutability = #NonPayable} {
    %0 = sol.length %arg0 : !sol.string<Memory>
    sol.return %0 : ui256
  }
}
