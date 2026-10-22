// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Big's head is 6 words (fixedArr inline); its memory copy is 5 words. The
// decoders are outlined per parameter tuple and take the calldata head's
// start and end.
// CHECK-LABEL: yul.func @__sol.abi_decode_tuple.calldata.struct$_$_ui256_$_struct$_$_ui256_$_ui256_$_string$_CallData_$_$_array$_2_ui256_$_CallData_$_$_array$_dyn_ui256_$_CallData_$_$_$_CallData_$_$_ui256_$_$_CallData_$ : (i256, i256) -> i256
// CHECK-NEXT:  ^bb0(%[[START:.*]]: i256, %[[END:.*]]: i256):
// CHECK:         %[[OFF:.*]] = yul.calldataload %[[START]]
// CHECK:         %[[HEAD:.*]] = yul.add %[[START]], %[[OFF]]
// CHECK:         %[[C96:.*]] = yul.constant 96
// CHECK:         %[[HEADEND:.*]] = yul.add %[[HEAD]], %[[C96]]
// CHECK:         yul.cmp ugt, %[[HEADEND]], %[[END]]
// CHECK:         yul.func_return %[[HEAD]] : i256

// The memory decoder allocates the 5-word copy, then the string, the two-word
// fixed array and the dynamic array are each one calldatacopy.
// CHECK-LABEL: yul.func @__sol.abi_decode_tuple.calldata.struct$_$_ui256_$_struct$_$_ui256_$_ui256_$_string$_Memory_$_$_array$_2_ui256_$_Memory_$_$_array$_dyn_ui256_$_Memory_$_$_$_Memory_$_$_ui256_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:         yul.constant 96
// CHECK:         yul.constant 96
// CHECK:         %[[NS:.*]] = yul.mload
// CHECK:         yul.constant 192
// CHECK:         yul.constant 160
// CHECK:         yul.calldatacopy
// CHECK:         %[[FIXEDSZ:.*]] = yul.mul %{{.*}}, %{{.*}}
// CHECK-NEXT:    yul.calldatacopy %{{.*}}, %{{.*}}, %[[FIXEDSZ]]
// CHECK:         yul.calldatacopy
// CHECK-NOT:     yul.for
// CHECK:         yul.func_return %[[NS]] : i256

// The dynamic Big member takes one 32-byte offset word in the calldata head.
// CHECK-LABEL: yul.func @cd_nested : (i256) -> i256
// CHECK-NEXT:  ^bb0(%[[S:.*]]: i256):
// CHECK:         %[[C64:.*]] = yul.constant 64
// CHECK:         %[[P2:.*]] = yul.add %[[S]], %[[C64]]
// CHECK:         %[[V2:.*]] = yul.calldataload %[[P2]]
// CHECK:         yul.func_return %[[V2]]

// CHECK:         case 1543776000 {
// CHECK:           %[[NS:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.struct$_$_ui256_$_struct$_$_ui256_$_ui256_$_string$_Memory_$_$_array$_2_ui256_$_Memory_$_$_array$_dyn_ui256_$_Memory_$_$_$_Memory_$_$_ui256_$_$_Memory_$(%{{.*}}, %{{.*}}) : (i256, i256) -> i256
// CHECK:           yul.func_call @mem_nested(%[[NS]]) : (i256) -> ()

// CHECK:         case 2433354261 {
// CHECK:           %[[HEAD:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.struct$_$_ui256_$_struct$_$_ui256_$_ui256_$_string$_CallData_$_$_array$_2_ui256_$_CallData_$_$_array$_dyn_ui256_$_CallData_$_$_$_CallData_$_$_ui256_$_$_CallData_$(%{{.*}}, %{{.*}}) : (i256, i256) -> i256
// CHECK:           yul.func_call @cd_nested(%[[HEAD]]) : (i256) -> i256

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    sol.func @mem_nested(%arg0: !sol.struct<(ui256, !sol.struct<(ui256, ui256, !sol.string<Memory>, !sol.array<2 x ui256, Memory>, !sol.array<? x ui256, Memory>), Memory>, ui256), Memory>) attributes {orig_fn_type = (!sol.struct<(ui256, !sol.struct<(ui256, ui256, !sol.string<Memory>, !sol.array<2 x ui256, Memory>, !sol.array<? x ui256, Memory>), Memory>, ui256), Memory>) -> (), selector = 1543776000 : i32, state_mutability = #Pure} {
      sol.return
    }
    sol.func @cd_nested(%arg0: !sol.struct<(ui256, !sol.struct<(ui256, ui256, !sol.string<CallData>, !sol.array<2 x ui256, CallData>, !sol.array<? x ui256, CallData>), CallData>, ui256), CallData>) -> ui256 attributes {orig_fn_type = (!sol.struct<(ui256, !sol.struct<(ui256, ui256, !sol.string<CallData>, !sol.array<2 x ui256, CallData>, !sol.array<? x ui256, CallData>), CallData>, ui256), CallData>) -> ui256, selector = -1861613035 : i32, state_mutability = #Pure} {
      %c2_ui64 = sol.constant 2 : ui64
      %0 = sol.gep %arg0, %c2_ui64 : !sol.struct<(ui256, !sol.struct<(ui256, ui256, !sol.string<CallData>, !sol.array<2 x ui256, CallData>, !sol.array<? x ui256, CallData>), CallData>, ui256), CallData>, ui64, !sol.ptr<ui256, CallData>
      %1 = sol.load %0 : !sol.ptr<ui256, CallData>, ui256
      sol.return %1 : ui256
    }
  } {kind = #Contract, runtime}
}
