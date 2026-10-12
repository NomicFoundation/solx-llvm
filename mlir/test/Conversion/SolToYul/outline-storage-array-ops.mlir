// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck %s

// Storage array accesses with a bounds check, pushes and pops are outlined
// once per array type: `index_storage_array.<ty>`, returning the element
// address (a {slot, byte offset} struct for packed elements),
// `push_storage_array.<ty>` and `pop_storage_array.<ty>`. The no-panic
// bounds behaviour is part of the key. A constant index into a static array
// needs no check and stays inline.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
#View = #sol<StateMutability View>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C_89 {
    sol.state_var @n_3 slot 0 offset 0 : !sol.array<? x ui8, Storage>
    sol.state_var @f_7 slot 1 offset 0 : !sol.array<4 x ui256, Storage>
    sol.state_var @w_10 slot 5 offset 0 : !sol.array<? x ui256, Storage>
    sol.func @C_89() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @get_22(%arg0: ui256) -> ui8 attributes {id = 22 : i64, orig_fn_type = (ui256) -> ui8, selector = -1794649190 : i32, state_mutability = #View} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %arg0, %0 : ui256, !sol.ptr<ui256, Stack>
      %1 = sol.alloca : !sol.ptr<ui8, Stack>
      %c0_ui8 = sol.constant 0 : ui8
      sol.store %c0_ui8, %1 : ui8, !sol.ptr<ui8, Stack>
      %2 = sol.addr_of @n_3 : !sol.array<? x ui8, Storage>
      %3 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      %4 = sol.gep %2, %3 : !sol.array<? x ui8, Storage>, ui256, !sol.ptr<ui8, Storage>
      %5 = sol.load %4 : !sol.ptr<ui8, Storage>, ui8
      sol.return %5 : ui8
    }
    // The same access with the no-panic bounds behaviour gets its own helper.
    sol.func @getnp_99(%arg0: ui256) -> ui8 attributes {id = 99 : i64, orig_fn_type = (ui256) -> ui8, selector = 99 : i32, state_mutability = #View} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %arg0, %0 : ui256, !sol.ptr<ui256, Stack>
      %1 = sol.alloca : !sol.ptr<ui8, Stack>
      %c0_ui8 = sol.constant 0 : ui8
      sol.store %c0_ui8, %1 : ui8, !sol.ptr<ui8, Stack>
      %2 = sol.addr_of @n_3 : !sol.array<? x ui8, Storage>
      %3 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      %4 = sol.gep %2, %3 no_panic_bounds : !sol.array<? x ui8, Storage>, ui256, !sol.ptr<ui8, Storage>
      %5 = sol.load %4 : !sol.ptr<ui8, Storage>, ui8
      sol.return %5 : ui8
    }
    sol.func @get2_34(%arg0: ui256) -> ui8 attributes {id = 34 : i64, orig_fn_type = (ui256) -> ui8, selector = 823676355 : i32, state_mutability = #View} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %arg0, %0 : ui256, !sol.ptr<ui256, Stack>
      %1 = sol.alloca : !sol.ptr<ui8, Stack>
      %c0_ui8 = sol.constant 0 : ui8
      sol.store %c0_ui8, %1 : ui8, !sol.ptr<ui8, Stack>
      %2 = sol.addr_of @n_3 : !sol.array<? x ui8, Storage>
      %3 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      %4 = sol.gep %2, %3 : !sol.array<? x ui8, Storage>, ui256, !sol.ptr<ui8, Storage>
      %5 = sol.load %4 : !sol.ptr<ui8, Storage>, ui8
      sol.return %5 : ui8
    }
    sol.func @fixedConst_44() -> ui256 attributes {id = 44 : i64, orig_fn_type = () -> ui256, selector = -647998331 : i32, state_mutability = #View} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      %c0_ui256 = sol.constant 0 : ui256
      sol.store %c0_ui256, %0 : ui256, !sol.ptr<ui256, Stack>
      %1 = sol.addr_of @f_7 : !sol.array<4 x ui256, Storage>
      %c2_ui8 = sol.constant 2 : ui8
      %2 = sol.gep %1, %c2_ui8 : !sol.array<4 x ui256, Storage>, ui8, !sol.ptr<ui256, Storage>
      %3 = sol.load %2 : !sol.ptr<ui256, Storage>, ui256
      sol.return %3 : ui256
    }
    sol.func @fixedIdx_56(%arg0: ui256) -> ui256 attributes {id = 56 : i64, orig_fn_type = (ui256) -> ui256, selector = 734579996 : i32, state_mutability = #View} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %arg0, %0 : ui256, !sol.ptr<ui256, Stack>
      %1 = sol.alloca : !sol.ptr<ui256, Stack>
      %c0_ui256 = sol.constant 0 : ui256
      sol.store %c0_ui256, %1 : ui256, !sol.ptr<ui256, Stack>
      %2 = sol.addr_of @f_7 : !sol.array<4 x ui256, Storage>
      %3 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      %4 = sol.gep %2, %3 : !sol.array<4 x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
      %5 = sol.load %4 : !sol.ptr<ui256, Storage>, ui256
      sol.return %5 : ui256
    }
    sol.func @push_74(%arg0: ui8) attributes {id = 74 : i64, orig_fn_type = (ui8) -> (), selector = -1238054656 : i32, state_mutability = #NonPayable} {
      %0 = sol.alloca : !sol.ptr<ui8, Stack>
      sol.store %arg0, %0 : ui8, !sol.ptr<ui8, Stack>
      %1 = sol.addr_of @n_3 : !sol.array<? x ui8, Storage>
      %2 = sol.push %1 : !sol.array<? x ui8, Storage> -> !sol.ptr<ui8, Storage>
      %3 = sol.load %0 : !sol.ptr<ui8, Stack>, ui8
      sol.store %3, %2 : ui8, !sol.ptr<ui8, Storage>
      %4 = sol.addr_of @n_3 : !sol.array<? x ui8, Storage>
      %5 = sol.push %4 : !sol.array<? x ui8, Storage> -> !sol.ptr<ui8, Storage>
      %6 = sol.load %0 : !sol.ptr<ui8, Stack>, ui8
      sol.store %6, %5 : ui8, !sol.ptr<ui8, Storage>
      sol.return
    }
    sol.func @pop_88() attributes {id = 88 : i64, orig_fn_type = () -> (), selector = -1527978708 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @n_3 : !sol.array<? x ui8, Storage>
      sol.pop %0 : !sol.array<? x ui8, Storage>
      %1 = sol.addr_of @w_10 : !sol.array<? x ui256, Storage>
      sol.pop %1 : !sol.array<? x ui256, Storage>
      sol.return
    }
  } {kind = #Contract}
}

