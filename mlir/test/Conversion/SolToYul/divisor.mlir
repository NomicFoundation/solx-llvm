// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// CHECK-LABEL: yul.func @modular
// CHECK:         [[IS_ZERO:%.+]] = yul.cmp eq, %arg2, %c0
// CHECK-NEXT:    yul.if [[IS_ZERO]] {
// CHECK:           yul.mstore %{{.+}}, %c18
// CHECK:         [[SUM:%.+]] = yul.add %arg0, %arg1
// CHECK-NOT:     yul.cmp eq
// CHECK:         [[ADDED:%.+]] = yul.addmod [[SUM]], %arg1, %arg2
// CHECK-NEXT:    yul.mulmod [[ADDED]], %arg1, %arg2
sol.contract @Modular {
  sol.func @modular(%x: ui256, %y: ui256, %mod: ui256) -> ui256 attributes {orig_fn_type = (ui256, ui256, ui256) -> ui256, selector = 1 : i32, state_mutability = #Pure} {
    %divisor = sol.divisor %mod : ui256
    %sum = sol.cadd %x, %y : ui256
    %added = sol.addmod %sum, %y, %divisor : ui256
    %multiplied = sol.mulmod %added, %y, %divisor : ui256
    sol.return %multiplied : ui256
  }
} {kind = #Contract}
