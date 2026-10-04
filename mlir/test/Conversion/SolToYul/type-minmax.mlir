// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @uint8_max : () -> i256
// CHECK:         %[[V:.*]] = yul.constant 255
// CHECK:         yul.func_return %[[V]] : i256

module {
  sol.contract @C {
    sol.func @uint8_max() -> ui8 {
      %c-1_ui8 = sol.constant 255 : ui8
      sol.return %c-1_ui8 : ui8
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
