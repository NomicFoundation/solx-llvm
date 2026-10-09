// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Function pointer arrays are zeroed by a store per slot, internal and
// external alike. Other value types are zeroed by one copy from past the end
// of calldata.

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.func @internal
// CHECK-NOT:     yul.calldatacopy
// CHECK:         yul.for
// CHECK:         body {
// CHECK-NEXT:    ^bb0([[OFF:%.+]]: i256):
// CHECK-NEXT:      [[SLOT:%.+]] = yul.add [[DATA:%.+]], [[OFF]]
// CHECK-NEXT:      [[ZERO:%.+]] = yul.constant 0
// CHECK-NEXT:      yul.mstore [[SLOT]], [[ZERO]]
// CHECK:         } step {
// CHECK-NEXT:    ^bb0([[CUR:%.+]]: i256):
// CHECK-NEXT:      yul.add [[CUR]], %c32
// CHECK-NOT:     yul.calldatacopy
// CHECK:         yul.func_return
sol.contract @Internal {
  sol.func @internal(%arg0: ui256) attributes {orig_fn_type = (ui256) -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %0 = sol.malloc %arg0 zero_init : ui256 !sol.array<? x !sol.func_ref<() -> ui256>, Memory>
    sol.return
  }
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.func @external
// CHECK-NOT:     yul.calldatacopy
// CHECK:         yul.for
// CHECK:         body {
// CHECK-NEXT:    ^bb0([[OFF:%.+]]: i256):
// CHECK-NEXT:      [[SLOT:%.+]] = yul.add [[DATA:%.+]], [[OFF]]
// CHECK-NEXT:      [[ZERO:%.+]] = yul.constant 0
// CHECK-NEXT:      yul.mstore [[SLOT]], [[ZERO]]
// CHECK-NOT:     yul.calldatacopy
// CHECK:         yul.func_return
sol.contract @External {
  sol.func @external(%arg0: ui256) attributes {orig_fn_type = (ui256) -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %0 = sol.malloc %arg0 zero_init : ui256 !sol.array<? x !sol.ext_func_ref<() -> ui256>, Memory>
    sol.return
  }
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.func @integer
// CHECK-NOT:     yul.for
// CHECK:         yul.calldatacopy
// CHECK-NOT:     yul.for
// CHECK:         yul.func_return
sol.contract @Integer {
  sol.func @integer(%arg0: ui256) attributes {orig_fn_type = (ui256) -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %0 = sol.malloc %arg0 zero_init : ui256 !sol.array<? x ui256, Memory>
    sol.return
  }
} {kind = #Contract}
