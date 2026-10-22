// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Storage references cross the library ABI as bare slot numbers.

// CHECK-LABEL: yul.object @L_deployed {
// CHECK-LABEL: yul.func @__sol.abi_decode_tuple.calldata.i256 : (i256, i256) -> i256
// CHECK-NEXT:  ^bb0(%[[HEAD:.*]]: i256, %{{.*}}: i256):
// CHECK:         %[[WORD:.*]] = yul.calldataload %[[HEAD]]
// CHECK:         yul.func_return %[[WORD]] : i256

// CHECK-LABEL: yul.func @__sol.index_storage_array.array$_dyn_ui256_$_Storage_$ : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK-NEXT:  ^bb0(%[[SLOT:.*]]: i256, %{{.*}}: i256):
// CHECK:         yul.sload %[[SLOT]]
// CHECK:         yul.mstore %{{.*}}, %[[SLOT]]
// CHECK:         yul.keccak256

// CHECK-LABEL: yul.func @f : (i256) -> i256
// CHECK-NEXT:  ^bb0(%[[RV:.*]]: i256):
// CHECK:         yul.func_call @__sol.index_storage_array.array$_dyn_ui256_$_Storage_$(%[[RV]], %{{.*}})
// CHECK:         yul.sload

// CHECK:         case 3865590979 {
// CHECK:           %[[C4:.*]] = yul.constant 4
// CHECK:           %[[R:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.i256(%[[C4]], %{{.*}}) : (i256, i256) -> i256
// CHECK:           yul.func_call @f(%[[R]]) : (i256) -> i256

#Library = #sol<ContractKind Library>
#View = #sol<StateMutability View>
module {
  sol.contract @L {
    sol.func @f(%arg0: !sol.array<? x ui256, Storage>) -> ui256 attributes {orig_fn_type = (!sol.array<? x ui256, Storage>) -> ui256, selector = -429376317 : i32, state_mutability = #View} {
      %c0_ui8 = sol.constant 0 : ui8
      %0 = sol.gep %arg0, %c0_ui8 : !sol.array<? x ui256, Storage>, ui8, !sol.ptr<ui256, Storage>
      %1 = sol.load %0 : !sol.ptr<ui256, Storage>, ui256
      sol.return %1 : ui256
    }
  } {kind = #Library, runtime}
}

// -----

// CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.i256 : (i256, i256) -> i256
// CHECK-NEXT:  ^bb0(%[[V:.*]]: i256, %[[AT:.*]]: i256):
// CHECK:         yul.mstore %[[AT]], %[[V]]

// CHECK-LABEL: yul.func @g : () -> i256
// CHECK:         %[[LIB:.*]] = yul.linkersymbol "library-storage-ref-abi.sol:L"
// CHECK:         %[[RSLOT:.*]] = yul.constant 2
// CHECK:         yul.constant 3865590979
// CHECK:         %[[ARGS:.*]] = yul.add %{{.*}}, %{{.*}}
// CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.i256(%[[RSLOT]], %[[ARGS]])
// CHECK:         yul.delegate_call

#Contract = #sol<ContractKind Contract>
#View = #sol<StateMutability View>
module {
  sol.contract @C {
    sol.state_var @r slot 2 offset 0 : !sol.array<? x ui256, Storage>
    sol.func @g() -> ui256 attributes {state_mutability = #View} {
      %0 = sol.lib_addr "library-storage-ref-abi.sol:L" : !sol.address
      %1 = sol.addr_of @r : !sol.array<? x ui256, Storage>
      %c3865590979_ui256 = sol.constant 3865590979 : ui256
      %2 = sol.gasleft : ui256
      %c0_ui256 = sol.constant 0 : ui256
      %status, %outs = sol.ext_call "f"(%1) at %0 gas %2 value %c0_ui256 selector %c3865590979_ui256 {callee_type = (!sol.array<? x ui256, Storage>) -> ui256, delegate_call, library_call, static_call} : !sol.address, (!sol.array<? x ui256, Storage>) -> (i1, ui256)
      sol.return %outs : ui256
    }
  } {kind = #Contract, runtime}
}
