// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Decoded bool[] elements are validated; the returned bool is normalized.
// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         case 114889333 {
// CHECK:           %[[ARR:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.array$_dyn_i1_$_Memory_$(
// CHECK:           %[[R:.*]] = yul.func_call @mem_bool(%[[ARR]]) : (i256) -> i256
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.i1(%[[R]],

// CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.i1 : (i256, i256) -> i256
// CHECK:         %[[RB:.*]] = yul.cmp ne, %arg0, %{{.*}}
// CHECK:         yul.mstore %arg1, %[[RB]]

// CHECK-LABEL: yul.func @__sol.abi_decode.calldata.memory.array$_dyn_i1_$_Memory_$
// CHECK:         yul.for
// CHECK:           %[[V:.*]] = yul.calldataload %{{.*}}
// CHECK:           %[[B:.*]] = yul.cmp ne, %[[V]], %{{.*}}
// CHECK:           %[[BAD:.*]] = yul.cmp ne, %[[V]], %[[B]]
// CHECK:           yul.if %[[BAD]] {
// CHECK:             yul.revert
// CHECK:           yul.mstore %{{.*}}, %[[B]]

// CHECK-LABEL: yul.func @mem_bool : (i256) -> i256
// CHECK:         yul.cmp uge
// CHECK:         yul.func_call @__sol.panic
// CHECK-NEXT:    yul.unreachable
// CHECK:         %[[V:.*]] = yul.mload
// CHECK-NOT:     yul.cmp ne
// CHECK:         yul.func_return %[[V]] : i256

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    sol.func @mem_bool(%arg0: !sol.array<? x i1, Memory>) -> i1 attributes {orig_fn_type = (!sol.array<? x i1, Memory>) -> i1, selector = 114889333 : i32, state_mutability = #NonPayable} {
      %c0_ui8 = sol.constant 0 : ui8
      %0 = sol.gep %arg0, %c0_ui8 : !sol.array<? x i1, Memory>, ui8, !sol.ptr<i1, Memory>
      %1 = sol.load %0 : !sol.ptr<i1, Memory>, i1
      sol.return %1 : i1
    }
  } {kind = #Contract, runtime}
}

// -----

// CHECK-LABEL: yul.func @__sol.abi_encode_array.memory.padded.tail.array$_dyn_i1_$_Memory_$
// CHECK:         yul.for
// CHECK:           %[[V:.*]] = yul.mload
// CHECK:           %[[B:.*]] = yul.cmp ne, %[[V]], %{{.*}}
// CHECK:           yul.mstore %{{.*}}, %[[B]]
// CHECK-LABEL: yul.func @encode_array_bool : (i256) -> i256
// CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_dyn_i1_$_Memory_$(%arg0,

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    sol.func @encode_array_bool(%arg0: !sol.array<? x i1, Memory>) -> !sol.string<Memory> attributes {state_mutability = #NonPayable} {
      %0 = sol.encode %arg0 : (!sol.array<? x i1, Memory>) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #Contract}
}
