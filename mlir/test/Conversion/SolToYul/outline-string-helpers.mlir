// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck %s

// Every string or bytes assignment into storage is outlined once per source
// location as `__sol.copy_string.<src>.storage`; a calldata source is one
// struct argument. Each of them, and `delete` of a storage string, zeroes
// the shrunk tail through the shared `clear_storage_string_tail`. Reading a
// storage string into memory copies its bytes through
// `copy_string_bytes.storage.memory`, and an allocating read of a storage
// string into memory is the shared `clone_string.storage.memory` around it.
// A `push` or `pop` on a storage string is the shared `push_storage_string`,
// `push_storage_string.zero` or `pop_storage_string`. Every length read of a
// storage string,
// in the helpers and at the sites that stay inline, goes through the shared
// `storage_string_length`, which holds the one copy of the encoding panic.
//
// The size-less `sol.malloc` is written in the generic form because its
// custom printer does not round-trip.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
#View = #sol<StateMutability View>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C_54 {
    sol.state_var @s0_2 slot 0 offset 0 : !sol.string<Storage>
    sol.state_var @s1_4 slot 1 offset 0 : !sol.string<Storage>
    sol.state_var @s2_6 slot 2 offset 0 : !sol.string<Storage>
    sol.func @C_54() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @m2s_20(%arg0: !sol.string<Memory>) attributes {id = 20 : i64, orig_fn_type = (!sol.string<Memory>) -> (), selector = 1365795410 : i32, state_mutability = #NonPayable} {
      %0 = sol.alloca : !sol.ptr<!sol.string<Memory>, Stack>
      sol.store %arg0, %0 : !sol.string<Memory>, !sol.ptr<!sol.string<Memory>, Stack>
      %1 = sol.load %0 : !sol.ptr<!sol.string<Memory>, Stack>, !sol.string<Memory>
      %2 = sol.addr_of @s0_2 : !sol.string<Storage>
      sol.copy %1, %2 : !sol.string<Memory>, !sol.string<Storage>
      %3 = sol.load %0 : !sol.ptr<!sol.string<Memory>, Stack>, !sol.string<Memory>
      %4 = sol.addr_of @s1_4 : !sol.string<Storage>
      sol.copy %3, %4 : !sol.string<Memory>, !sol.string<Storage>
      sol.return
    }
    sol.func @cd2s_30(%arg0: !sol.string<CallData>) attributes {id = 30 : i64, orig_fn_type = (!sol.string<CallData>) -> (), selector = 1308247810 : i32, state_mutability = #NonPayable} {
      %0 = sol.alloca : !sol.ptr<!sol.string<CallData>, Stack>
      sol.store %arg0, %0 : !sol.string<CallData>, !sol.ptr<!sol.string<CallData>, Stack>
      %1 = sol.load %0 : !sol.ptr<!sol.string<CallData>, Stack>, !sol.string<CallData>
      %2 = sol.addr_of @s0_2 : !sol.string<Storage>
      sol.copy %1, %2 : !sol.string<CallData>, !sol.string<Storage>
      sol.return
    }
    sol.func @s2s_38() attributes {id = 38 : i64, orig_fn_type = () -> (), selector = 1708252964 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0_2 : !sol.string<Storage>
      %1 = sol.addr_of @s1_4 : !sol.string<Storage>
      sol.copy %0, %1 : !sol.string<Storage>, !sol.string<Storage>
      sol.return
    }
    sol.func @del_45() attributes {id = 45 : i64, orig_fn_type = () -> (), selector = -1235709955 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s2_6 : !sol.string<Storage>
      sol.delete %0 : !sol.string<Storage>
      sol.return
    }
    sol.func @s2m_53() -> !sol.string<Memory> attributes {id = 53 : i64, orig_fn_type = () -> !sol.string<Memory>, selector = -530736148 : i32, state_mutability = #View} {
      %0 = sol.alloca : !sol.ptr<!sol.string<Memory>, Stack>
      %1 = "sol.malloc"() : () -> !sol.string<Memory>
      sol.store %1, %0 : !sol.string<Memory>, !sol.ptr<!sol.string<Memory>, Stack>
      %2 = sol.addr_of @s0_2 : !sol.string<Storage>
      %3 = sol.data_loc_cast %2 : !sol.string<Storage>, !sol.string<Memory>
      sol.return %3 : !sol.string<Memory>
    }
    sol.func @pv_60(%arg0: !sol.fixedbytes<1>) attributes {id = 60 : i64, orig_fn_type = (!sol.fixedbytes<1>) -> (), selector = -291275623 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0_2 : !sol.string<Storage>
      sol.push_string %0, %arg0 : <Storage>, !sol.fixedbytes<1>
      sol.return
    }
    sol.func @pz_70() attributes {id = 70 : i64, orig_fn_type = () -> (), selector = 1353567867 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0_2 : !sol.string<Storage>
      %1 = sol.push %0 : !sol.string<Storage> -> !sol.ptr<!sol.byte, Storage>
      sol.return
    }
    sol.func @pp_80() attributes {id = 80 : i64, orig_fn_type = () -> (), selector = -1858961722 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0_2 : !sol.string<Storage>
      sol.pop %0 : !sol.string<Storage>
      sol.return
    }
  } {kind = #Contract}
}

