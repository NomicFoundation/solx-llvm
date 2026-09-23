// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A memory allocation whose size is not a constant goes through the
// contract's one `__sol.alloc`, which rounds the size up, checks the new free
// pointer and advances it. A constant size allocates inline, where the checks
// fold.
//
// The size-less `sol.malloc` is written in the generic form because its
// custom printer does not round-trip.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @dynamic(%arg0: ui256) -> !sol.array<? x ui256, Memory> attributes {orig_fn_type = (ui256) -> !sol.array<? x ui256, Memory>, selector = 1 : i32, state_mutability = #Pure} {
      %0 = sol.malloc %arg0 zero_init : ui256 !sol.array<? x ui256, Memory>
      sol.return %0 : !sol.array<? x ui256, Memory>
    }
    sol.func @constant() -> !sol.array<3 x ui256, Memory> attributes {orig_fn_type = () -> !sol.array<3 x ui256, Memory>, selector = 2 : i32, state_mutability = #Pure} {
      %0 = "sol.malloc"() <{zero_init}> : () -> !sol.array<3 x ui256, Memory>
      sol.return %0 : !sol.array<3 x ui256, Memory>
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed
// CHECK-LABEL:   yul.func @__sol.alloc : (i256) -> i256
// CHECK:           %[[FREE:.*]] = yul.mload %c64
// CHECK:           %[[NEW:.*]] = yul.add %[[FREE]]
// CHECK:           yul.cmp ugt, %[[NEW]], %c18446744073709551615
// CHECK:           yul.cmp ult, %[[NEW]], %[[FREE]]
// CHECK:           yul.func_call @__sol.panic(%c65
// CHECK:           yul.mstore %c64{{.*}}, %[[NEW]]
// CHECK:           yul.func_return %[[FREE]]
// CHECK-LABEL:   yul.func @constant
// CHECK-NOT:       yul.func_call @__sol.alloc
// CHECK:           yul.mload %c64
// CHECK:           yul.mstore %c64
// CHECK-NOT:       yul.func_call @__sol.alloc
// CHECK:           yul.func_return
// CHECK-LABEL:   yul.func @dynamic
// CHECK-NOT:       yul.mstore %c64
// CHECK:           %[[PTR:.*]] = yul.func_call @__sol.alloc(%{{.*}}) : (i256) -> i256
// CHECK-NOT:       yul.mstore %c64
// CHECK:           yul.func_return %[[PTR]]
