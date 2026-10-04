// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         case 3233317909 {
// CHECK:           %[[OFF:.*]] = yul.calldataload
// CHECK:           %[[MAX:.*]] = yul.constant 18446744073709551615
// CHECK:           %[[BADOFF:.*]] = yul.cmp ugt, %[[OFF]], %[[MAX]]
// CHECK:           yul.if %[[BADOFF]] {
// CHECK:             yul.revert
// CHECK:           %[[HEAD:.*]] = yul.add %{{.*}}, %[[OFF]]
// CHECK:           %[[LAST:.*]] = yul.add %[[HEAD]], %{{.*}}
// CHECK:           %[[BADHEAD:.*]] = yul.cmp sge, %[[LAST]], %{{.*}}
// CHECK:           yul.if %[[BADHEAD]] {
// CHECK:           %[[LEN:.*]] = yul.calldataload %[[HEAD]]
// CHECK:           %[[BADLEN:.*]] = yul.cmp ugt, %[[LEN]], %{{.*}}
// CHECK:           yul.if %[[BADLEN]] {
// CHECK:           %[[DATA:.*]] = yul.add %[[HEAD]], %{{.*}}
// CHECK:           %[[END:.*]] = yul.add %[[DATA]], %[[LEN]]
// CHECK:           %[[BADEND:.*]] = yul.cmp ugt, %[[END]], %{{.*}}
// CHECK:           yul.if %[[BADEND]] {
// CHECK:           yul.func_call @g
// CHECK-LABEL: yul.func @g : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         %[[LENV:.*]] = llvm.extractvalue %arg0[1]
// CHECK:         yul.func_return %[[LENV]] : i256

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @g(%arg0: !sol.string<CallData>) -> ui256 attributes {orig_fn_type = (!sol.string<CallData>) -> ui256, selector = -1061649387 : i32, state_mutability = #Pure} {
      %0 = sol.length %arg0 : !sol.string<CallData>
      sol.return %0 : ui256
    }
  } {kind = #Contract}
}