// CHECK-LABEL: yul.object @C_89_deployed
// CHECK-DAG:     yul.func @__sol.pop_storage_array.array$_dyn_ui256_$_Storage_$ : (i256) -> ()
// CHECK-DAG:     yul.func @__sol.pop_storage_array.array$_dyn_ui8_$_Storage_$ : (i256) -> ()
// CHECK-DAG:     yul.func @__sol.push_storage_array.array$_dyn_ui8_$_Storage_$ : (i256) -> !llvm.struct<(i256, i256)>
// CHECK-DAG:     yul.func @__sol.index_storage_array.array$_4_ui256_$_Storage_$ : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK-DAG:     yul.func @__sol.index_storage_array.array$_dyn_ui8_$_Storage_$ : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK-DAG:     yul.func @__sol.index_storage_array.array$_dyn_ui8_$_Storage_$.nopanic : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK-LABEL:   yul.func @pop_88
// CHECK:           yul.func_call @__sol.pop_storage_array.array$_dyn_ui8_$_Storage_$(
// CHECK:           yul.func_call @__sol.pop_storage_array.array$_dyn_ui256_$_Storage_$(
// CHECK-LABEL:   yul.func @push_74
// CHECK:           yul.func_call @__sol.push_storage_array.array$_dyn_ui8_$_Storage_$(
// CHECK:           yul.func_call @__sol.push_storage_array.array$_dyn_ui8_$_Storage_$(
// CHECK-LABEL:   yul.func @fixedIdx_56
// CHECK:           yul.func_call @__sol.index_storage_array.array$_4_ui256_$_Storage_$(
// CHECK-LABEL:   yul.func @fixedConst_44
// CHECK-NOT:       yul.func_call @__sol.index_storage_array
// CHECK:           yul.sload
// CHECK-NOT:       yul.func_call @__sol.index_storage_array
// CHECK-LABEL:   yul.func @get2_34
// CHECK:           yul.func_call @__sol.index_storage_array.array$_dyn_ui8_$_Storage_$(
// CHECK-LABEL:   yul.func @getnp_99
// CHECK:           yul.func_call @__sol.index_storage_array.array$_dyn_ui8_$_Storage_$.nopanic(
// CHECK-LABEL:   yul.func @get_22
// CHECK:           yul.func_call @__sol.index_storage_array.array$_dyn_ui8_$_Storage_$(
