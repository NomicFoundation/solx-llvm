// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s \
// RUN:   --implicit-check-not='@__sol.abi_decode_tuple.calldata :' \
// RUN:   --implicit-check-not='@__sol.abi_encode_tuple.padded.tail :'

// Every non-empty ABI tuple is decoded and encoded by one helper per
// (source or mode, tuple): `__sol.abi_decode_tuple.<src>.<ty>...` and
// `__sol.abi_encode_tuple.<mode>.<ty>...`. Two selectors with the same
// parameter list share the decoder, and the per-type `abi_decode` and
// `abi_encode_array` helpers of loop-carrying elements nest inside the tuple
// helpers. An empty tuple stays inline: no helper has an empty type list.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @f1(%arg0: ui256, %arg1: !sol.array<? x ui8, Memory>) -> !sol.array<? x ui8, Memory> attributes {orig_fn_type = (ui256, !sol.array<? x ui8, Memory>) -> !sol.array<? x ui8, Memory>, selector = 1 : i32, state_mutability = #Pure} {
      sol.return %arg1 : !sol.array<? x ui8, Memory>
    }
    sol.func @f2(%arg0: ui256, %arg1: !sol.array<? x ui8, Memory>) -> !sol.array<? x ui8, Memory> attributes {orig_fn_type = (ui256, !sol.array<? x ui8, Memory>) -> !sol.array<? x ui8, Memory>, selector = 2 : i32, state_mutability = #Pure} {
      sol.return %arg1 : !sol.array<? x ui8, Memory>
    }
    sol.func @g(%arg0: ui256) -> ui256 attributes {orig_fn_type = (ui256) -> ui256, selector = 3 : i32, state_mutability = #Pure} {
      sol.return %arg0 : ui256
    }
    sol.func @h() attributes {orig_fn_type = () -> (), selector = 4 : i32, state_mutability = #Pure} {
      sol.return
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed
// CHECK:           yul.func_call @__sol.abi_decode_tuple.calldata.ui256.array$_dyn_ui8_$_Memory_$({{.*}}) : (i256, i256) -> (i256, i256)
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_dyn_ui8_$_Memory_$(
// CHECK:           yul.func_call @__sol.abi_decode_tuple.calldata.ui256.array$_dyn_ui8_$_Memory_$({{.*}}) : (i256, i256) -> (i256, i256)
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_dyn_ui8_$_Memory_$(
// CHECK:           yul.func_call @__sol.abi_decode_tuple.calldata.ui256(
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(
// CHECK-LABEL:   yul.func @__sol.abi_encode_tuple.padded.tail.ui256 : (i256, i256) -> i256
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.ui256 : (i256, i256) -> i256
// CHECK-LABEL:   yul.func @__sol.abi_encode_array.memory.padded.tail.array$_dyn_ui8_$_Memory_$ : (i256, i256, i256) -> i256
// CHECK:           yul.for
// CHECK-LABEL:   yul.func @__sol.abi_encode_tuple.padded.tail.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.func_call @__sol.abi_encode_array.memory.padded.tail.array$_dyn_ui8_$_Memory_$(
// CHECK-LABEL:   yul.func @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.for
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.ui256.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> (i256, i256)
// CHECK:           yul.calldataload
// CHECK:           yul.func_call @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$(
// CHECK-LABEL:   yul.func @h
// CHECK-LABEL:   yul.func @g
// CHECK-LABEL:   yul.func @f2
// CHECK-LABEL:   yul.func @f1
