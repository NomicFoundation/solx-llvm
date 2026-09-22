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

// The lowered helpers appear in reverse definition order.

// CHECK-LABEL: yul.func @cd2m_narrow
// CHECK:         yul.for
// CHECK:           yul.calldataload
// CHECK:           yul.mstore
// CHECK-NOT:     yul.calldatacopy
// CHECK:         yul.func_return

// CHECK-LABEL: yul.func @m2m_nested
// CHECK:         yul.for
// CHECK:           %[[SRC_ROW:.*]] = yul.mload
// CHECK-NEXT:      %[[DST_ROW:.*]] = yul.mload
// CHECK:           %[[M2M_SIZE:.*]] = yul.mul %c4_i256{{.*}}, %c32_i256
// CHECK-NEXT:      yul.mcopy %[[DST_ROW]], %[[SRC_ROW]], %[[M2M_SIZE]]
// CHECK-NOT:     yul.mstore
// CHECK:         yul.func_return

// CHECK-LABEL: yul.func @cd2m_flat
// CHECK-NOT:     yul.for
// CHECK:         %[[FLAT_SIZE:.*]] = yul.mul %c4_i256{{.*}}, %c32_i256
// CHECK-NEXT:    yul.calldatacopy %arg1, %arg0, %[[FLAT_SIZE]]
// CHECK-NEXT:    yul.func_return

// CHECK-LABEL: yul.func @cd2m_nested
// CHECK:         yul.for
// CHECK:           %[[CD_ROW:.*]] = yul.add %arg0
// CHECK:           %[[MEM_ROW:.*]] = yul.mload
// CHECK:           %[[CD_SIZE:.*]] = yul.mul %c4_i256{{.*}}, %c32_i256
// CHECK-NEXT:      yul.calldatacopy %[[MEM_ROW]], %[[CD_ROW]], %[[CD_SIZE]]
// CHECK-NOT:     yul.calldataload
// CHECK:         yul.func_return
