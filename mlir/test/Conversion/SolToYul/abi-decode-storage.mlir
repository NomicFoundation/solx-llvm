// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @f : (i256) -> (i256, i256)
// CHECK:         %[[SRC:.*]] = yul.add %arg0, %{{.*}}
// CHECK:         %[[SIZE:.*]] = yul.sub %{{.*}}, %[[SRC]]
// CHECK:         %[[C64:.*]] = yul.constant 64
// CHECK:         %[[SHORT:.*]] = yul.cmp slt, %[[SIZE]], %[[C64]]
// CHECK:         yul.if %[[SHORT]] {
// CHECK:         %[[UINT:.*]] = yul.mload %[[SRC]]
// CHECK:         %[[OFF:.*]] = yul.mload %{{.*}}
// CHECK:         yul.cmp ugt, %[[OFF]], %{{.*}}
// CHECK:         %[[HEAD:.*]] = yul.add %[[SRC]], %[[OFF]]
// CHECK:         %[[LEN:.*]] = yul.mload %[[HEAD]]
// CHECK:         %[[BYTES:.*]] = yul.mload
// CHECK:         yul.mstore %[[BYTES]], %[[LEN]]
// CHECK:         yul.mcopy %{{.*}}, %{{.*}}, %[[LEN]]
// CHECK:         yul.func_return %[[UINT]], %[[BYTES]] : i256, i256

module {
  sol.contract @C {
    sol.func @f(%arg0: !sol.string<Memory>) -> (ui256, !sol.string<Memory>) {
      %0:2 = sol.decode %arg0 : !sol.string<Memory> -> ui256, !sol.string<Memory>
      sol.return %0#0, %0#1 : ui256, !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
