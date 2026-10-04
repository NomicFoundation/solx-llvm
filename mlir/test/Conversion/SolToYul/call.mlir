// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @ret : () -> i256
// CHECK-NEXT:    %[[C:.*]] = yul.constant 42
// CHECK-NEXT:    yul.func_return %[[C]] : i256

// CHECK-LABEL: yul.func @no_ret : (i256) -> ()
// CHECK:         yul.func_return{{$}}

// CHECK-LABEL: yul.func @main : (i256) -> i256
// CHECK:         yul.func_call @no_ret(%arg0) : (i256) -> ()
// CHECK-NEXT:    %[[R:.*]] = yul.func_call @ret() : () -> i256
// CHECK-NEXT:    yul.func_return %[[R]] : i256

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @ret() -> ui256 {
    %c42_ui256 = sol.constant 42 : ui256
    sol.return %c42_ui256 : ui256
  }
  sol.func @no_ret(%arg0: ui256) {
    sol.return
  }
  sol.func @main(%arg0: ui256) -> ui256 {
    sol.call @no_ret(%arg0) : (ui256) -> ()
    %0 = sol.call @ret() : () -> ui256
    sol.return %0 : ui256
  }
}
