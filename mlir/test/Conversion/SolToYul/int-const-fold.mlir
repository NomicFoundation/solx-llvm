// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A signed constant wider than 64 bits is sign-extended to 256.
// CHECK-LABEL: yul.func @int72_min : () -> i256
// CHECK:         %[[C:.*]] = yul.constant -2361183241434822606848{{$}}
// CHECK:         yul.func_return %[[C]] : i256

// A cast that does not widen emits no cleanup.
// CHECK-LABEL: yul.func @same_width_cast : (i256) -> i256
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
// CHECK-NEXT:    yul.func_return %[[A]] : i256

#Default = #sol<RevertStrings Default>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @int72_min() -> si72 attributes {state_mutability = #Pure} {
    %c-2361183241434822606848_si72 = sol.constant -2361183241434822606848 : si72
    sol.return %c-2361183241434822606848_si72 : si72
  }
  sol.func @same_width_cast(%arg0: ui72) -> si72 attributes {state_mutability = #Pure} {
    %0 = sol.cast %arg0 : ui72 to si72
    sol.return %0 : si72
  }
}
