// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Struct copies are always outlined, since an identified struct may be
// self-referential: `copy_struct.<src>.storage.<src ty>.<dst ty>` for a copy
// into storage and `clone_struct.<src>.memory.<ty>` for a clone into memory.
// Their aggregate members go through the array helpers, and the ABI helpers
// of the dispatcher nest the per-type decoders and encoders the same way.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
#View = #sol<StateMutability View>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @s0 slot 0 offset 0 : !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
    sol.state_var @s1 slot 2 offset 0 : !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
    sol.func @m2s(%arg0: !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>) attributes {orig_fn_type = (!sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>) -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0 : !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
      sol.copy %arg0, %0 : !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
      %1 = sol.addr_of @s1 : !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
      sol.copy %arg0, %1 : !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
      sol.return
    }
    sol.func @s2m() -> !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory> attributes {orig_fn_type = () -> !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, selector = 2 : i32, state_mutability = #View} {
      %0 = sol.addr_of @s0 : !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
      %1 = sol.data_loc_cast %0 : !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>, !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>
      sol.return %1 : !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed
// CHECK-LABEL:   yul.func @__sol.abi_encode_array.memory.padded.tail.array$_dyn_ui8_$_Memory_$ : (i256, i256, i256) -> i256
// CHECK:           yul.for
// CHECK-LABEL:   yul.func @__sol.abi_encode_tuple.padded.tail.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.func_call @__sol.abi_encode_array.memory.padded.tail.array$_dyn_ui8_$_Memory_$(
// CHECK-LABEL:   yul.func @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.for
// CHECK-LABEL:   yul.func @__sol.abi_decode.calldata.memory.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.func_call @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$(
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.func_call @__sol.abi_decode.calldata.memory.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$(
// CHECK-LABEL:   yul.func @__sol.clone_array.storage.memory.array$_dyn_ui8_$_Storage_$ : (i256) -> i256
// CHECK-LABEL:   yul.func @__sol.clone_struct.storage.memory.struct$_$_ui256_$_array$_dyn_ui8_$_Storage_$_$_$_Storage_$ : (i256) -> i256
// CHECK:           yul.func_call @__sol.clone_array.storage.memory.array$_dyn_ui8_$_Storage_$(
// CHECK-LABEL:   yul.func @__sol.copy_array.memory.storage.array$_dyn_ui8_$_Memory_$.array$_dyn_ui8_$_Storage_$ : (i256, i256) -> ()
// CHECK-LABEL:   yul.func @__sol.copy_struct.memory.storage.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$.struct$_$_ui256_$_array$_dyn_ui8_$_Storage_$_$_$_Storage_$ : (i256, i256) -> ()
// CHECK:           yul.func_call @__sol.copy_array.memory.storage.array$_dyn_ui8_$_Memory_$.array$_dyn_ui8_$_Storage_$(
// CHECK-LABEL:   yul.func @s2m
// CHECK:           yul.func_call @__sol.clone_struct.storage.memory.struct$_$_ui256_$_array$_dyn_ui8_$_Storage_$_$_$_Storage_$(
// CHECK-LABEL:   yul.func @m2s
// CHECK:           yul.func_call @__sol.copy_struct.memory.storage.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$.struct$_$_ui256_$_array$_dyn_ui8_$_Storage_$_$_$_Storage_$(
// CHECK:           yul.func_call @__sol.copy_struct.memory.storage.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$.struct$_$_ui256_$_array$_dyn_ui8_$_Storage_$_$_$_Storage_$(
