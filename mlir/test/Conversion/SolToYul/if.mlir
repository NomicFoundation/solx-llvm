// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @if_else
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK:         %[[C:.*]] = yul.cmp eq, %[[A]], %[[B]]
// CHECK:         yul.if %[[C]] {
// CHECK-NEXT:      yul.func_call @g(%[[A]])
// CHECK-NEXT:      yul.yield
// CHECK-NEXT:    } else {
// CHECK-NEXT:      yul.func_call @g(%[[B]])
// CHECK-NEXT:      yul.yield
// CHECK-NEXT:    }

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @g(%x: ui256) {
    sol.return
  }
  sol.func @if_else(%a: ui256, %b: ui256) {
    %0 = sol.cmp eq, %a, %b : ui256
    sol.if %0 {
      sol.call @g(%a) : (ui256) -> ()
      sol.yield
    } else {
      sol.call @g(%b) : (ui256) -> ()
      sol.yield
    }
    sol.return
  }
}
