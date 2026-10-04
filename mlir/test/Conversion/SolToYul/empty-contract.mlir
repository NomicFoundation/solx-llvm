// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

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

// No functions: the runtime object has no dispatcher and always reverts.
// CHECK-LABEL:   yul.object @C_1_deployed {
// CHECK-NEXT:      %[[FMP:.*]] = yul.memoryguard 128
// CHECK-NEXT:      %[[C64:.*]] = yul.constant 64{{$}}
// CHECK-NEXT:      yul.mstore %[[C64]], %[[FMP]]
// CHECK-NEXT:      %[[Z:.*]] = yul.constant 0{{$}}
// CHECK-NEXT:      yul.revert %[[Z]], %[[Z]]
// CHECK-NEXT:    }

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @C_1 {
    sol.func @C_1() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract}
}

