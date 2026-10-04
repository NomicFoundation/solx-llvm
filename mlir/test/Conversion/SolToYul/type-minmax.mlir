// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @uint8_max : () -> i256
// CHECK:         %[[V:.*]] = yul.constant 255
// CHECK:         yul.func_return %[[V]] : i256

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @uint8_max() -> ui8 {
    %c-1_ui8 = sol.constant 255 : ui8
    sol.return %c-1_ui8 : ui8
  }
}
