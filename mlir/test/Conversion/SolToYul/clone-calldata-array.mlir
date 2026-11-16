// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A calldata array cloned into memory follows the legacy code generator. An
// array of scalars is one raw calldatacopy, so an enum out of range or a
// dirty byte is copied as it is. An array of static rows copies each row the
// same way. An array of dynamically encoded elements is ABI-decoded, and an
// array of structs clones each struct, both of which revert on a dirty value.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @rows(%arg0: !sol.array<? x !sol.array<2 x ui8, CallData>, CallData>) -> !sol.array<? x !sol.array<2 x ui8, Memory>, Memory> attributes {orig_fn_type = (!sol.array<? x !sol.array<2 x ui8, CallData>, CallData>) -> !sol.array<? x !sol.array<2 x ui8, Memory>, Memory>, selector = 1 : i32, state_mutability = #Pure} {
      %0 = sol.data_loc_cast %arg0 : !sol.array<? x !sol.array<2 x ui8, CallData>, CallData>, !sol.array<? x !sol.array<2 x ui8, Memory>, Memory>
      sol.return %0 : !sol.array<? x !sol.array<2 x ui8, Memory>, Memory>
    }
    sol.func @enums(%arg0: !sol.array<? x !sol.enum<3>, CallData>) -> !sol.array<? x !sol.enum<3>, Memory> attributes {orig_fn_type = (!sol.array<? x !sol.enum<3>, CallData>) -> !sol.array<? x !sol.enum<3>, Memory>, selector = 2 : i32, state_mutability = #Pure} {
      %0 = sol.data_loc_cast %arg0 : !sol.array<? x !sol.enum<3>, CallData>, !sol.array<? x !sol.enum<3>, Memory>
      sol.return %0 : !sol.array<? x !sol.enum<3>, Memory>
    }
    sol.func @nested(%arg0: !sol.array<? x !sol.array<? x ui8, CallData>, CallData>) -> !sol.array<? x !sol.array<? x ui8, Memory>, Memory> attributes {orig_fn_type = (!sol.array<? x !sol.array<? x ui8, CallData>, CallData>) -> !sol.array<? x !sol.array<? x ui8, Memory>, Memory>, selector = 3 : i32, state_mutability = #Pure} {
      %0 = sol.data_loc_cast %arg0 : !sol.array<? x !sol.array<? x ui8, CallData>, CallData>, !sol.array<? x !sol.array<? x ui8, Memory>, Memory>
      sol.return %0 : !sol.array<? x !sol.array<? x ui8, Memory>, Memory>
    }
    sol.func @structs(%arg0: !sol.array<? x !sol.struct<(ui8), CallData>, CallData>) -> !sol.array<? x !sol.struct<(ui8), Memory>, Memory> attributes {orig_fn_type = (!sol.array<? x !sol.struct<(ui8), CallData>, CallData>) -> !sol.array<? x !sol.struct<(ui8), Memory>, Memory>, selector = 4 : i32, state_mutability = #Pure} {
      %0 = sol.data_loc_cast %arg0 : !sol.array<? x !sol.struct<(ui8), CallData>, CallData>, !sol.array<? x !sol.struct<(ui8), Memory>, Memory>
      sol.return %0 : !sol.array<? x !sol.struct<(ui8), Memory>, Memory>
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed

// A struct element is cloned member by member, and a dirty member reverts.
// CHECK-LABEL:   yul.func @__sol.clone_struct.calldata.memory.struct$_$_ui8_$_$_CallData_$
// CHECK:           %[[V:.*]] = yul.calldataload %arg0
// CHECK-NEXT:      %[[M:.*]] = yul.constant 255
// CHECK-NEXT:      %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK-NEXT:      %[[BAD:.*]] = yul.cmp ne, %[[V]], %[[C]]
// CHECK-NEXT:      yul.if %[[BAD]] {
// CHECK:             yul.revert
// CHECK:           yul.mstore %{{.*}}, %[[C]]

// CHECK-LABEL:   yul.func @__sol.clone_array.calldata.memory.array$_dyn_struct$_$_ui8_$_$_CallData_$_$_CallData_$
// CHECK:           yul.for
// CHECK:             yul.func_call @__sol.clone_struct.calldata.memory.struct$_$_ui8_$_$_CallData_$

// The decoder of a nested dynamic array decodes each inner array, and that
// decoder validates every element.
// CHECK-LABEL:   yul.func @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.calldataload
// CHECK-NEXT:        %[[M:.*]] = yul.constant 255
// CHECK-NEXT:        %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK-NEXT:        %[[BAD:.*]] = yul.cmp ne, %[[V]], %[[C]]
// CHECK-NEXT:        yul.if %[[BAD]] {
// CHECK:               yul.revert
// CHECK:             yul.mstore %{{.*}}, %[[C]]

// CHECK-LABEL:   yul.func @__sol.abi_decode.calldata.memory.array$_dyn_array$_dyn_ui8_$_Memory_$_$_Memory_$
// CHECK:           yul.for
// CHECK:             yul.func_call @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$

// Each static row is one calldatacopy into a fresh allocation.
// CHECK-LABEL:   yul.func @__sol.clone_array.calldata.memory.array$_dyn_array$_2_ui8_$_CallData_$_$_CallData_$
// CHECK:           yul.for
// CHECK:             %[[ROW:.*]] = yul.mload %c64
// CHECK-NOT:         yul.calldataload
// CHECK:             %[[SIZE:.*]] = yul.mul %c2_i256{{.*}}, %c32_i256
// CHECK-NEXT:        yul.calldatacopy %[[ROW]], %{{.*}}, %[[SIZE]]
// CHECK-NEXT:        yul.mstore %{{.*}}, %[[ROW]]

// CHECK-LABEL:   yul.func @structs
// CHECK:           yul.func_call @__sol.clone_array.calldata.memory.array$_dyn_struct$_$_ui8_$_$_CallData_$_$_CallData_$

// CHECK-LABEL:   yul.func @nested
// CHECK:           yul.func_call @__sol.abi_decode.calldata.memory.array$_dyn_array$_dyn_ui8_$_Memory_$_$_Memory_$

// An enum array is copied raw: no range check and no panic.
// CHECK-LABEL:   yul.func @enums
// CHECK-NOT:       yul.func_call @__sol.clone_array
// CHECK-NOT:       yul.calldataload
// CHECK:           yul.calldatacopy
// CHECK-NOT:       yul.func_call @__sol.panic
// CHECK:           yul.func_return

// CHECK-LABEL:   yul.func @rows
// CHECK:           yul.func_call @__sol.clone_array.calldata.memory.array$_dyn_array$_2_ui8_$_CallData_$_$_CallData_$
