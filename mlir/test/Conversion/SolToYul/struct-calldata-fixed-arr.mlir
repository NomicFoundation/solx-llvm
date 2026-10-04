// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The calldata uint256[2] member is inline, so c sits at byte 96.
// CHECK-LABEL: yul.func @getC : (i256) -> i256
// CHECK-NEXT:  ^bb0(%[[S:.*]]: i256):
// CHECK:         %[[C96:.*]] = yul.constant 96
// CHECK:         %[[P:.*]] = yul.add %[[S]], %[[C96]]
// CHECK:         %[[V:.*]] = yul.calldataload %[[P]]
// CHECK:         yul.func_return %[[V]] : i256

#Default = #sol<RevertStrings Default>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @getC(%arg0: !sol.struct<(ui256, !sol.array<2 x ui256, CallData>, ui256), CallData>) -> ui256 attributes {state_mutability = #Pure} {
    %c2_ui64 = sol.constant 2 : ui64
    %0 = sol.gep %arg0, %c2_ui64 : !sol.struct<(ui256, !sol.array<2 x ui256, CallData>, ui256), CallData>, ui64, !sol.ptr<ui256, CallData>
    %1 = sol.load %0 : !sol.ptr<ui256, CallData>, ui256
    sol.return %1 : ui256
  }
}
