// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The tuple helpers are keyed by source and mode: `abi.decode` of a memory
// `bytes` gets the `.memory.` decoder of its tuple and `abi.encodePacked`
// the `.packed.inplace.` encoder, both distinct from the dispatcher's
// `.calldata.` decoders and `.padded.tail.` encoders of the same types. The
// per-type array helpers nest inside them with the same keys.
//
// The selector-less `sol.encode` is written in the generic form because its
// custom printer does not round-trip.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @p(%arg0: !sol.array<? x ui8, Memory>, %arg1: ui256) -> !sol.string<Memory> attributes {orig_fn_type = (!sol.array<? x ui8, Memory>, ui256) -> !sol.string<Memory>, selector = 1 : i32, state_mutability = #Pure} {
      %0 = "sol.encode"(%arg0, %arg1) <{operandSegmentSizes = array<i32: 2, 0>, packed}> : (!sol.array<? x ui8, Memory>, ui256) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
    sol.func @q(%arg0: !sol.string<Memory>) -> (ui256, !sol.array<? x ui8, Memory>) attributes {orig_fn_type = (!sol.string<Memory>) -> (ui256, !sol.array<? x ui8, Memory>), selector = 2 : i32, state_mutability = #Pure} {
      %0:2 = sol.decode %arg0 : !sol.string<Memory> -> ui256, !sol.array<? x ui8, Memory>
      sol.return %0#0, %0#1 : ui256, !sol.array<? x ui8, Memory>
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed
// The dispatcher's own coders of the same types are separate helpers.
// CHECK-DAG:     yul.func @__sol.abi_decode_tuple.calldata.array$_dyn_ui8_$_Memory_$.ui256 : (i256, i256) -> (i256, i256)
// CHECK-DAG:     yul.func @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
// CHECK-DAG:     yul.func @__sol.abi_encode_tuple.padded.tail.ui256.array$_dyn_ui8_$_Memory_$ : (i256, i256, i256) -> i256
// CHECK-DAG:     yul.func @__sol.abi_encode_array.memory.padded.tail.array$_dyn_ui8_$_Memory_$ : (i256, i256, i256) -> i256
// CHECK-LABEL:   yul.func @__sol.abi_decode.memory.memory.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.mload
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.memory.ui256.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> (i256, i256)
// CHECK:           yul.mload
// CHECK:           yul.func_call @__sol.abi_decode.memory.memory.array$_dyn_ui8_$_Memory_$(
// CHECK-LABEL:   yul.func @__sol.abi_encode_array.memory.packed.inplace.array$_dyn_ui8_$_Memory_$
// CHECK-LABEL:   yul.func @__sol.abi_encode_tuple.packed.inplace.array$_dyn_ui8_$_Memory_$.ui256 : (i256, i256, i256) -> i256
// CHECK:           yul.func_call @__sol.abi_encode_array.memory.packed.inplace.array$_dyn_ui8_$_Memory_$(
// CHECK-LABEL:   yul.func @q
// CHECK:           yul.func_call @__sol.abi_decode_tuple.memory.ui256.array$_dyn_ui8_$_Memory_$({{.*}}) : (i256, i256) -> (i256, i256)
// CHECK-LABEL:   yul.func @p
// CHECK:           yul.func_call @__sol.abi_encode_tuple.packed.inplace.array$_dyn_ui8_$_Memory_$.ui256({{.*}}) : (i256, i256, i256) -> i256
