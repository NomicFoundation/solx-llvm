// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck %s
// RUN: mlir-opt --convert-sol-to-yul --convert-yul-to-std %s | \
// RUN:   FileCheck --check-prefix=STD %s

// An array copy into storage is emitted once per (source, destination) type
// pair as a `__sol.copy_array.*` helper and every site becomes a call. A
// calldata source is a fat pointer and is passed as the one struct value the
// type converter gives it.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Osaka = #sol<EvmVersion Osaka>
#NonPayable = #sol<StateMutability NonPayable>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @s0 slot 0 offset 0 : !sol.array<? x ui256, Storage>
    sol.state_var @s1 slot 1 offset 0 : !sol.array<? x ui256, Storage>

    // Two memory -> storage copies of the same type share one helper.
    sol.func @m2s(%arg0: !sol.array<? x ui256, Memory>) attributes {id = 1 : i64, orig_fn_type = (!sol.array<? x ui256, Memory>) -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0 : !sol.array<? x ui256, Storage>
      sol.copy %arg0, %0 : !sol.array<? x ui256, Memory>, !sol.array<? x ui256, Storage>
      %1 = sol.addr_of @s1 : !sol.array<? x ui256, Storage>
      sol.copy %arg0, %1 : !sol.array<? x ui256, Memory>, !sol.array<? x ui256, Storage>
      sol.return
    }

    // A calldata -> storage copy: the fat pointer is passed as is.
    sol.func @cd2s(%arg0: !sol.array<? x ui256, CallData>) attributes {id = 2 : i64, orig_fn_type = (!sol.array<? x ui256, CallData>) -> (), selector = 2 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0 : !sol.array<? x ui256, Storage>
      sol.copy %arg0, %0 : !sol.array<? x ui256, CallData>, !sol.array<? x ui256, Storage>
      sol.return
    }
  } {kind = #Contract}
}

// The helpers are emitted before the user functions that call them.
// CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.array$_dyn_ui256_$_CallData_$.array$_dyn_ui256_$_Storage_$ : (!llvm.struct<(i256, i256)>, i256) -> ()
// CHECK:         llvm.extractvalue %arg0[1]
// CHECK:         llvm.extractvalue %arg0[0]
// CHECK:         yul.for
// CHECK:           yul.calldataload
// CHECK:           yul.sstore
// CHECK:         yul.func_return

// CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_dyn_ui256_$_Memory_$.array$_dyn_ui256_$_Storage_$ : (i256, i256) -> ()
// CHECK:         yul.for
// CHECK:           yul.sstore
// CHECK:         yul.func_return


// CHECK-LABEL: yul.func @cd2s : (!llvm.struct<(i256, i256)>) -> ()
// CHECK-NOT:     yul.sstore
// CHECK-NOT:     llvm.extractvalue
// CHECK:         yul.func_call @__sol.copy_array.calldata.storage.array$_dyn_ui256_$_CallData_$.array$_dyn_ui256_$_Storage_$(%arg0, %{{.*}}) : (!llvm.struct<(i256, i256)>, i256) -> ()
// CHECK-NOT:     yul.sstore
// CHECK:         yul.func_return


// CHECK-LABEL: yul.func @m2s
// CHECK-NOT:     yul.sstore
// CHECK:         yul.func_call @__sol.copy_array.memory.storage.array$_dyn_ui256_$_Memory_$.array$_dyn_ui256_$_Storage_$(%arg0, %{{.*}})
// CHECK:         yul.func_call @__sol.copy_array.memory.storage.array$_dyn_ui256_$_Memory_$.array$_dyn_ui256_$_Storage_$(%arg0, %{{.*}})
// CHECK-NOT:     yul.sstore
// CHECK:         yul.func_return


// STD: func.func @__sol.copy_array.calldata.storage.array$_dyn_ui256_$_CallData_$.array$_dyn_ui256_$_Storage_$(%arg0: !llvm.struct<(i256, i256)>, %arg1: i256) attributes {llvm.linkage = #llvm.linkage<private>, passthrough = ["nofree", "null_pointer_is_valid"]}
// STD: func.func @__sol.copy_array.memory.storage.array$_dyn_ui256_$_Memory_$.array$_dyn_ui256_$_Storage_$({{.*}}) attributes {llvm.linkage = #llvm.linkage<private>, passthrough = ["nofree", "null_pointer_is_valid"]}
// STD: func.func @m2s({{.*}}) attributes {llvm.linkage = #llvm.linkage<private>, passthrough = ["nofree", "null_pointer_is_valid"]}
