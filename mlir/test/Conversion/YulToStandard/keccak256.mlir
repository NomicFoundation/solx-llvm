// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @keccak256
// CHECK-SAME:      (%[[OFF:.*]]: i256, %[[LEN:.*]]: i256) -> i256
// CHECK-NEXT:    %[[P:.*]] = llvm.inttoptr %[[OFF]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[P]], %[[LEN]]) <{id = {{[0-9]+}} : i32, name = "evm.sha3"}> : (!llvm.ptr<1>, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256

yul.func @keccak256 : (i256, i256) -> i256 {
^bb0(%off: i256, %len: i256):
  %0 = yul.keccak256 %off, %len
  yul.func_return %0 : i256
}
