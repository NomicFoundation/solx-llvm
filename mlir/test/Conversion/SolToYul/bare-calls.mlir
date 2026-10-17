// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @call : (i256, i256, i256, i256) -> (i256, i256)
    // CHECK:         %[[LEN:.*]] = yul.mload %arg1
    // CHECK:         %[[DATA:.*]] = yul.add %arg1, %c32_i256
    // CHECK:         %[[TO:.*]] = yul.and %arg0, %c1461501637330902918203684832716283019655932542975_i256
    // CHECK:         %[[OK:.*]] = yul.call %arg2, %[[TO]], %arg3, %[[DATA]], %[[LEN]], %[[C0:c0_i256[_0-9]*]], %[[C0]]
    // CHECK:         %[[ST:.*]] = yul.cmp ne, %[[OK]], %[[C0]]
    // CHECK:         %[[RDS:.*]] = yul.returndatasize
    // CHECK:         %[[RD:.*]] = yul.func_call @__sol.alloc(%{{.*}}) : (i256) -> i256
    // CHECK:         yul.mstore %[[RD]], %[[RDS]]
    // CHECK:         %[[RDP:.*]] = yul.add %[[RD]], %{{.*}}
    // CHECK:         yul.returndatacopy %[[RDP]], %[[C0]], %[[RDS]]
    // CHECK:         yul.func_return %[[ST]], %[[RD]] : i256, i256
    sol.func @call(%arg0: !sol.address, %arg1: !sol.string<Memory>, %arg2: ui256, %arg3: ui256) -> (i1, !sol.string<Memory>) {
      %status, %ret_data = sol.bare_call %arg0 gas %arg2 value %arg3 input %arg1 : !sol.address, ui256, ui256, !sol.string<Memory> -> i1, !sol.string<Memory>
      sol.return %status, %ret_data : i1, !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @delegatecall : (i256, i256, i256) -> (i256, i256)
    // CHECK:         %[[TO:.*]] = yul.and %arg0,
    // CHECK:         %[[OK:.*]] = yul.delegate_call %arg2, %[[TO]], %{{.*}}, %{{.*}}, %[[C0:c0_i256[_0-9]*]], %[[C0]]
    // CHECK:         yul.cmp ne, %[[OK]], %[[C0]]
    // CHECK:         yul.returndatacopy
    sol.func @delegatecall(%arg0: !sol.address, %arg1: !sol.string<Memory>, %arg2: ui256) -> (i1, !sol.string<Memory>) {
      %status, %ret_data = sol.bare_delegate_call %arg0 gas %arg2 input %arg1 : !sol.address, ui256, !sol.string<Memory> -> i1, !sol.string<Memory>
      sol.return %status, %ret_data : i1, !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @staticcall : (i256, i256, i256) -> (i256, i256)
    // CHECK:         %[[TO:.*]] = yul.and %arg0,
    // CHECK:         %[[OK:.*]] = yul.static_call %arg2, %[[TO]], %{{.*}}, %{{.*}}, %[[C0:c0_i256[_0-9]*]], %[[C0]]
    // CHECK:         yul.cmp ne, %[[OK]], %[[C0]]
    // CHECK:         yul.returndatacopy
    sol.func @staticcall(%arg0: !sol.address, %arg1: !sol.string<Memory>, %arg2: ui256) -> (i1, !sol.string<Memory>) {
      %status, %ret_data = sol.bare_static_call %arg0 gas %arg2 input %arg1 : !sol.address, ui256, !sol.string<Memory> -> i1, !sol.string<Memory>
      sol.return %status, %ret_data : i1, !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
