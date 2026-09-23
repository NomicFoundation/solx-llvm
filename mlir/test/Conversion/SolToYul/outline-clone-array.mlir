// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck %s

// An allocating array copy into memory that needs a loop is outlined once
// per type as `__sol.clone_array.<src>.memory.<ty>`: every storage source,
// and a calldata source whose elements are not 32-byte words, which is
// passed as one fat-pointer struct. A calldata array of words is a single
// calldatacopy and stays inline.
//
// The size-less `sol.malloc` is written in the generic form because its
// custom printer does not round-trip.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
#View = #sol<StateMutability View>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C_49 {
    sol.state_var @n_3 slot 0 offset 0 : !sol.array<? x ui8, Storage>
    sol.state_var @w_6 slot 1 offset 0 : !sol.array<? x ui256, Storage>
    sol.func @C_49() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @n2m_15() -> !sol.array<? x ui8, Memory> attributes {id = 15 : i64, orig_fn_type = () -> !sol.array<? x ui8, Memory>, selector = 507661058 : i32, state_mutability = #View} {
      %0 = sol.alloca : !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %1 = "sol.malloc"() <{zero_init}> : () -> !sol.array<? x ui8, Memory>
      sol.store %1, %0 : !sol.array<? x ui8, Memory>, !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %2 = sol.addr_of @n_3 : !sol.array<? x ui8, Storage>
      %3 = sol.data_loc_cast %2 : !sol.array<? x ui8, Storage>, !sol.array<? x ui8, Memory>
      sol.return %3 : !sol.array<? x ui8, Memory>
    }
    sol.func @w2m_24() -> !sol.array<? x ui256, Memory> attributes {id = 24 : i64, orig_fn_type = () -> !sol.array<? x ui256, Memory>, selector = -1906823883 : i32, state_mutability = #View} {
      %0 = sol.alloca : !sol.ptr<!sol.array<? x ui256, Memory>, Stack>
      %1 = "sol.malloc"() <{zero_init}> : () -> !sol.array<? x ui256, Memory>
      sol.store %1, %0 : !sol.array<? x ui256, Memory>, !sol.ptr<!sol.array<? x ui256, Memory>, Stack>
      %2 = sol.addr_of @w_6 : !sol.array<? x ui256, Storage>
      %3 = sol.data_loc_cast %2 : !sol.array<? x ui256, Storage>, !sol.array<? x ui256, Memory>
      sol.return %3 : !sol.array<? x ui256, Memory>
    }
    sol.func @cdn_36(%arg0: !sol.array<? x ui8, CallData>) -> !sol.array<? x ui8, Memory> attributes {id = 36 : i64, orig_fn_type = (!sol.array<? x ui8, CallData>) -> !sol.array<? x ui8, Memory>, selector = -1585227628 : i32, state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<!sol.array<? x ui8, CallData>, Stack>
      sol.store %arg0, %0 : !sol.array<? x ui8, CallData>, !sol.ptr<!sol.array<? x ui8, CallData>, Stack>
      %1 = sol.alloca : !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %2 = "sol.malloc"() <{zero_init}> : () -> !sol.array<? x ui8, Memory>
      sol.store %2, %1 : !sol.array<? x ui8, Memory>, !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %3 = sol.load %0 : !sol.ptr<!sol.array<? x ui8, CallData>, Stack>, !sol.array<? x ui8, CallData>
      %4 = sol.data_loc_cast %3 : !sol.array<? x ui8, CallData>, !sol.array<? x ui8, Memory>
      sol.return %4 : !sol.array<? x ui8, Memory>
    }
    sol.func @cdw_48(%arg0: !sol.array<? x ui256, CallData>) -> !sol.array<? x ui256, Memory> attributes {id = 48 : i64, orig_fn_type = (!sol.array<? x ui256, CallData>) -> !sol.array<? x ui256, Memory>, selector = -1216705663 : i32, state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<!sol.array<? x ui256, CallData>, Stack>
      sol.store %arg0, %0 : !sol.array<? x ui256, CallData>, !sol.ptr<!sol.array<? x ui256, CallData>, Stack>
      %1 = sol.alloca : !sol.ptr<!sol.array<? x ui256, Memory>, Stack>
      %2 = "sol.malloc"() <{zero_init}> : () -> !sol.array<? x ui256, Memory>
      sol.store %2, %1 : !sol.array<? x ui256, Memory>, !sol.ptr<!sol.array<? x ui256, Memory>, Stack>
      %3 = sol.load %0 : !sol.ptr<!sol.array<? x ui256, CallData>, Stack>, !sol.array<? x ui256, CallData>
      %4 = sol.data_loc_cast %3 : !sol.array<? x ui256, CallData>, !sol.array<? x ui256, Memory>
      sol.return %4 : !sol.array<? x ui256, Memory>
    }
  } {kind = #Contract}
}

// CHECK-LABEL: yul.object @C_49_deployed
// CHECK-DAG:     yul.func @__sol.clone_array.calldata.memory.array$_dyn_ui8_$_CallData_$ : (!llvm.struct<(i256, i256)>) -> i256
// CHECK-DAG:     yul.func @__sol.clone_array.storage.memory.array$_dyn_ui256_$_Storage_$ : (i256) -> i256
// CHECK-DAG:     yul.func @__sol.clone_array.storage.memory.array$_dyn_ui8_$_Storage_$ : (i256) -> i256
// CHECK-LABEL:   yul.func @cdw_48
// CHECK-NOT:       yul.func_call @__sol.clone_array
// CHECK:           yul.calldatacopy
// CHECK-NOT:       yul.func_call @__sol.clone_array
// CHECK-LABEL:   yul.func @cdn_36
// CHECK:           yul.func_call @__sol.clone_array.calldata.memory.array$_dyn_ui8_$_CallData_$(%{{.*}}) : (!llvm.struct<(i256, i256)>) -> i256
// CHECK-LABEL:   yul.func @w2m_24
// CHECK:           yul.func_call @__sol.clone_array.storage.memory.array$_dyn_ui256_$_Storage_$(
// CHECK-LABEL:   yul.func @n2m_15
// CHECK:           yul.func_call @__sol.clone_array.storage.memory.array$_dyn_ui8_$_Storage_$(
