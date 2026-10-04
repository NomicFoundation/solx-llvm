// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The fixed array member is held by pointer in the struct's second word.
// CHECK-LABEL: yul.func @ui : (i256) -> (i256, i256)
// CHECK:         %[[UIP:.*]] = yul.add %arg0, %{{.*}}
// CHECK:         %[[UI:.*]] = yul.mload %[[UIP]]
// CHECK:         %[[C32:.*]] = yul.constant 32
// CHECK:         %[[ARRP:.*]] = yul.add %arg0, %[[C32]]
// CHECK:         %[[ARR:.*]] = yul.mload %[[ARRP]]
// CHECK:         %[[C64:.*]] = yul.constant 64
// CHECK:         %[[ELTP:.*]] = yul.add %[[ARR]], %[[C64]]
// CHECK:         %[[ELT:.*]] = yul.mload %[[ELTP]]
// CHECK:         yul.func_return %[[UI]], %[[ELT]] : i256, i256

// A non-zeroed struct skips the member init and takes the stored values.
// CHECK-LABEL: yul.func @literal_bytes : () -> ()
// CHECK:         %[[C96:.*]] = yul.constant 96
// CHECK:         %[[S:.*]] = yul.mload
// CHECK-NOT:     yul.mstore %{{.*}}, %[[C96]]
// CHECK:         %[[X:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    yul.mstore %{{.*}}, %[[X]]
// CHECK:         %[[BP:.*]] = yul.add %[[S]], %c32_i256
// CHECK:         %[[STR:.*]] = yul.mload
// CHECK:         %[[LEN:.*]] = yul.constant 5{{$}}
// CHECK-NEXT:    yul.mstore %[[STR]], %[[LEN]]
// CHECK:         yul.constant 47219736118171679016481614208494153725245902603978864281390662590579859259392
// CHECK:         yul.mstore %[[BP]], %[[STR]]
// CHECK:         %[[YP:.*]] = yul.add %[[S]], %{{.*}}
// CHECK-NEXT:    %[[Y:.*]] = yul.constant 2{{$}}
// CHECK-NEXT:    yul.mstore %[[YP]], %[[Y]]

// CHECK-LABEL: yul.func @cd_dyn_member : (i256) -> i256
// CHECK:         %[[OFFP:.*]] = yul.add %arg0, %{{.*}}
// CHECK:         %[[OFF:.*]] = yul.calldataload %[[OFFP]]
// CHECK:         %[[ARR:.*]] = yul.add %arg0, %[[OFF]]
// CHECK:         yul.calldataload %[[ARR]]
// CHECK:         yul.constant 50
// CHECK:         %[[V:.*]] = yul.calldataload
// CHECK:         %[[MASK:.*]] = yul.constant 65535
// CHECK:         %[[R:.*]] = yul.and %[[V]], %[[MASK]]
// CHECK:         %[[DIRTY:.*]] = yul.cmp ne, %[[V]], %[[R]]
// CHECK:         yul.if %[[DIRTY]] {
// CHECK:           yul.revert
// CHECK:         yul.func_return %[[R]] : i256

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @ui(%arg0: !sol.struct<(ui256, !sol.array<3 x ui256, Memory>), Memory>) -> (ui256, ui256) {
    %c0_ui64 = sol.constant 0 : ui64
    %0 = sol.gep %arg0, %c0_ui64 : !sol.struct<(ui256, !sol.array<3 x ui256, Memory>), Memory>, ui64, !sol.ptr<ui256, Memory>
    %1 = sol.load %0 : !sol.ptr<ui256, Memory>, ui256
    %c1_ui64 = sol.constant 1 : ui64
    %2 = sol.gep %arg0, %c1_ui64 : !sol.struct<(ui256, !sol.array<3 x ui256, Memory>), Memory>, ui64, !sol.ptr<!sol.array<3 x ui256, Memory>, Memory>
    %3 = sol.load %2 : !sol.ptr<!sol.array<3 x ui256, Memory>, Memory>, !sol.array<3 x ui256, Memory>
    %c2_ui8 = sol.constant 2 : ui8
    %4 = sol.gep %3, %c2_ui8 : !sol.array<3 x ui256, Memory>, ui8, !sol.ptr<ui256, Memory>
    %5 = sol.load %4 : !sol.ptr<ui256, Memory>, ui256
    sol.return %1, %5 : ui256, ui256
  }
  sol.func @literal_bytes() {
    %0 = sol.malloc : !sol.struct<(ui256, !sol.string<Memory>, ui256), Memory>
    %c0_ui64 = sol.constant 0 : ui64
    %1 = sol.gep %0, %c0_ui64 : !sol.struct<(ui256, !sol.string<Memory>, ui256), Memory>, ui64, !sol.ptr<ui256, Memory>
    %c1_ui256 = sol.constant 1 : ui256
    sol.store %c1_ui256, %1 : ui256, !sol.ptr<ui256, Memory>
    %c1_ui64 = sol.constant 1 : ui64
    %2 = sol.gep %0, %c1_ui64 : !sol.struct<(ui256, !sol.string<Memory>, ui256), Memory>, ui64, !sol.ptr<!sol.string<Memory>, Memory>
    %3 = sol.string_lit "hello" -> !sol.string<Memory>
    sol.store %3, %2 : !sol.string<Memory>, !sol.ptr<!sol.string<Memory>, Memory>
    %c2_ui64 = sol.constant 2 : ui64
    %4 = sol.gep %0, %c2_ui64 : !sol.struct<(ui256, !sol.string<Memory>, ui256), Memory>, ui64, !sol.ptr<ui256, Memory>
    %c2_ui256 = sol.constant 2 : ui256
    sol.store %c2_ui256, %4 : ui256, !sol.ptr<ui256, Memory>
    sol.return
  }
  sol.func @cd_dyn_member(%arg0: !sol.struct<(!sol.array<? x ui16, CallData>), CallData>) -> ui16 {
    %c0_ui64 = sol.constant 0 : ui64
    %0 = sol.gep %arg0, %c0_ui64 : !sol.struct<(!sol.array<? x ui16, CallData>), CallData>, ui64, !sol.array<? x ui16, CallData>
    %c0_ui8 = sol.constant 0 : ui8
    %1 = sol.gep %0, %c0_ui8 : !sol.array<? x ui16, CallData>, ui8, !sol.ptr<ui16, CallData>
    %2 = sol.load %1 : !sol.ptr<ui16, CallData>, ui16
    sol.return %2 : ui16
  }
}
