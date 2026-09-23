// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck %s

// Struct copies are always outlined, since an identified struct may be
// self-referential: `copy_struct.<src>.storage.<src ty>.<dst ty>` for a copy into storage
// and `clone_struct.<src>.memory.<ty>` for a clone into memory. Their
// aggregate members go through the array helpers, and the ABI helpers of
// the dispatcher nest the per-type decoders and encoders the same way.
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
  sol.contract @C_37 {
    sol.state_var @s0_9 slot 0 offset 0 : !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
    sol.state_var @s1_12 slot 2 offset 0 : !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
    sol.func @C_37() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @m2s_27(%arg0: !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>) attributes {id = 27 : i64, orig_fn_type = (!sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>) -> (), selector = -1354262773 : i32, state_mutability = #NonPayable} {
      %0 = sol.alloca : !sol.ptr<!sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, Stack>
      sol.store %arg0, %0 : !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, !sol.ptr<!sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, Stack>
      %1 = sol.load %0 : !sol.ptr<!sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, Stack>, !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>
      %2 = sol.addr_of @s0_9 : !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
      sol.copy %1, %2 : !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
      %3 = sol.load %0 : !sol.ptr<!sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, Stack>, !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>
      %4 = sol.addr_of @s1_12 : !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
      sol.copy %3, %4 : !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
      sol.return
    }
    sol.func @s2m_36() -> !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory> attributes {id = 36 : i64, orig_fn_type = () -> !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, selector = -530736148 : i32, state_mutability = #View} {
      %0 = sol.alloca : !sol.ptr<!sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, Stack>
      %1 = "sol.malloc"() <{zero_init}> : () -> !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>
      sol.store %1, %0 : !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, !sol.ptr<!sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>, Stack>
      %2 = sol.addr_of @s0_9 : !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>
      %3 = sol.data_loc_cast %2 : !sol.struct<(ui256, !sol.array<? x ui8, Storage>), Storage>, !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>
      sol.return %3 : !sol.struct<(ui256, !sol.array<? x ui8, Memory>), Memory>
    }
  } {kind = #Contract}
}

// CHECK-LABEL: yul.object @C_37_deployed
// CHECK-LABEL:   yul.func @__sol.clone_array.storage.memory.array$_dyn_ui8_$_Storage_$ : (i256) -> i256
// CHECK-LABEL:   yul.func @__sol.clone_struct.storage.memory.struct$_$_ui256_$_array$_dyn_ui8_$_Storage_$_$_$_Storage_$ : (i256) -> i256
// CHECK:           yul.func_call @__sol.clone_array.storage.memory.array$_dyn_ui8_$_Storage_$(
// CHECK-LABEL:   yul.func @__sol.copy_array.memory.storage.array$_dyn_ui8_$_Memory_$.array$_dyn_ui8_$_Storage_$ : (i256, i256) -> ()
// CHECK-LABEL:   yul.func @__sol.copy_struct.memory.storage.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$.struct$_$_ui256_$_array$_dyn_ui8_$_Storage_$_$_$_Storage_$ : (i256, i256) -> ()
// CHECK:           yul.func_call @__sol.copy_array.memory.storage.array$_dyn_ui8_$_Memory_$.array$_dyn_ui8_$_Storage_$(
// CHECK-LABEL:   yul.func @s2m_36
// CHECK:           yul.func_call @__sol.clone_struct.storage.memory.struct$_$_ui256_$_array$_dyn_ui8_$_Storage_$_$_$_Storage_$(
// CHECK-LABEL:   yul.func @m2s_27
// CHECK:           yul.func_call @__sol.copy_struct.memory.storage.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$.struct$_$_ui256_$_array$_dyn_ui8_$_Storage_$_$_$_Storage_$(
// CHECK:           yul.func_call @__sol.copy_struct.memory.storage.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$.struct$_$_ui256_$_array$_dyn_ui8_$_Storage_$_$_$_Storage_$(
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.func_call @__sol.abi_decode.calldata.memory.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$(
// CHECK-LABEL:   yul.func @__sol.abi_decode.calldata.memory.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.func_call @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$(
// CHECK-LABEL:   yul.func @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.for
// CHECK-LABEL:   yul.func @__sol.abi_encode_tuple.padded.tail.struct$_$_ui256_$_array$_dyn_ui8_$_Memory_$_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.func_call @__sol.abi_encode_array.memory.padded.tail.array$_dyn_ui8_$_Memory_$(
// CHECK-LABEL:   yul.func @__sol.abi_encode_array.memory.padded.tail.array$_dyn_ui8_$_Memory_$ : (i256, i256, i256) -> i256
// CHECK:           yul.for
