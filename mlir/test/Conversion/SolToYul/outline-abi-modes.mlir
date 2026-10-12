// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck %s

// The tuple helpers are keyed by source and mode: `abi.decode` of a memory
// `bytes` gets the `.memory.` decoder of its tuple and `abi.encodePacked`
// the `.packed.inplace.` encoder, both distinct from the dispatcher's
// `.calldata.` decoders and `.padded.tail.` encoders of the same types. The
// per-type array helpers nest inside them with the same keys.
//
// The size-less `sol.malloc` and the selector-less `sol.encode` are written
// in the generic form because their custom printers do not round-trip.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C_40 {
    sol.func @C_40() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @p_17(%arg0: !sol.array<? x ui8, Memory>, %arg1: ui256) -> !sol.string<Memory> attributes {id = 17 : i64, orig_fn_type = (!sol.array<? x ui8, Memory>, ui256) -> !sol.string<Memory>, selector = -906231479 : i32, state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      sol.store %arg0, %0 : !sol.array<? x ui8, Memory>, !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %1 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %arg1, %1 : ui256, !sol.ptr<ui256, Stack>
      %2 = sol.alloca : !sol.ptr<!sol.string<Memory>, Stack>
      %3 = "sol.malloc"() : () -> !sol.string<Memory>
      sol.store %3, %2 : !sol.string<Memory>, !sol.ptr<!sol.string<Memory>, Stack>
      %4 = sol.load %0 : !sol.ptr<!sol.array<? x ui8, Memory>, Stack>, !sol.array<? x ui8, Memory>
      %5 = sol.load %1 : !sol.ptr<ui256, Stack>, ui256
      %6 = "sol.encode"(%4, %5) <{operandSegmentSizes = array<i32: 2, 0>, packed}> : (!sol.array<? x ui8, Memory>, ui256) -> !sol.string<Memory>
      sol.return %6 : !sol.string<Memory>
    }
    sol.func @q_39(%arg0: !sol.string<Memory>) -> (ui256, !sol.array<? x ui8, Memory>) attributes {id = 39 : i64, orig_fn_type = (!sol.string<Memory>) -> (ui256, !sol.array<? x ui8, Memory>), selector = 1420308653 : i32, state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<!sol.string<Memory>, Stack>
      sol.store %arg0, %0 : !sol.string<Memory>, !sol.ptr<!sol.string<Memory>, Stack>
      %1 = sol.alloca : !sol.ptr<ui256, Stack>
      %c0_ui256 = sol.constant 0 : ui256
      sol.store %c0_ui256, %1 : ui256, !sol.ptr<ui256, Stack>
      %2 = sol.alloca : !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %3 = "sol.malloc"() <{zero_init}> : () -> !sol.array<? x ui8, Memory>
      sol.store %3, %2 : !sol.array<? x ui8, Memory>, !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %4 = sol.load %0 : !sol.ptr<!sol.string<Memory>, Stack>, !sol.string<Memory>
      %5:2 = sol.decode %4 : !sol.string<Memory> -> ui256, !sol.array<? x ui8, Memory>
      sol.return %5#0, %5#1 : ui256, !sol.array<? x ui8, Memory>
    }
  } {kind = #Contract}
}

// CHECK-LABEL: yul.object @C_40_deployed
// CHECK-LABEL:   yul.func @__sol.abi_decode.memory.memory.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.mload
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.memory.ui256.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> (i256, i256)
// CHECK:           yul.mload
// CHECK:           yul.func_call @__sol.abi_decode.memory.memory.array$_dyn_ui8_$_Memory_$(
// CHECK-LABEL:   yul.func @__sol.abi_encode_array.memory.packed.inplace.array$_dyn_ui8_$_Memory_$
// CHECK-LABEL:   yul.func @__sol.abi_encode_tuple.packed.inplace.array$_dyn_ui8_$_Memory_$.ui256 : (i256, i256, i256) -> i256
// CHECK:           yul.func_call @__sol.abi_encode_array.memory.packed.inplace.array$_dyn_ui8_$_Memory_$(
// CHECK-LABEL:   yul.func @q_39
// CHECK:           yul.func_call @__sol.abi_decode_tuple.memory.ui256.array$_dyn_ui8_$_Memory_$({{.*}}) : (i256, i256) -> (i256, i256)
// CHECK-LABEL:   yul.func @p_17
// CHECK:           yul.func_call @__sol.abi_encode_tuple.packed.inplace.array$_dyn_ui8_$_Memory_$.ui256({{.*}}) : (i256, i256, i256) -> i256

// The dispatcher's own coders of the same types are separate helpers.
// CHECK-DAG:     yul.func @__sol.abi_decode_tuple.calldata.array$_dyn_ui8_$_Memory_$.ui256 : (i256, i256) -> (i256, i256)
// CHECK-DAG:     yul.func @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
// CHECK-DAG:     yul.func @__sol.abi_encode_tuple.padded.tail.ui256.array$_dyn_ui8_$_Memory_$ : (i256, i256, i256) -> i256
// CHECK-DAG:     yul.func @__sol.abi_encode_array.memory.padded.tail.array$_dyn_ui8_$_Memory_$ : (i256, i256, i256) -> i256
