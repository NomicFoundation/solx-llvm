// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A memory array of reference-typed elements allocates its rows in a loop
// that is outlined once per type as `__sol.alloc_array.<zeroed|uninit>.memory.<ty>`:
// a static array, or a dynamic array at the outermost dimension with a
// runtime length. A dynamic array with a constant length keeps its row loop
// inline for the optimizer to unroll, and an array of scalars has no rows.
//
// The size-less `sol.malloc` is written in the generic form because its
// custom printer does not round-trip.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @dynRuntime(%arg0: ui256) -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory> attributes {orig_fn_type = (ui256) -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory>, selector = 1 : i32, state_mutability = #Pure} {
      %0 = sol.malloc %arg0 zero_init : ui256 !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
      sol.return %0 : !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
    }
    sol.func @dynConst() -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory> attributes {orig_fn_type = () -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory>, selector = 2 : i32, state_mutability = #Pure} {
      %c3_ui8 = sol.constant 3 : ui8
      %0 = sol.malloc %c3_ui8 zero_init : ui8 !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
      sol.return %0 : !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
    }
    sol.func @staticRows() -> !sol.array<3 x !sol.array<2 x ui256, Memory>, Memory> attributes {orig_fn_type = () -> !sol.array<3 x !sol.array<2 x ui256, Memory>, Memory>, selector = 3 : i32, state_mutability = #Pure} {
      %0 = "sol.malloc"() <{zero_init}> : () -> !sol.array<3 x !sol.array<2 x ui256, Memory>, Memory>
      sol.return %0 : !sol.array<3 x !sol.array<2 x ui256, Memory>, Memory>
    }
    sol.func @scalars(%arg0: ui256) -> !sol.array<? x ui256, Memory> attributes {orig_fn_type = (ui256) -> !sol.array<? x ui256, Memory>, selector = 4 : i32, state_mutability = #Pure} {
      %0 = sol.malloc %arg0 zero_init : ui256 !sol.array<? x ui256, Memory>
      sol.return %0 : !sol.array<? x ui256, Memory>
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed
// The encoder of a word array row is one mcopy.
// CHECK-LABEL:   yul.func @__sol.abi_encode_array.memory.padded.tail.array$_3_array$_2_ui256_$_Memory_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:           yul.for
// CHECK-NOT:         yul.for
// CHECK:             yul.mcopy
// CHECK:           yul.func_return
// CHECK-DAG:     yul.func @__sol.alloc_array.zeroed.memory.array$_3_array$_2_ui256_$_Memory_$_$_Memory_$ : () -> i256
// CHECK-DAG:     yul.func @__sol.alloc_array.zeroed.memory.array$_dyn_array$_dyn_ui256_$_Memory_$_$_Memory_$ : (i256) -> i256
// CHECK-LABEL:   yul.func @scalars
// CHECK-NOT:       yul.func_call @__sol.alloc_array
// CHECK-LABEL:   yul.func @staticRows
// CHECK:           yul.func_call @__sol.alloc_array.zeroed.memory.array$_3_array$_2_ui256_$_Memory_$_$_Memory_$() : () -> i256
// CHECK-LABEL:   yul.func @dynConst
// CHECK-NOT:       yul.func_call @__sol.alloc_array
// CHECK:           yul.for
// CHECK-NOT:       yul.func_call @__sol.alloc_array
// CHECK-LABEL:   yul.func @dynRuntime
// CHECK:           yul.func_call @__sol.alloc_array.zeroed.memory.array$_dyn_array$_dyn_ui256_$_Memory_$_$_Memory_$(%{{.*}}) : (i256) -> i256
