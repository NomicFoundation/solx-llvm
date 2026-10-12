// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck %s

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    // Nested static array, calldata -> memory: a row loop around one
    // calldatacopy of 128 bytes.
    sol.func @cd2m_nested(%arg0: !sol.array<4 x !sol.array<4 x ui256, CallData>, CallData>, %arg1: !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>) attributes {id = 1 : i64, orig_fn_type = (!sol.array<4 x !sol.array<4 x ui256, CallData>, CallData>, !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>) -> (), selector = 1 : i32, state_mutability = #Pure} {
      sol.copy %arg0, %arg1 : !sol.array<4 x !sol.array<4 x ui256, CallData>, CallData>, !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>
      sol.return
    }

    // Flat static array, calldata -> memory: a single calldatacopy.
    sol.func @cd2m_flat(%arg0: !sol.array<4 x ui256, CallData>, %arg1: !sol.array<4 x ui256, Memory>) attributes {id = 2 : i64, orig_fn_type = (!sol.array<4 x ui256, CallData>, !sol.array<4 x ui256, Memory>) -> (), selector = 2 : i32, state_mutability = #Pure} {
      sol.copy %arg0, %arg1 : !sol.array<4 x ui256, CallData>, !sol.array<4 x ui256, Memory>
      sol.return
    }

    // Nested static array, memory -> memory: a row loop around one mcopy.
    sol.func @m2m_nested(%arg0: !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>, %arg1: !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>) attributes {id = 3 : i64, orig_fn_type = (!sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>, !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>) -> (), selector = 3 : i32, state_mutability = #Pure} {
      sol.copy %arg0, %arg1 : !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>, !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>
      sol.return
    }

    // Narrow elements need cleanup and keep the word loop.
    sol.func @cd2m_narrow(%arg0: !sol.array<4 x ui8, CallData>, %arg1: !sol.array<4 x ui8, Memory>) attributes {id = 4 : i64, orig_fn_type = (!sol.array<4 x ui8, CallData>, !sol.array<4 x ui8, Memory>) -> (), selector = 4 : i32, state_mutability = #Pure} {
      sol.copy %arg0, %arg1 : !sol.array<4 x ui8, CallData>, !sol.array<4 x ui8, Memory>
      sol.return
    }
  } {kind = #Contract}
}

// A copy whose elements need a loop is emitted once per type pair as a
// `__sol.copy_array.*` helper and every site calls it; the loop and its bulk
// copy live in the helper. A copy that is a single bulk copy stays inline.
// A row of a memory destination is a fresh allocation: the loop clones each
// row with one bulk copy and stores its pointer in the row slot.

// CHECK-LABEL: yul.func @__sol.copy_array.calldata.memory.array$_4_ui8_$_CallData_$.array$_4_ui8_$_Memory_$
// CHECK:         yul.for
// CHECK:           yul.calldataload
// CHECK:           yul.mstore
// CHECK-NOT:     yul.calldatacopy
// CHECK:         yul.func_return

// CHECK-LABEL: yul.func @__sol.copy_array.memory.memory.array$_4_array$_4_ui256_$_Memory_$_$_Memory_$.array$_4_array$_4_ui256_$_Memory_$_$_Memory_$
// CHECK:         yul.for
// CHECK:           %[[SRC_ROW:.*]] = yul.mload
// CHECK:           %[[DST_ROW:.*]] = yul.mload %c64_i256
// CHECK:           %[[M2M_SIZE:.*]] = yul.mul %c4_i256{{.*}}, %c32_i256
// CHECK-NEXT:      yul.mcopy %[[DST_ROW]], %[[SRC_ROW]], %[[M2M_SIZE]]
// CHECK-NEXT:      yul.mstore {{.*}}, %[[DST_ROW]]
// CHECK:         yul.func_return

// The nested calldata copy loops per row and copies each row in bulk.
// CHECK-LABEL: yul.func @__sol.copy_array.calldata.memory.array$_4_array$_4_ui256_$_CallData_$_$_CallData_$.array$_4_array$_4_ui256_$_Memory_$_$_Memory_$
// CHECK:         yul.for
// CHECK:           %[[CD_ROW:.*]] = yul.add %arg0
// CHECK:           %[[MEM_ROW:.*]] = yul.mload %c64_i256
// CHECK:           %[[CD_SIZE:.*]] = yul.mul %c4_i256{{.*}}, %c32_i256
// CHECK-NEXT:      yul.calldatacopy %[[MEM_ROW]], %[[CD_ROW]], %[[CD_SIZE]]
// CHECK-NEXT:      yul.mstore {{.*}}, %[[MEM_ROW]]
// CHECK-NOT:     yul.calldataload
// CHECK:         yul.func_return

// The copying functions are calls; the flat one keeps its inline bulk copy.
// CHECK-LABEL: yul.func @cd2m_narrow
// CHECK:         yul.func_call @__sol.copy_array.calldata.memory.array$_4_ui8_$_CallData_$.array$_4_ui8_$_Memory_$(%arg0, %arg1)
// CHECK-NEXT:    yul.func_return

// A flat word array is one calldatacopy and gets no helper: it stays in the
// function itself.
// CHECK-LABEL: yul.func @cd2m_flat
// CHECK-NOT:     yul.for
// CHECK-NOT:     yul.func_call
// CHECK:         %[[FLAT_SIZE:.*]] = yul.mul %c4_i256{{.*}}, %c32_i256
// CHECK-NEXT:    yul.calldatacopy %arg1, %arg0, %[[FLAT_SIZE]]
// CHECK-NEXT:    yul.func_return
