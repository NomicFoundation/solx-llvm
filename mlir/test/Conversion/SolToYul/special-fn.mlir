// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// After the selector switch: empty calldata goes to receive, anything else to
// the non-payable fallback.

// CHECK-LABEL: yul.object @C_13 {
// CHECK-LABEL:   yul.object @C_13_deployed {
// CHECK:           yul.switch
// CHECK:           case 638722032 {
// CHECK:             yul.func_call @f_4() : () -> ()
// CHECK:           %[[CDS:.*]] = yul.calldatasize
// CHECK:           %[[EMPTY:.*]] = yul.cmp eq, %[[CDS]], %c0_i256
// CHECK:           yul.if %[[EMPTY]] {
// CHECK-NEXT:        yul.func_call @_8() : () -> ()
// CHECK-NEXT:        yul.stop
// CHECK:           %[[CV:.*]] = yul.callvalue
// CHECK:           %[[PAID:.*]] = yul.cmp ne, %[[CV]], %c0_i256
// CHECK:           yul.if %[[PAID]] {
// CHECK:             yul.revert
// CHECK:           yul.func_call @_12() : () -> ()
// CHECK-NEXT:      yul.stop
// CHECK-LABEL:     yul.func @_12 : () -> ()
// CHECK-LABEL:     yul.func @_8 : () -> ()
// CHECK-LABEL:     yul.func @f_4 : () -> ()

// A (bytes) -> bytes fallback takes the whole calldata and returns its memory
// result as the returndata.
// CHECK-LABEL: yul.object @A_deployed {
// CHECK-NOT:     yul.switch
// CHECK:         %[[SIZE:.*]] = yul.calldatasize
// CHECK:         %[[Z:.*]] = yul.constant 0
// CHECK:         %[[EMPTY:.*]] = yul.cmp eq, %[[SIZE]], %[[Z]]
// CHECK:         yul.if %[[EMPTY]] {
// CHECK-NEXT:      yul.func_call @receive() : () -> ()
// CHECK-NEXT:      yul.stop
// CHECK:         yul.callvalue
// CHECK:         %[[SIZE2:.*]] = yul.calldatasize
// CHECK:         %[[Z2:.*]] = yul.constant 0
// CHECK:         %[[IN0:.*]] = llvm.insertvalue %[[Z2]], %{{.*}}[0]
// CHECK:         %[[IN:.*]] = llvm.insertvalue %[[SIZE2]], %[[IN0]][1]
// CHECK:         %[[OUT:.*]] = yul.func_call @fallback(%[[IN]]) : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         %[[DATA:.*]] = yul.add %[[OUT]],
// CHECK:         %[[LEN:.*]] = yul.mload %[[OUT]]
// CHECK:         yul.return %[[DATA]], %[[LEN]]
// CHECK-LABEL:   yul.func @receive : () -> ()
// CHECK-LABEL:   yul.func @fallback : (!llvm.struct<(i256, i256)>) -> i256

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Fallback = #sol<FunctionKind Fallback>
#NonPayable = #sol<StateMutability NonPayable>
#Payable = #sol<StateMutability Payable>
#Receive = #sol<FunctionKind Receive>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @C_13 {
    sol.func @C_13() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f_4() attributes {id = 4 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @_8() attributes {id = 8 : i64, kind = #Receive, state_mutability = #Payable} {
      sol.return
    }
    sol.func @_12() attributes {id = 12 : i64, kind = #Fallback, state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract}
  sol.contract @A {
    sol.func @fallback(%arg0: !sol.string<CallData>) -> !sol.string<Memory> attributes {kind = #Fallback, state_mutability = #NonPayable} {
      %0 = sol.malloc : !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
    sol.func @receive() attributes {kind = #Receive, state_mutability = #Payable} {
      sol.return
    }
  } {kind = #Contract}
}