// CHECK-LABEL: yul.object @C_54_deployed
// CHECK-LABEL:   yul.func @__sol.pop_storage_string : (i256) -> ()
// CHECK:           yul.func_call @__sol.storage_string_length(
// CHECK:           yul.sstore
// CHECK-LABEL:   yul.func @__sol.push_storage_string.zero : (i256) -> !llvm.struct<(i256, i256)>
// CHECK:           yul.func_call @__sol.storage_string_length(
// CHECK:           yul.sstore
// CHECK-LABEL:   yul.func @__sol.push_storage_string : (i256, i256) -> ()
// CHECK:           yul.func_call @__sol.storage_string_length(
// CHECK:           yul.sstore
// CHECK-LABEL:   yul.func @__sol.copy_string_bytes.storage.memory : (i256, i256, i256, i256) -> ()
// CHECK-LABEL:   yul.func @__sol.clone_string.storage.memory : (i256) -> i256
// CHECK:           yul.func_call @__sol.storage_string_length(
// CHECK:           yul.func_call @__sol.copy_string_bytes.storage.memory(
// CHECK:           yul.func_return
// CHECK-LABEL:   yul.func @__sol.copy_string.storage.storage : (i256, i256) -> ()
// CHECK-COUNT-2:   yul.func_call @__sol.storage_string_length(
// CHECK:           yul.func_call @__sol.clear_storage_string_tail(
// CHECK-LABEL:   yul.func @__sol.copy_string.calldata.storage : (!llvm.struct<(i256, i256)>, i256) -> ()
// CHECK:           llvm.extractvalue %arg0[1]
// CHECK:           yul.func_call @__sol.storage_string_length(
// CHECK:           yul.func_call @__sol.clear_storage_string_tail(
// CHECK-LABEL:   yul.func @__sol.clear_storage_string_tail : (i256, i256, i256) -> ()
// CHECK:           yul.sstore
// CHECK-LABEL:   yul.func @__sol.storage_string_length : (i256) -> i256
// CHECK:           yul.arith_shr %arg0
// CHECK:           yul.constant 127
// CHECK:           yul.revert
// CHECK:           yul.func_return
// CHECK-LABEL:   yul.func @__sol.copy_string.memory.storage : (i256, i256) -> ()
// CHECK:           yul.func_call @__sol.storage_string_length(
// CHECK:           yul.func_call @__sol.clear_storage_string_tail(
// CHECK-LABEL:   yul.func @pp_80
// CHECK:           yul.func_call @__sol.pop_storage_string(
// CHECK-LABEL:   yul.func @pz_70
// CHECK:           yul.func_call @__sol.push_storage_string.zero(
// CHECK-LABEL:   yul.func @pv_60
// CHECK:           yul.func_call @__sol.push_storage_string(
// CHECK-LABEL:   yul.func @s2m_53
// CHECK:           yul.func_call @__sol.clone_string.storage.memory(
// CHECK-LABEL:   yul.func @del_45
// CHECK:           yul.func_call @__sol.storage_string_length(
// CHECK:           yul.func_call @__sol.clear_storage_string_tail(
// CHECK-LABEL:   yul.func @s2s_38
// CHECK:           yul.func_call @__sol.copy_string.storage.storage(
// CHECK-LABEL:   yul.func @cd2s_30
// CHECK:           yul.func_call @__sol.copy_string.calldata.storage(%{{.*}}, %{{.*}}) : (!llvm.struct<(i256, i256)>, i256) -> ()
// CHECK-LABEL:   yul.func @m2s_20
// CHECK-NOT:       yul.sstore
// CHECK:           yul.func_call @__sol.copy_string.memory.storage(
// CHECK:           yul.func_call @__sol.copy_string.memory.storage(
// CHECK-NOT:       yul.sstore
// CHECK:           yul.func_return
