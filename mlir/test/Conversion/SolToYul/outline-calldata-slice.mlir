// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A `bytes calldata` or `string calldata` value is decoded by the contract's
// one `__sol.abi_decode_calldata_slice`, called from the tuple decoders of
// every selector that takes one, whatever the rest of the tuple. A `bytes
// memory` parameter is copied into memory by its own decoder.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @f(%arg0: ui256, %arg1: !sol.string<CallData>) attributes {orig_fn_type = (ui256, !sol.string<CallData>) -> (), selector = 1 : i32, state_mutability = #Pure} {
      sol.return
    }
    sol.func @g(%arg0: ui64, %arg1: !sol.string<CallData>) attributes {orig_fn_type = (ui64, !sol.string<CallData>) -> (), selector = 2 : i32, state_mutability = #Pure} {
      sol.return
    }
    sol.func @m(%arg0: !sol.string<Memory>) attributes {orig_fn_type = (!sol.string<Memory>) -> (), selector = 3 : i32, state_mutability = #Pure} {
      sol.return
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.string$_Memory_$ : (i256, i256) -> i256
// CHECK-NOT:       yul.func_call @__sol.abi_decode_calldata_slice
// CHECK:           yul.calldatacopy
// CHECK-NOT:       yul.func_call @__sol.abi_decode_calldata_slice
// CHECK:           yul.func_return
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.ui64.string$_CallData_$ : (i256, i256) -> (i256, !llvm.struct<(i256, i256)>)
// CHECK:           %[[G:.*]] = yul.func_call @__sol.abi_decode_calldata_slice(%{{.*}}, %arg1) : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK:           yul.func_return %{{.*}}, %[[G]]
// CHECK-LABEL:   yul.func @__sol.abi_decode_calldata_slice : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK:           %[[LEN:.*]] = yul.calldataload %arg0
// CHECK:           yul.cmp ugt, %[[LEN]], %c18446744073709551615
// CHECK:           %[[DATA:.*]] = yul.add %arg0, %c32
// CHECK:           %[[END:.*]] = yul.add %[[DATA]], %[[LEN]]
// CHECK:           yul.cmp ugt, %[[END]], %arg1
// CHECK:           llvm.insertvalue %[[DATA]]
// CHECK:           llvm.insertvalue %[[LEN]]
// CHECK:           yul.func_return
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.ui256.string$_CallData_$ : (i256, i256) -> (i256, !llvm.struct<(i256, i256)>)
// CHECK:           %[[F:.*]] = yul.func_call @__sol.abi_decode_calldata_slice(%{{.*}}, %arg1) : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK:           yul.func_return %{{.*}}, %[[F]]
