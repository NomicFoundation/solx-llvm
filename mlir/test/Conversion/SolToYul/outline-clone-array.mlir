// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// An allocating array copy into memory that needs a loop is outlined once
// per type as `__sol.clone_array.<src>.memory.<ty>`: every storage source,
// and a calldata source whose elements are not one bulk copy. A calldata
// array of scalars, narrow or word-sized, is a single calldatacopy and stays
// inline.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
#View = #sol<StateMutability View>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @n slot 0 offset 0 : !sol.array<? x ui8, Storage>
    sol.state_var @w slot 1 offset 0 : !sol.array<? x ui256, Storage>
    sol.func @n2m() -> !sol.array<? x ui8, Memory> attributes {orig_fn_type = () -> !sol.array<? x ui8, Memory>, selector = 1 : i32, state_mutability = #View} {
      %0 = sol.addr_of @n : !sol.array<? x ui8, Storage>
      %1 = sol.data_loc_cast %0 : !sol.array<? x ui8, Storage>, !sol.array<? x ui8, Memory>
      sol.return %1 : !sol.array<? x ui8, Memory>
    }
    sol.func @w2m() -> !sol.array<? x ui256, Memory> attributes {orig_fn_type = () -> !sol.array<? x ui256, Memory>, selector = 2 : i32, state_mutability = #View} {
      %0 = sol.addr_of @w : !sol.array<? x ui256, Storage>
      %1 = sol.data_loc_cast %0 : !sol.array<? x ui256, Storage>, !sol.array<? x ui256, Memory>
      sol.return %1 : !sol.array<? x ui256, Memory>
    }
    sol.func @cdn(%arg0: !sol.array<? x ui8, CallData>) -> !sol.array<? x ui8, Memory> attributes {orig_fn_type = (!sol.array<? x ui8, CallData>) -> !sol.array<? x ui8, Memory>, selector = 3 : i32, state_mutability = #Pure} {
      %0 = sol.data_loc_cast %arg0 : !sol.array<? x ui8, CallData>, !sol.array<? x ui8, Memory>
      sol.return %0 : !sol.array<? x ui8, Memory>
    }
    sol.func @cdw(%arg0: !sol.array<? x ui256, CallData>) -> !sol.array<? x ui256, Memory> attributes {orig_fn_type = (!sol.array<? x ui256, CallData>) -> !sol.array<? x ui256, Memory>, selector = 4 : i32, state_mutability = #Pure} {
      %0 = sol.data_loc_cast %arg0 : !sol.array<? x ui256, CallData>, !sol.array<? x ui256, Memory>
      sol.return %0 : !sol.array<? x ui256, Memory>
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed
// CHECK-NOT:     yul.func @__sol.clone_array.calldata
// CHECK-DAG:     yul.func @__sol.clone_array.storage.memory.array$_dyn_ui256_$_Storage_$ : (i256) -> i256
// CHECK-DAG:     yul.func @__sol.clone_array.storage.memory.array$_dyn_ui8_$_Storage_$ : (i256) -> i256
// CHECK-LABEL:   yul.func @cdw
// CHECK-NOT:       yul.func_call @__sol.clone_array
// CHECK:           yul.calldatacopy
// CHECK-NOT:       yul.func_call @__sol.clone_array
// CHECK-LABEL:   yul.func @cdn
// CHECK-NOT:       yul.func_call @__sol.clone_array
// CHECK:           yul.calldatacopy
// CHECK-NOT:       yul.func_call @__sol.clone_array
// CHECK-LABEL:   yul.func @w2m
// CHECK:           yul.func_call @__sol.clone_array.storage.memory.array$_dyn_ui256_$_Storage_$(
// CHECK-LABEL:   yul.func @n2m
// CHECK:           yul.func_call @__sol.clone_array.storage.memory.array$_dyn_ui8_$_Storage_$(
