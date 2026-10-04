// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @ret : () -> i256
    // CHECK-NEXT:    %[[C:.*]] = yul.constant 42
    // CHECK-NEXT:    yul.func_return %[[C]] : i256
    sol.func @ret() -> ui256 {
      %c42_ui256 = sol.constant 42 : ui256
      sol.return %c42_ui256 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @no_ret : (i256) -> ()
    // CHECK:         yul.func_return{{$}}
    sol.func @no_ret(%arg0: ui256) {
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    sol.func @ret() -> ui256 {
      %c42_ui256 = sol.constant 42 : ui256
      sol.return %c42_ui256 : ui256
    }

    sol.func @no_ret(%arg0: ui256) {
      sol.return
    }

    // CHECK-LABEL: yul.func @main : (i256) -> i256
    // CHECK:         yul.func_call @no_ret(%arg0) : (i256) -> ()
    // CHECK-NEXT:    %[[R:.*]] = yul.func_call @ret() : () -> i256
    // CHECK-NEXT:    yul.func_return %[[R]] : i256
    sol.func @main(%arg0: ui256) -> ui256 {
      sol.call @no_ret(%arg0) : (ui256) -> ()
      %0 = sol.call @ret() : () -> ui256
      sol.return %0 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
