// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s \
// RUN:   --implicit-check-not='@__sol.abi_decode_tuple.calldata :' \
// RUN:   --implicit-check-not='@__sol.abi_encode_tuple.padded.tail :'

// Every non-empty ABI tuple is decoded and encoded by one helper per
// (source or mode, tuple): `__sol.abi_decode_tuple.<src>.<ty>...` and
// `__sol.abi_encode_tuple.<mode>.<ty>...`. Two selectors with the same
// parameter list share the decoder, and the per-type `abi_decode` and
// `abi_encode_array` helpers of loop-carrying elements nest inside the tuple
// helpers. An empty tuple stays inline: no helper has an empty type list.
// A constant string element is keyed as `constant_string_<keccak>`.

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
    sol.func @packed(%arg0: ui8) -> (!sol.string<Memory>, !sol.string<Memory>) attributes {state_mutability = #Pure} {
      %0 = sol.constant_string "a b"
      %1 = sol.encode %0, %arg0 : (!sol.constant_string, ui8) -> !sol.string<Memory> {packed}
      %2 = sol.constant_string "ab"
      %3 = sol.encode %2, %arg0 : (!sol.constant_string, ui8) -> !sol.string<Memory> {packed}
      sol.return %1, %3 : !sol.string<Memory>, !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed
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
// Two literals that differ only in a blank get two helpers.
// CHECK-LABEL:   yul.func @__sol.abi_encode_tuple.packed.inplace.constant_string_67fad3bfa1e0321bd021ca805ce14876e50acac8ca8532eda8cbf924da565160.ui8 : (i256, i256) -> i256
// CHECK-NEXT:    ^bb0(%{{.*}}: i256, %[[DST:.*]]: i256):
// CHECK-NEXT:      %[[AB:.*]] = yul.constant 44047497324925121336511606693520958599579173549109180625971642598225011015680
// CHECK-NEXT:      yul.mstore %[[DST]], %[[AB]]
// CHECK-NEXT:      %[[LEN:.*]] = yul.constant 2{{$}}
// CHECK-NEXT:      yul.add %[[DST]], %[[LEN]]
// CHECK-LABEL:   yul.func @__sol.abi_encode_tuple.packed.inplace.constant_string_0fcafc8424b845c8dfb7652f8432edf1b16987eee93b8d8a987751dae5a4e1f6.ui8 : (i256, i256) -> i256
// CHECK-NEXT:    ^bb0(%{{.*}}: i256, %[[DST:.*]]: i256):
// CHECK-NEXT:      %[[A_B:.*]] = yul.constant 43931561789791733446010277664546429126028899820594662472618022516313630441472
// CHECK-NEXT:      yul.mstore %[[DST]], %[[A_B]]
// CHECK-NEXT:      %[[LEN:.*]] = yul.constant 3{{$}}
// CHECK-NEXT:      yul.add %[[DST]], %[[LEN]]
// CHECK-LABEL:   yul.func @packed :
// CHECK:           yul.func_call @__sol.abi_encode_tuple.packed.inplace.constant_string_0fcafc8424b845c8dfb7652f8432edf1b16987eee93b8d8a987751dae5a4e1f6.ui8(
// CHECK:           yul.func_call @__sol.abi_encode_tuple.packed.inplace.constant_string_67fad3bfa1e0321bd021ca805ce14876e50acac8ca8532eda8cbf924da565160.ui8(
// CHECK-LABEL:   yul.func @h
// CHECK-LABEL:   yul.func @g
// CHECK-LABEL:   yul.func @f2
// CHECK-LABEL:   yul.func @f1
// CHECK:           yul.func_call @__sol.abi_decode_tuple.calldata.ui256.array$_dyn_ui8_$_Memory_$({{.*}}) : (i256, i256) -> (i256, i256)
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_dyn_ui8_$_Memory_$(
// CHECK:           yul.func_call @__sol.abi_decode_tuple.calldata.ui256.array$_dyn_ui8_$_Memory_$({{.*}}) : (i256, i256) -> (i256, i256)
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_dyn_ui8_$_Memory_$(
// CHECK:           yul.func_call @__sol.abi_decode_tuple.calldata.ui256(
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(
