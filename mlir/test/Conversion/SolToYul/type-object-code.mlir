// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @creation_code
// CHECK:         %[[SZ:.*]] = yul.datasize {obj = @A}
// CHECK:         %[[P:.*]] = yul.mload
// CHECK:         yul.mstore %[[P]], %[[SZ]]
// CHECK:         %[[DST:.*]] = yul.add %[[P]], %{{.*}}
// CHECK:         %[[OFF:.*]] = yul.dataoffset {obj = @A}
// CHECK:         yul.codecopy %[[DST]], %[[OFF]], %[[SZ]]
// CHECK:         yul.func_return %[[P]] : i256

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @creation_code() -> !sol.string<Memory> {
    %0 = sol.object_code "A" : !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
}
