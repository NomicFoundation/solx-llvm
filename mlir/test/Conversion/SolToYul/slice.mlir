// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A calldata array is an (offset, length) pair; a[s:e] reverts unless
// s <= e <= length and yields (offset + stride * s, e - s). The stride is 32
// for ui256 elements and 1 for bytes.

// CHECK-LABEL: yul.func @slice : (!llvm.struct<(i256, i256)>, !llvm.struct<(i256, i256)>, i256, i256) -> (!llvm.struct<(i256, i256)>, !llvm.struct<(i256, i256)>)
// CHECK-NEXT:  ^bb0(%[[A:.*]]: !llvm.struct<(i256, i256)>, %[[B:.*]]: !llvm.struct<(i256, i256)>, %[[S:.*]]: i256, %[[E:.*]]: i256):
// CHECK:         %[[OFF:.*]] = llvm.extractvalue %[[A]][0]
// CHECK:         %[[LEN:.*]] = llvm.extractvalue %[[A]][1]
// CHECK:         %[[C1:.*]] = yul.cmp ugt, %[[S]], %[[E]]
// CHECK:         yul.if %[[C1]] {
// CHECK:           yul.revert
// CHECK:         %[[C2:.*]] = yul.cmp ugt, %[[E]], %[[LEN]]
// CHECK:         yul.if %[[C2]] {
// CHECK:           yul.revert
// CHECK:         %[[SB:.*]] = yul.mul %[[S]], %c32_i256
// CHECK:         %[[NOFF:.*]] = yul.add %[[OFF]], %[[SB]]
// CHECK:         %[[NLEN:.*]] = yul.sub %[[E]], %[[S]]
// CHECK:         %[[R0:.*]] = llvm.insertvalue %[[NOFF]], %{{.*}}[0]
// CHECK:         %[[AS:.*]] = llvm.insertvalue %[[NLEN]], %[[R0]][1]

// CHECK:         %[[BOFF:.*]] = llvm.extractvalue %[[B]][0]
// CHECK:         %[[ONE:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    %[[BSB:.*]] = yul.mul %[[S]], %[[ONE]]
// CHECK-NEXT:    %[[BNOFF:.*]] = yul.add %[[BOFF]], %[[BSB]]
// CHECK-NEXT:    %[[BNLEN:.*]] = yul.sub %[[E]], %[[S]]
// CHECK:         %[[BR0:.*]] = llvm.insertvalue %[[BNOFF]], %{{.*}}[0]
// CHECK:         %[[BS:.*]] = llvm.insertvalue %[[BNLEN]], %[[BR0]][1]
// CHECK:         yul.func_return %[[AS]], %[[BS]]

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @slice(%a: !sol.array<? x ui256, CallData>, %b: !sol.string<CallData>, %s: ui256, %e: ui256) -> (!sol.array<? x ui256, CallData>, !sol.string<CallData>) {
    %0 = sol.slice %a[%s : %e] : !sol.array<? x ui256, CallData>, ui256, ui256 -> !sol.array<? x ui256, CallData>
    %1 = sol.slice %b[%s : %e] : !sol.string<CallData>, ui256, ui256 -> !sol.string<CallData>
    sol.return %0, %1 : !sol.array<? x ui256, CallData>, !sol.string<CallData>
  }
}
