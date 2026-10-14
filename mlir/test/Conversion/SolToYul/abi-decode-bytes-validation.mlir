// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  // CHECK-LABEL: yul.object @C_deployed {
  // CHECK:         case 3233317909 {
  // CHECK:           %[[REF:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.string$_CallData_$(%{{.*}}, %{{.*}}) : (i256, i256) -> !llvm.struct<(i256, i256)>
  // CHECK:           yul.func_call @g(%[[REF]])
  // CHECK-LABEL: yul.func @__sol.abi_decode_calldata_slice : (i256, i256) -> !llvm.struct<(i256, i256)>
  // CHECK-NEXT:  ^bb0(%[[HEAD:.*]]: i256, %[[END:.*]]: i256):
  // CHECK:         %[[LAST:.*]] = yul.add %[[HEAD]], %{{.*}}
  // CHECK:         %[[BADHEAD:.*]] = yul.cmp sge, %[[LAST]], %[[END]]
  // CHECK:         yul.if %[[BADHEAD]] {
  // CHECK:           yul.revert
  // CHECK:         %[[LEN:.*]] = yul.calldataload %[[HEAD]]
  // CHECK:         %[[MAX:.*]] = yul.constant 18446744073709551615
  // CHECK:         %[[BADLEN:.*]] = yul.cmp ugt, %[[LEN]], %[[MAX]]
  // CHECK:         yul.if %[[BADLEN]] {
  // CHECK:         %[[DATA:.*]] = yul.add %[[HEAD]], %{{.*}}
  // CHECK:         %[[DATAEND:.*]] = yul.add %[[DATA]], %[[LEN]]
  // CHECK:         %[[BADEND:.*]] = yul.cmp ugt, %[[DATAEND]], %[[END]]
  // CHECK:         yul.if %[[BADEND]] {
  // CHECK:         llvm.insertvalue %[[DATA]], %{{.*}}[0]
  // CHECK:         llvm.insertvalue %[[LEN]], %{{.*}}[1]
  // CHECK-LABEL: yul.func @__sol.abi_decode_tuple.calldata.string$_CallData_$ : (i256, i256) -> !llvm.struct<(i256, i256)>
  // CHECK-NEXT:  ^bb0(%[[START:.*]]: i256, %[[END:.*]]: i256):
  // CHECK:         %[[OFF:.*]] = yul.calldataload %[[START]]
  // CHECK:         %[[MAX:.*]] = yul.constant 18446744073709551615
  // CHECK:         %[[BADOFF:.*]] = yul.cmp ugt, %[[OFF]], %[[MAX]]
  // CHECK:         yul.if %[[BADOFF]] {
  // CHECK:           yul.revert
  // CHECK:         %[[HEAD:.*]] = yul.add %[[START]], %[[OFF]]
  // CHECK:         yul.func_call @__sol.abi_decode_calldata_slice(%[[HEAD]], %[[END]])
  // CHECK-LABEL: yul.func @g : (!llvm.struct<(i256, i256)>) -> i256
  // CHECK:         %[[LENV:.*]] = llvm.extractvalue %arg0[1]
  // CHECK:         yul.func_return %[[LENV]] : i256
  sol.contract @C {
    sol.func @g(%arg0: !sol.string<CallData>) -> ui256 attributes {orig_fn_type = (!sol.string<CallData>) -> ui256, selector = -1061649387 : i32, state_mutability = #Pure} {
      %0 = sol.length %arg0 : !sol.string<CallData>
      sol.return %0 : ui256
    }
  } {kind = #Contract, runtime}
}
