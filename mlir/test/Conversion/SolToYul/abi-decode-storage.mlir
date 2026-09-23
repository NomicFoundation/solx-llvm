// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The decode of the (uint256, bytes) tuple from memory is outlined; the site
// passes the data's start and end, the helper validates and copies.
// CHECK-LABEL: yul.func @__sol.abi_decode_tuple.memory.ui256.string$_Memory_$ : (i256, i256) -> (i256, i256)
// CHECK-NEXT:  ^bb0(%[[SRC:.*]]: i256, %[[END:.*]]: i256):
// CHECK:         %[[SIZE:.*]] = yul.sub %[[END]], %[[SRC]]
// CHECK:         %[[SHORT:.*]] = yul.cmp slt, %[[SIZE]], %{{.*}}
// CHECK:         yul.if %[[SHORT]] {
// CHECK:         %[[UINT:.*]] = yul.mload %[[SRC]]
// CHECK:         %[[OFF:.*]] = yul.mload %{{.*}}
// CHECK:         yul.cmp ugt, %[[OFF]], %{{.*}}
// CHECK:         %[[HEAD:.*]] = yul.add %[[SRC]], %[[OFF]]
// CHECK:         %[[LEN:.*]] = yul.mload %[[HEAD]]
// CHECK:         %[[BYTES:.*]] = yul.func_call @__sol.alloc
// CHECK:         yul.mstore %[[BYTES]], %[[LEN]]
// CHECK:         yul.mcopy %{{.*}}, %{{.*}}, %[[LEN]]
// CHECK:         yul.func_return %[[UINT]], %[[BYTES]] : i256, i256

// CHECK-LABEL: yul.func @f : (i256) -> (i256, i256)
// CHECK:         %[[DATA:.*]] = yul.add %arg0, %{{.*}}
// CHECK:         %[[DLEN:.*]] = yul.mload %arg0
// CHECK:         %[[DEND:.*]] = yul.add %[[DATA]], %[[DLEN]]
// CHECK:         %[[R:.*]]:2 = yul.func_call @__sol.abi_decode_tuple.memory.ui256.string$_Memory_$(%[[DATA]], %[[DEND]])
// CHECK:         yul.func_return %[[R]]#0, %[[R]]#1 : i256, i256

module {
  sol.contract @C {
    sol.func @f(%arg0: !sol.string<Memory>) -> (ui256, !sol.string<Memory>) {
      %0:2 = sol.decode %arg0 : !sol.string<Memory> -> ui256, !sol.string<Memory>
      sol.return %0#0, %0#1 : ui256, !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
