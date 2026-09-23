// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck %s
// RUN: mlir-opt --convert-sol-to-yul --convert-yul-to-std %s | \
// RUN:   FileCheck --check-prefix=STD %s

// An array copy into storage is emitted once per (source, destination) type
// pair as a `__sol.copy_array.*` helper and every site becomes a call. A
// calldata source is a fat pointer; it crosses the helper boundary as two
// words (data address, length).

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

    // A calldata -> storage copy: the fat pointer is passed as two words.
    sol.func @cd2s(%arg0: !sol.array<? x ui256, CallData>) attributes {id = 2 : i64, orig_fn_type = (!sol.array<? x ui256, CallData>) -> (), selector = 2 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s0 : !sol.array<? x ui256, Storage>
      sol.copy %arg0, %0 : !sol.array<? x ui256, CallData>, !sol.array<? x ui256, Storage>
      sol.return
    }
  } {kind = #Contract}
}

// The helpers are emitted before the user functions that call them.
// CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.solarray$L$Dxui256$CCallData$R.solarray$L$Dxui256$CStorage$R : (i256, i256, i256) -> ()
// CHECK:         yul.for
// CHECK:           yul.calldataload
// CHECK:           yul.sstore
// CHECK:         yul.func_return

// CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.solarray$L$Dxui256$CMemory$R.solarray$L$Dxui256$CStorage$R : (i256, i256) -> ()
// CHECK:         yul.for
// CHECK:           yul.sstore
// CHECK:         yul.func_return
// A helper is marked as compiler-generated and keeps the marker through the
// lowering to the standard dialects, where it becomes an LLVM function
// attribute. EVMAlwaysInline reads it to decide whether a helper shared by
// several call sites stays out of line.
// CHECK:       } {evm.sol_helper, llvm.linkage = #llvm.linkage<private>}


// CHECK-LABEL: yul.func @cd2s
// CHECK-NOT:     yul.sstore
// CHECK:         %[[DATA:.*]] = llvm.extractvalue %arg0[0]
// CHECK-NEXT:    %[[LEN:.*]] = llvm.extractvalue %arg0[1]
// CHECK:         yul.func_call @__sol.copy_array.calldata.storage.solarray$L$Dxui256$CCallData$R.solarray$L$Dxui256$CStorage$R(%[[DATA]], %[[LEN]], %{{.*}})
// CHECK-NOT:     yul.sstore
// CHECK:         yul.func_return


// CHECK-LABEL: yul.func @m2s
// CHECK-NOT:     yul.sstore
// CHECK:         yul.func_call @__sol.copy_array.memory.storage.solarray$L$Dxui256$CMemory$R.solarray$L$Dxui256$CStorage$R(%arg0, %{{.*}})
// CHECK:         yul.func_call @__sol.copy_array.memory.storage.solarray$L$Dxui256$CMemory$R.solarray$L$Dxui256$CStorage$R(%arg0, %{{.*}})
// CHECK-NOT:     yul.sstore
// CHECK:         yul.func_return


// STD: func.func @__sol.copy_array.calldata.storage.solarray$L$Dxui256$CCallData$R.solarray$L$Dxui256$CStorage$R({{.*}}) attributes {llvm.linkage = #llvm.linkage<private>, passthrough = ["nofree", "null_pointer_is_valid", "evm.sol_helper"]}
// STD: func.func @__sol.copy_array.memory.storage.solarray$L$Dxui256$CMemory$R.solarray$L$Dxui256$CStorage$R({{.*}}) attributes {llvm.linkage = #llvm.linkage<private>, passthrough = ["nofree", "null_pointer_is_valid", "evm.sol_helper"]}
// A user function carries no marker.
// STD: func.func @m2s({{.*}}) attributes {llvm.linkage = #llvm.linkage<private>, passthrough = ["nofree", "null_pointer_is_valid"]}
