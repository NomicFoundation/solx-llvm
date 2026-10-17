// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Storage array accesses with a bounds check, pushes and pops are outlined
// once per array type: `index_storage_array.<ty>`, returning the element
// address (a {slot, byte offset} struct for packed elements),
// `push_storage_array.<ty>` and `pop_storage_array.<ty>`. The no-panic
// bounds behaviour is part of the key. A constant index into a static array
// needs no check and stays inline.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
#View = #sol<StateMutability View>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @n slot 0 offset 0 : !sol.array<? x ui8, Storage>
    sol.state_var @f slot 1 offset 0 : !sol.array<4 x ui256, Storage>
    sol.state_var @w slot 5 offset 0 : !sol.array<? x ui256, Storage>
    sol.func @get(%arg0: ui256) -> ui8 attributes {orig_fn_type = (ui256) -> ui8, selector = 1 : i32, state_mutability = #View} {
      %0 = sol.addr_of @n : !sol.array<? x ui8, Storage>
      %1 = sol.gep %0, %arg0 : !sol.array<? x ui8, Storage>, ui256, !sol.ptr<ui8, Storage>
      %2 = sol.load %1 : !sol.ptr<ui8, Storage>, ui8
      sol.return %2 : ui8
    }
    sol.func @getnp(%arg0: ui256) -> ui8 attributes {orig_fn_type = (ui256) -> ui8, selector = 2 : i32, state_mutability = #View} {
      %0 = sol.addr_of @n : !sol.array<? x ui8, Storage>
      %1 = sol.gep %0, %arg0 no_panic_bounds : !sol.array<? x ui8, Storage>, ui256, !sol.ptr<ui8, Storage>
      %2 = sol.load %1 : !sol.ptr<ui8, Storage>, ui8
      sol.return %2 : ui8
    }
    sol.func @get2(%arg0: ui256) -> ui8 attributes {orig_fn_type = (ui256) -> ui8, selector = 3 : i32, state_mutability = #View} {
      %0 = sol.addr_of @n : !sol.array<? x ui8, Storage>
      %1 = sol.gep %0, %arg0 : !sol.array<? x ui8, Storage>, ui256, !sol.ptr<ui8, Storage>
      %2 = sol.load %1 : !sol.ptr<ui8, Storage>, ui8
      sol.return %2 : ui8
    }
    sol.func @fixedConst() -> ui256 attributes {orig_fn_type = () -> ui256, selector = 4 : i32, state_mutability = #View} {
      %0 = sol.addr_of @f : !sol.array<4 x ui256, Storage>
      %c2_ui8 = sol.constant 2 : ui8
      %1 = sol.gep %0, %c2_ui8 : !sol.array<4 x ui256, Storage>, ui8, !sol.ptr<ui256, Storage>
      %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
      sol.return %2 : ui256
    }
    sol.func @fixedIdx(%arg0: ui256) -> ui256 attributes {orig_fn_type = (ui256) -> ui256, selector = 5 : i32, state_mutability = #View} {
      %0 = sol.addr_of @f : !sol.array<4 x ui256, Storage>
      %1 = sol.gep %0, %arg0 : !sol.array<4 x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
      %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
      sol.return %2 : ui256
    }
    sol.func @push(%arg0: ui8) attributes {orig_fn_type = (ui8) -> (), selector = 6 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @n : !sol.array<? x ui8, Storage>
      %1 = sol.push %0 : !sol.array<? x ui8, Storage> -> !sol.ptr<ui8, Storage>
      sol.store %arg0, %1 : ui8, !sol.ptr<ui8, Storage>
      %2 = sol.addr_of @n : !sol.array<? x ui8, Storage>
      %3 = sol.push %2 : !sol.array<? x ui8, Storage> -> !sol.ptr<ui8, Storage>
      sol.store %arg0, %3 : ui8, !sol.ptr<ui8, Storage>
      sol.return
    }
    sol.func @pop() attributes {orig_fn_type = () -> (), selector = 7 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @n : !sol.array<? x ui8, Storage>
      sol.pop %0 : !sol.array<? x ui8, Storage>
      %1 = sol.addr_of @w : !sol.array<? x ui256, Storage>
      sol.pop %1 : !sol.array<? x ui256, Storage>
      sol.return
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed
// CHECK-DAG:     yul.func @__sol.pop_storage_array.array$_dyn_ui256_$_Storage_$ : (i256) -> ()
// CHECK-DAG:     yul.func @__sol.pop_storage_array.array$_dyn_ui8_$_Storage_$ : (i256) -> ()
// CHECK-DAG:     yul.func @__sol.push_storage_array.array$_dyn_ui8_$_Storage_$ : (i256) -> !llvm.struct<(i256, i256)>
// CHECK-DAG:     yul.func @__sol.index_storage_array.array$_4_ui256_$_Storage_$ : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK-DAG:     yul.func @__sol.index_storage_array.array$_dyn_ui8_$_Storage_$ : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK-DAG:     yul.func @__sol.index_storage_array.array$_dyn_ui8_$_Storage_$.nopanic : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK-LABEL:   yul.func @pop
// CHECK:           yul.func_call @__sol.pop_storage_array.array$_dyn_ui8_$_Storage_$(
// CHECK:           yul.func_call @__sol.pop_storage_array.array$_dyn_ui256_$_Storage_$(
// CHECK-LABEL:   yul.func @push
// CHECK:           yul.func_call @__sol.push_storage_array.array$_dyn_ui8_$_Storage_$(
// CHECK:           yul.sstore
// CHECK:           yul.func_call @__sol.push_storage_array.array$_dyn_ui8_$_Storage_$(
// CHECK:           yul.sstore
// CHECK-LABEL:   yul.func @fixedIdx
// CHECK:           yul.func_call @__sol.index_storage_array.array$_4_ui256_$_Storage_$(
// CHECK-LABEL:   yul.func @fixedConst
// CHECK-NOT:       yul.func_call @__sol.index_storage_array
// CHECK:           yul.sload
// CHECK-NOT:       yul.func_call @__sol.index_storage_array
// CHECK-LABEL:   yul.func @get2
// CHECK:           yul.func_call @__sol.index_storage_array.array$_dyn_ui8_$_Storage_$(
// CHECK-LABEL:   yul.func @getnp
// CHECK:           yul.func_call @__sol.index_storage_array.array$_dyn_ui8_$_Storage_$.nopanic(
// CHECK-LABEL:   yul.func @get
// CHECK:           yul.func_call @__sol.index_storage_array.array$_dyn_ui8_$_Storage_$(
