// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A default mapping reference is slot 0.
// CHECK-LABEL: yul.func @get : () -> i256
// CHECK-NEXT:    %[[V:.*]] = yul.constant 0
// CHECK-NEXT:    yul.func_return %[[V]] : i256

#Default = #sol<RevertStrings Default>
#View = #sol<StateMutability View>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @get() -> !sol.mapping<ui256, ui256> attributes {state_mutability = #View} {
    %0 = sol.default_storage : !sol.mapping<ui256, ui256>
    sol.return %0 : !sol.mapping<ui256, ui256>
  }
}
