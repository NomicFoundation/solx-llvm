// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The code is copied into a fresh length-prefixed memory buffer.
// CHECK-LABEL: yul.func @code : (i256) -> i256
// CHECK:         %[[A:.*]] = yul.and %arg0,
// CHECK:         %[[SZ:.*]] = yul.extcodesize %[[A]]
// CHECK:         %[[BUF:.*]] = yul.mload
// CHECK:         yul.mstore %[[BUF]], %[[SZ]]
// CHECK:         %[[DATA:.*]] = yul.add %[[BUF]], %{{.*}}
// CHECK:         yul.extcodecopy %[[A]], %[[DATA]], %{{.*}}, %[[SZ]]
// CHECK:         yul.func_return %[[BUF]] : i256

// CHECK-LABEL: yul.func @code_hash : (i256) -> i256
// CHECK:         %[[A:.*]] = yul.and %arg0,
// CHECK:         %[[H:.*]] = yul.extcodehash %[[A]]
// CHECK:         yul.func_return %[[H]] : i256

// CHECK-LABEL: yul.func @code_len : (i256) -> i256
// CHECK:         %[[MASK:.*]] = yul.constant 1461501637330902918203684832716283019655932542975
// CHECK:         %[[A:.*]] = yul.and %arg0, %[[MASK]]
// CHECK:         %[[SZ:.*]] = yul.extcodesize %[[A]]
// CHECK:         yul.func_return %[[SZ]] : i256

// CHECK-LABEL: yul.func @balance : (i256) -> i256
// CHECK-NEXT:  ^bb0(%[[R:.*]]: i256):
// CHECK:         %[[MASK:.*]] = yul.constant 1461501637330902918203684832716283019655932542975
// CHECK:         %[[A:.*]] = yul.and %[[R]], %[[MASK]]
// CHECK:         %[[B:.*]] = yul.balance %[[A]]
// CHECK:         yul.func_return %[[B]] : i256

// CHECK-LABEL: yul.func @kill : (i256) -> () {
// CHECK-NEXT:  ^bb0(%[[R:.*]]: i256):
// CHECK:         %[[MASK:.*]] = yul.constant 1461501637330902918203684832716283019655932542975
// CHECK:         %[[A:.*]] = yul.and %[[R]], %[[MASK]]
// CHECK:         yul.selfdestruct %[[A]]

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @code(%arg0: !sol.address) -> !sol.string<Memory> {
    %0 = sol.code %arg0 : !sol.address -> !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @code_hash(%arg0: !sol.address) -> ui256 {
    %0 = sol.code_hash %arg0 : !sol.address -> ui256
    sol.return %0 : ui256
  }
  sol.func @code_len(%arg0: !sol.address) -> ui256 {
    %0 = sol.code_size %arg0 : !sol.address -> ui256
    sol.return %0 : ui256
  }
  sol.func @balance(%arg0: !sol.address) -> ui256 {
    %0 = sol.balance %arg0 : !sol.address -> ui256
    sol.return %0 : ui256
  }
  sol.func @kill(%arg0: !sol.address<payable>) {
    sol.selfdestruct %arg0 : !sol.address<payable>
    sol.return
  }
}
