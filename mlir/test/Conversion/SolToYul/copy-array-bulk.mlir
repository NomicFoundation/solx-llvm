// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// An array copy between memory and calldata whose elements are 256-bit
// integers or bytes32 is one calldatacopy or mcopy of the payload. A nested
// array copies one row at a time. Narrow elements need cleanup and keep the
// word loop. The same holds for the ABI decoder and encoder of such arrays.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @cd2m_nested(%arg0: !sol.array<4 x !sol.array<4 x ui256, CallData>, CallData>, %arg1: !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>) attributes {orig_fn_type = (!sol.array<4 x !sol.array<4 x ui256, CallData>, CallData>, !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>) -> (), selector = 1 : i32, state_mutability = #Pure} {
      sol.copy %arg0, %arg1 : !sol.array<4 x !sol.array<4 x ui256, CallData>, CallData>, !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>
      sol.return
    }
    sol.func @cd2m_flat(%arg0: !sol.array<4 x ui256, CallData>, %arg1: !sol.array<4 x ui256, Memory>) attributes {orig_fn_type = (!sol.array<4 x ui256, CallData>, !sol.array<4 x ui256, Memory>) -> (), selector = 2 : i32, state_mutability = #Pure} {
      sol.copy %arg0, %arg1 : !sol.array<4 x ui256, CallData>, !sol.array<4 x ui256, Memory>
      sol.return
    }
    sol.func @cd2m_signed(%arg0: !sol.array<4 x si256, CallData>, %arg1: !sol.array<4 x si256, Memory>) attributes {orig_fn_type = (!sol.array<4 x si256, CallData>, !sol.array<4 x si256, Memory>) -> (), selector = 3 : i32, state_mutability = #Pure} {
      sol.copy %arg0, %arg1 : !sol.array<4 x si256, CallData>, !sol.array<4 x si256, Memory>
      sol.return
    }
    sol.func @cd2m_bytes32(%arg0: !sol.array<4 x !sol.fixedbytes<32>, CallData>, %arg1: !sol.array<4 x !sol.fixedbytes<32>, Memory>) attributes {orig_fn_type = (!sol.array<4 x !sol.fixedbytes<32>, CallData>, !sol.array<4 x !sol.fixedbytes<32>, Memory>) -> (), selector = 4 : i32, state_mutability = #Pure} {
      sol.copy %arg0, %arg1 : !sol.array<4 x !sol.fixedbytes<32>, CallData>, !sol.array<4 x !sol.fixedbytes<32>, Memory>
      sol.return
    }
    sol.func @m2m_nested(%arg0: !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>, %arg1: !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>) attributes {orig_fn_type = (!sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>, !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>) -> (), selector = 5 : i32, state_mutability = #Pure} {
      sol.copy %arg0, %arg1 : !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>, !sol.array<4 x !sol.array<4 x ui256, Memory>, Memory>
      sol.return
    }
    sol.func @cd2m_narrow(%arg0: !sol.array<4 x ui8, CallData>, %arg1: !sol.array<4 x ui8, Memory>) attributes {orig_fn_type = (!sol.array<4 x ui8, CallData>, !sol.array<4 x ui8, Memory>) -> (), selector = 6 : i32, state_mutability = #Pure} {
      sol.copy %arg0, %arg1 : !sol.array<4 x ui8, CallData>, !sol.array<4 x ui8, Memory>
      sol.return
    }
    sol.func @ret(%arg0: !sol.array<4 x ui256, Memory>) -> !sol.array<4 x ui256, Memory> attributes {orig_fn_type = (!sol.array<4 x ui256, Memory>) -> !sol.array<4 x ui256, Memory>, selector = 7 : i32, state_mutability = #Pure} {
      sol.return %arg0 : !sol.array<4 x ui256, Memory>
    }
  } {kind = #Contract, runtime}
}

// The dispatcher decodes a word array parameter with one calldatacopy and
// encodes a word array result with one mcopy.
// CHECK-LABEL: yul.object @C_deployed
// CHECK:         case 2 {
// CHECK-NOT:       yul.for
// CHECK:           yul.calldatacopy
// CHECK-NOT:       yul.for
// CHECK:           yul.func_call @cd2m_flat
// CHECK:         case 7 {
// CHECK-NOT:       yul.for
// CHECK:           yul.calldatacopy
// CHECK-NOT:       yul.for
// CHECK:           %[[RET:.*]] = yul.func_call @ret
// CHECK-NOT:       yul.for
// CHECK:           yul.mcopy %{{.*}}, %[[RET]]
// CHECK-NOT:       yul.for
// CHECK:           yul.return

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

// CHECK-LABEL: yul.func @cd2m_bytes32
// CHECK-NOT:     yul.for
// CHECK:         yul.calldatacopy %arg1, %arg0
// CHECK-NEXT:    yul.func_return

// CHECK-LABEL: yul.func @cd2m_signed
// CHECK-NOT:     yul.for
// CHECK:         yul.calldatacopy %arg1, %arg0
// CHECK-NEXT:    yul.func_return

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
