// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  // CHECK-LABEL: yul.object @C_1 {
  // CHECK:         %[[FMP:.*]] = yul.memoryguard 128
  // CHECK:         %[[C64:.*]] = yul.constant 64{{$}}
  // CHECK:         yul.mstore %[[C64]], %[[FMP]]
  // CHECK:         %[[CV:.*]] = yul.callvalue
  // CHECK:         %[[NZ:.*]] = yul.cmp ne, %[[CV]], %{{.*}}
  // CHECK:         yul.if %[[NZ]] {
  // CHECK:           yul.revert
  // CHECK:         yul.func_call @C_1() : () -> ()
  // CHECK:         %[[MEM:.*]] = yul.mload
  // CHECK:         %[[OFF:.*]] = yul.dataoffset {obj = @C_1_deployed}
  // CHECK:         %[[SIZE:.*]] = yul.datasize {obj = @C_1_deployed}
  // CHECK:         yul.codecopy %[[MEM]], %[[OFF]], %[[SIZE]]
  // CHECK:         yul.return %[[MEM]], %[[SIZE]]
  // CHECK-LABEL:   yul.func @C_1 : () -> ()
  // CHECK-NEXT:      yul.func_return
  sol.contract @C_1 {
    sol.func @C_1() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
module {
  // No functions: the runtime object has no dispatcher and always reverts.
  // CHECK-LABEL: yul.object @C_1_deployed {
  // CHECK-NEXT:    yul.func @__entry : () -> () {
  // CHECK-NEXT:      %[[FMP:.*]] = yul.memoryguard 128
  // CHECK-NEXT:      %[[C64:.*]] = yul.constant 64{{$}}
  // CHECK-NEXT:      yul.mstore %[[C64]], %[[FMP]]
  // CHECK-NEXT:      %[[Z:.*]] = yul.constant 0{{$}}
  // CHECK-NEXT:      yul.revert %[[Z]], %[[Z]]
  // CHECK-NEXT:      yul.func_return
  // CHECK-NEXT:    }
  // CHECK-NEXT:  }
  sol.contract @C_1 {
  } {kind = #Contract, runtime}
}
