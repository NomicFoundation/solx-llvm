// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The upcast is a no-op on the address.
// CHECK-LABEL: yul.func @b_to_a : (i256) -> i256
// CHECK-NEXT:  ^bb0(%[[B:.*]]: i256):
// CHECK-NEXT:    yul.func_return %[[B]] : i256

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @b_to_a(%b: !sol.contract<"B">) -> !sol.contract<"A"> {
    %0 = sol.contract_cast %b : <"B"> to <"A">
    sol.return %0 : !sol.contract<"A">
  }
}
