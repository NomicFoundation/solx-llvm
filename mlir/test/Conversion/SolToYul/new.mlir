// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Constructor arguments are encoded after the copied creation code; a zero
// address from create/create2 bubbles up the constructor's revert data.

sol.contract @C {
  // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.ui256 : (i256, i256) -> i256
  // CHECK-NEXT:  ^bb0(%[[VAL:.*]]: i256, %[[HEAD:.*]]: i256):
  // CHECK:         yul.mstore %[[HEAD]], %[[VAL]]
  // CHECK-LABEL: yul.func @create : (i256, i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[V:.*]]: i256, %[[ARG:.*]]: i256):
  // CHECK:         %[[MEM:.*]] = yul.mload
  // CHECK:         %[[OFF:.*]] = yul.dataoffset {obj = @D}
  // CHECK:         %[[SZ:.*]] = yul.datasize {obj = @D}
  // CHECK:         yul.codecopy %[[MEM]], %[[OFF]], %[[SZ]]
  // CHECK:         %[[ARGS:.*]] = yul.add %[[MEM]], %[[SZ]]
  // CHECK:         %[[END:.*]] = yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(%[[ARG]], %[[ARGS]])
  // CHECK:         %[[LEN:.*]] = yul.sub %[[END]], %[[MEM]]
  // CHECK:         %[[ADDR:.*]] = yul.create %[[V]], %[[MEM]], %[[LEN]]
  // CHECK:         %[[FAIL:.*]] = yul.cmp eq, %[[ADDR]], %{{.*}}
  // CHECK:         yul.if %[[FAIL]] {
  // CHECK:           %[[BUF:.*]] = yul.mload
  // CHECK:           %[[RSZ:.*]] = yul.returndatasize
  // CHECK:           yul.returndatacopy %[[BUF]], %{{.*}}, %[[RSZ]]
  // CHECK:           yul.revert %[[BUF]], %[[RSZ]]
  sol.func @create(%v: ui256, %a: ui256) {
    %0 = sol.new "D" value = %v ctor(%a : ui256) : !sol.contract<"D">
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // CHECK-LABEL: yul.func @create2 : (i256, i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[V:.*]]: i256, %[[SALT:.*]]: i256):
  // CHECK:         %[[ADDR:.*]] = yul.create2 %[[V]], %{{.*}}, %{{.*}}, %[[SALT]]
  // CHECK:         %[[FAIL:.*]] = yul.cmp eq, %[[ADDR]], %{{.*}}
  // CHECK:         yul.if %[[FAIL]] {
  // CHECK:           %[[BUF:.*]] = yul.mload
  // CHECK:           %[[RSZ:.*]] = yul.returndatasize
  // CHECK:           yul.returndatacopy %[[BUF]], %{{.*}}, %[[RSZ]]
  // CHECK:           yul.revert %[[BUF]], %[[RSZ]]
  sol.func @create2(%v: ui256, %salt: ui256) {
    %0 = sol.new "D" value = %v salt = %salt ctor() : !sol.contract<"D">
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}
