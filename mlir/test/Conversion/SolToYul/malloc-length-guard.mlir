// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A sized bytes or string allocation panics (0x41) on a length above 2^64 - 1
// before it reads the free memory pointer. The rounded size of a huge length
// wraps mod 2^256, so the free memory pointer check alone misses it.

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.func @bytes
// CHECK-NEXT:  ^bb0([[LEN:%.+]]: i256):
// CHECK-NOT:     yul.mload
// CHECK:         [[MAX:%.+]] = yul.constant 18446744073709551615
// CHECK-NEXT:    [[COND:%.+]] = yul.cmp ugt, [[LEN]], [[MAX]]
// CHECK-NEXT:    yul.if [[COND]] {
// CHECK:           yul.constant 65
// CHECK:           yul.revert
// CHECK:         } else {
// CHECK:         yul.mload
// CHECK:         yul.calldatacopy
// CHECK:         yul.func_return
sol.contract @Bytes {
  sol.func @bytes(%arg0: ui256) attributes {orig_fn_type = (ui256) -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %0 = sol.malloc %arg0 zero_init : ui256 !sol.string<Memory>
    sol.return
  }
} {kind = #Contract}
