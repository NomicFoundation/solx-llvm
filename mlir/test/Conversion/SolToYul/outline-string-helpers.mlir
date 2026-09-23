// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Every string or bytes assignment into storage is outlined once per source
// location as `__sol.copy_string.<src>.storage`. A calldata source is one
// struct argument. Each of them, and `delete` of a storage string, zeroes
// the shrunk tail through the shared `clear_storage_string_tail`. An
// allocating read of a storage string into memory is the shared
// `clone_string.storage.memory` around `copy_string_bytes.storage.memory`.
// A `push` or `pop` on a storage string is the shared `push_storage_string`,
// `push_storage_string.zero` or `pop_storage_string`. Every length read of a
// storage string, in the helpers and at the sites that stay inline, goes
// through the shared `storage_string_length`, which holds the one copy of
// the encoding panic.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
#View = #sol<StateMutability View>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @s0 slot 0 offset 0 : !sol.string<Storage>
    sol.state_var @s1 slot 1 offset 0 : !sol.string<Storage>
    sol.state_var @s2 slot 2 offset 0 : !sol.string<Storage>
    sol.func @m2s(%arg0: !sol.string<Memory>) attributes {orig_fn_type = (!sol.string<Memory>) -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0 : !sol.string<Storage>
      sol.copy %arg0, %0 : !sol.string<Memory>, !sol.string<Storage>
      %1 = sol.addr_of @s1 : !sol.string<Storage>
      sol.copy %arg0, %1 : !sol.string<Memory>, !sol.string<Storage>
      sol.return
    }
    sol.func @cd2s(%arg0: !sol.string<CallData>) attributes {orig_fn_type = (!sol.string<CallData>) -> (), selector = 2 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0 : !sol.string<Storage>
      sol.copy %arg0, %0 : !sol.string<CallData>, !sol.string<Storage>
      sol.return
    }
    sol.func @s2s() attributes {orig_fn_type = () -> (), selector = 3 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0 : !sol.string<Storage>
      %1 = sol.addr_of @s1 : !sol.string<Storage>
      sol.copy %0, %1 : !sol.string<Storage>, !sol.string<Storage>
      sol.return
    }
    sol.func @del() attributes {orig_fn_type = () -> (), selector = 4 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s2 : !sol.string<Storage>
      sol.delete %0 : !sol.string<Storage>
      sol.return
    }
    sol.func @s2m() -> !sol.string<Memory> attributes {orig_fn_type = () -> !sol.string<Memory>, selector = 5 : i32, state_mutability = #View} {
      %0 = sol.addr_of @s0 : !sol.string<Storage>
      %1 = sol.data_loc_cast %0 : !sol.string<Storage>, !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
    sol.func @pv(%arg0: !sol.fixedbytes<1>) attributes {orig_fn_type = (!sol.fixedbytes<1>) -> (), selector = 6 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0 : !sol.string<Storage>
      sol.push_string %0, %arg0 : <Storage>, !sol.fixedbytes<1>
      sol.return
    }
    sol.func @pz() attributes {orig_fn_type = () -> (), selector = 7 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0 : !sol.string<Storage>
      %1 = sol.push %0 : !sol.string<Storage> -> !sol.ptr<!sol.byte, Storage>
      sol.return
    }
    sol.func @pp() attributes {orig_fn_type = () -> (), selector = 8 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0 : !sol.string<Storage>
      sol.pop %0 : !sol.string<Storage>
      sol.return
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed
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
// CHECK:           yul.func_call @__sol.panic(%c34
// CHECK:           yul.func_return
// CHECK-LABEL:   yul.func @__sol.copy_string.memory.storage : (i256, i256) -> ()
// CHECK:           yul.func_call @__sol.storage_string_length(
// CHECK:           yul.func_call @__sol.clear_storage_string_tail(
// CHECK-LABEL:   yul.func @pp
// CHECK:           yul.func_call @__sol.pop_storage_string(
// CHECK-LABEL:   yul.func @pz
// CHECK:           yul.func_call @__sol.push_storage_string.zero(
// CHECK-LABEL:   yul.func @pv
// CHECK:           yul.func_call @__sol.push_storage_string(
// CHECK-LABEL:   yul.func @s2m
// CHECK:           yul.func_call @__sol.clone_string.storage.memory(
// CHECK-LABEL:   yul.func @del
// CHECK:           yul.func_call @__sol.storage_string_length(
// CHECK:           yul.func_call @__sol.clear_storage_string_tail(
// CHECK-LABEL:   yul.func @s2s
// CHECK:           yul.func_call @__sol.copy_string.storage.storage(
// CHECK-LABEL:   yul.func @cd2s
// CHECK:           yul.func_call @__sol.copy_string.calldata.storage(%{{.*}}, %{{.*}}) : (!llvm.struct<(i256, i256)>, i256) -> ()
// CHECK-LABEL:   yul.func @m2s
// CHECK-NOT:       yul.sstore
// CHECK:           yul.func_call @__sol.copy_string.memory.storage(
// CHECK:           yul.func_call @__sol.copy_string.memory.storage(
// CHECK-NOT:       yul.sstore
// CHECK:           yul.func_return
