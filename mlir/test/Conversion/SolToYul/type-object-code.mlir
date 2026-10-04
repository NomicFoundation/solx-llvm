// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @creation_code
    // CHECK:         %[[SZ:.*]] = yul.datasize {obj = @A}
    // CHECK:         %[[P:.*]] = yul.mload
    // CHECK:         yul.mstore %[[P]], %[[SZ]]
    // CHECK:         %[[DST:.*]] = yul.add %[[P]], %{{.*}}
    // CHECK:         %[[OFF:.*]] = yul.dataoffset {obj = @A}
    // CHECK:         yul.codecopy %[[DST]], %[[OFF]], %[[SZ]]
    // CHECK:         yul.func_return %[[P]] : i256
    sol.func @creation_code() -> !sol.string<Memory> {
      %0 = sol.object_code "A" : !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}
