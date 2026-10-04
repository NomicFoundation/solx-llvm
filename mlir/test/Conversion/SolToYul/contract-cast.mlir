// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The upcast is a no-op on the address.
// CHECK-LABEL: yul.func @b_to_a : (i256) -> i256
// CHECK-NEXT:  ^bb0(%[[B:.*]]: i256):
// CHECK-NEXT:    yul.func_return %[[B]] : i256

module {
  sol.contract @C {
    sol.func @b_to_a(%b: !sol.contract<"B">) -> !sol.contract<"A"> {
      %0 = sol.contract_cast %b : <"B"> to <"A">
      sol.return %0 : !sol.contract<"A">
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
