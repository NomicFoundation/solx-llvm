// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck %s
// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck --check-prefix=NODEF %s

// Every non-empty ABI tuple is decoded and encoded by one helper per
// (source or mode, tuple): `__sol.abi_decode_tuple.<src>.<ty>...` and
// `__sol.abi_encode_tuple.<mode>.<ty>...`. Two selectors with the same
// parameter list share the decoder, and the per-type `abi_decode` and
// `abi_encode_array` helpers of loop-carrying elements nest inside the tuple
// helpers. An empty tuple stays inline.
//
// The size-less `sol.malloc` is written in the generic form because its
// custom printer does not round-trip.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C_43 {
    sol.func @C_43() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f1_14(%arg0: ui256, %arg1: !sol.array<? x ui8, Memory>) -> !sol.array<? x ui8, Memory> attributes {id = 14 : i64, orig_fn_type = (ui256, !sol.array<? x ui8, Memory>) -> !sol.array<? x ui8, Memory>, selector = 33756874 : i32, state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %arg0, %0 : ui256, !sol.ptr<ui256, Stack>
      %1 = sol.alloca : !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      sol.store %arg1, %1 : !sol.array<? x ui8, Memory>, !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %2 = sol.alloca : !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %3 = "sol.malloc"() <{zero_init}> : () -> !sol.array<? x ui8, Memory>
      sol.store %3, %2 : !sol.array<? x ui8, Memory>, !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %4 = sol.load %1 : !sol.ptr<!sol.array<? x ui8, Memory>, Stack>, !sol.array<? x ui8, Memory>
      sol.return %4 : !sol.array<? x ui8, Memory>
    }
    sol.func @f2_28(%arg0: ui256, %arg1: !sol.array<? x ui8, Memory>) -> !sol.array<? x ui8, Memory> attributes {id = 28 : i64, orig_fn_type = (ui256, !sol.array<? x ui8, Memory>) -> !sol.array<? x ui8, Memory>, selector = -2036475371 : i32, state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %arg0, %0 : ui256, !sol.ptr<ui256, Stack>
      %1 = sol.alloca : !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      sol.store %arg1, %1 : !sol.array<? x ui8, Memory>, !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %2 = sol.alloca : !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %3 = "sol.malloc"() <{zero_init}> : () -> !sol.array<? x ui8, Memory>
      sol.store %3, %2 : !sol.array<? x ui8, Memory>, !sol.ptr<!sol.array<? x ui8, Memory>, Stack>
      %4 = sol.load %1 : !sol.ptr<!sol.array<? x ui8, Memory>, Stack>, !sol.array<? x ui8, Memory>
      sol.return %4 : !sol.array<? x ui8, Memory>
    }
    sol.func @g_38(%arg0: ui256) -> ui256 attributes {id = 38 : i64, orig_fn_type = (ui256) -> ui256, selector = -467655094 : i32, state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %arg0, %0 : ui256, !sol.ptr<ui256, Stack>
      %1 = sol.alloca : !sol.ptr<ui256, Stack>
      %c0_ui256 = sol.constant 0 : ui256
      sol.store %c0_ui256, %1 : ui256, !sol.ptr<ui256, Stack>
      %2 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      sol.return %2 : ui256
    }
    sol.func @h_42() attributes {id = 42 : i64, orig_fn_type = () -> (), selector = -1194732699 : i32, state_mutability = #Pure} {
      sol.return
    }
  } {kind = #Contract}
}

// CHECK-LABEL: yul.object @C_43_deployed
// CHECK:           yul.func_call @__sol.abi_decode_tuple.calldata.ui256.array$_dyn_ui8_$_Memory_$({{.*}}) : (i256, i256) -> (i256, i256)
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_dyn_ui8_$_Memory_$(
// CHECK:           yul.func_call @__sol.abi_decode_tuple.calldata.ui256.array$_dyn_ui8_$_Memory_$({{.*}}) : (i256, i256) -> (i256, i256)
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_dyn_ui8_$_Memory_$(
// CHECK:           yul.func_call @__sol.abi_decode_tuple.calldata.ui256(
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(
// CHECK-LABEL:   yul.func @h_42
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.ui256.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> (i256, i256)
// CHECK:           yul.calldataload
// CHECK:           yul.func_call @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$(
// CHECK-LABEL:   yul.func @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.for
// CHECK-LABEL:   yul.func @__sol.abi_encode_tuple.padded.tail.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.func_call @__sol.abi_encode_array.memory.padded.tail.array$_dyn_ui8_$_Memory_$(
// CHECK-LABEL:   yul.func @__sol.abi_encode_array.memory.padded.tail.array$_dyn_ui8_$_Memory_$ : (i256, i256, i256) -> i256
// CHECK:           yul.for
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.ui256 : (i256, i256) -> i256
// CHECK-LABEL:   yul.func @__sol.abi_encode_tuple.padded.tail.ui256 : (i256, i256) -> i256

// The empty tuples of @h get no helper: a symbol with no type field.
// NODEF-NOT: yul.func @__sol.abi_decode_tuple.calldata :
// NODEF-NOT: yul.func @__sol.abi_encode_tuple.padded.tail :
