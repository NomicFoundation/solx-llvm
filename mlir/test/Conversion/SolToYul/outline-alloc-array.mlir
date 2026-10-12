// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck %s

// A memory array of reference-typed elements allocates its rows in a loop
// that is outlined once per type as `__sol.alloc_array.<zeroed|uninit>.memory.<ty>`:
// a static array, or a dynamic array at the outermost dimension with a
// runtime length. A dynamic array with a constant length keeps its row loop
// inline for the optimizer to unroll, and an array of scalars has no rows.
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
  sol.contract @C_64 {
    sol.func @C_64() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @dynRuntime_19(%arg0: ui256) -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory> attributes {id = 19 : i64, orig_fn_type = (ui256) -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory>, selector = -905461388 : i32, state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %arg0, %0 : ui256, !sol.ptr<ui256, Stack>
      %1 = sol.alloca : !sol.ptr<!sol.array<? x !sol.array<? x ui256, Memory>, Memory>, Stack>
      %2 = "sol.malloc"() <{zero_init}> : () -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
      sol.store %2, %1 : !sol.array<? x !sol.array<? x ui256, Memory>, Memory>, !sol.ptr<!sol.array<? x !sol.array<? x ui256, Memory>, Memory>, Stack>
      %3 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      %4 = sol.malloc %3 zero_init : ui256 !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
      sol.store %4, %1 : !sol.array<? x !sol.array<? x ui256, Memory>, Memory>, !sol.ptr<!sol.array<? x !sol.array<? x ui256, Memory>, Memory>, Stack>
      %5 = sol.load %1 : !sol.ptr<!sol.array<? x !sol.array<? x ui256, Memory>, Memory>, Stack>, !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
      sol.return %5 : !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
    }
    sol.func @dynConst_36() -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory> attributes {id = 36 : i64, orig_fn_type = () -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory>, selector = -159915855 : i32, state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<!sol.array<? x !sol.array<? x ui256, Memory>, Memory>, Stack>
      %1 = "sol.malloc"() <{zero_init}> : () -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
      sol.store %1, %0 : !sol.array<? x !sol.array<? x ui256, Memory>, Memory>, !sol.ptr<!sol.array<? x !sol.array<? x ui256, Memory>, Memory>, Stack>
      %c3_ui8 = sol.constant 3 : ui8
      %2 = sol.malloc %c3_ui8 zero_init : ui8 !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
      sol.store %2, %0 : !sol.array<? x !sol.array<? x ui256, Memory>, Memory>, !sol.ptr<!sol.array<? x !sol.array<? x ui256, Memory>, Memory>, Stack>
      %3 = sol.load %0 : !sol.ptr<!sol.array<? x !sol.array<? x ui256, Memory>, Memory>, Stack>, !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
      sol.return %3 : !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
    }
    sol.func @staticRows_46() -> !sol.array<3 x !sol.array<2 x ui256, Memory>, Memory> attributes {id = 46 : i64, orig_fn_type = () -> !sol.array<3 x !sol.array<2 x ui256, Memory>, Memory>, selector = 752479973 : i32, state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<!sol.array<3 x !sol.array<2 x ui256, Memory>, Memory>, Stack>
      %1 = "sol.malloc"() <{zero_init}> : () -> !sol.array<3 x !sol.array<2 x ui256, Memory>, Memory>
      sol.store %1, %0 : !sol.array<3 x !sol.array<2 x ui256, Memory>, Memory>, !sol.ptr<!sol.array<3 x !sol.array<2 x ui256, Memory>, Memory>, Stack>
      %2 = sol.load %0 : !sol.ptr<!sol.array<3 x !sol.array<2 x ui256, Memory>, Memory>, Stack>, !sol.array<3 x !sol.array<2 x ui256, Memory>, Memory>
      sol.return %2 : !sol.array<3 x !sol.array<2 x ui256, Memory>, Memory>
    }
    sol.func @scalars_63(%arg0: ui256) -> !sol.array<? x ui256, Memory> attributes {id = 63 : i64, orig_fn_type = (ui256) -> !sol.array<? x ui256, Memory>, selector = -829040418 : i32, state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %arg0, %0 : ui256, !sol.ptr<ui256, Stack>
      %1 = sol.alloca : !sol.ptr<!sol.array<? x ui256, Memory>, Stack>
      %2 = "sol.malloc"() <{zero_init}> : () -> !sol.array<? x ui256, Memory>
      sol.store %2, %1 : !sol.array<? x ui256, Memory>, !sol.ptr<!sol.array<? x ui256, Memory>, Stack>
      %3 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      %4 = sol.malloc %3 zero_init : ui256 !sol.array<? x ui256, Memory>
      sol.store %4, %1 : !sol.array<? x ui256, Memory>, !sol.ptr<!sol.array<? x ui256, Memory>, Stack>
      %5 = sol.load %1 : !sol.ptr<!sol.array<? x ui256, Memory>, Stack>, !sol.array<? x ui256, Memory>
      sol.return %5 : !sol.array<? x ui256, Memory>
    }
  } {kind = #Contract}
}

// CHECK-LABEL: yul.object @C_64_deployed
// CHECK-DAG:     yul.func @__sol.alloc_array.zeroed.memory.array$_3_array$_2_ui256_$_Memory_$_$_Memory_$ : () -> i256
// CHECK-DAG:     yul.func @__sol.alloc_array.zeroed.memory.array$_dyn_array$_dyn_ui256_$_Memory_$_$_Memory_$ : (i256) -> i256
// CHECK-LABEL:   yul.func @scalars_63
// CHECK-NOT:       yul.func_call @__sol.alloc_array
// CHECK-LABEL:   yul.func @staticRows_46
// CHECK:           yul.func_call @__sol.alloc_array.zeroed.memory.array$_3_array$_2_ui256_$_Memory_$_$_Memory_$() : () -> i256
// CHECK-LABEL:   yul.func @dynConst_36
// CHECK-NOT:       yul.func_call @__sol.alloc_array
// CHECK:           yul.for
// CHECK-NOT:       yul.func_call @__sol.alloc_array
// CHECK-LABEL:   yul.func @dynRuntime_19
// CHECK:           yul.func_call @__sol.alloc_array.zeroed.memory.array$_dyn_array$_dyn_ui256_$_Memory_$_$_Memory_$(%{{.*}}) : (i256) -> i256
