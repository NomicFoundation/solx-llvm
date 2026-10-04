// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @balance
// CHECK-SAME:      (%[[ADDR:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[ADDR]]) <{id = {{[0-9]+}} : i32, name = "evm.balance"}> : (i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @balance : (i256) -> i256 {
^bb0(%addr: i256):
  %0 = yul.balance %addr
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @extcodehash
// CHECK-SAME:      (%[[ADDR:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[ADDR]]) <{id = {{[0-9]+}} : i32, name = "evm.extcodehash"}> : (i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @extcodehash : (i256) -> i256 {
^bb0(%addr: i256):
  %0 = yul.extcodehash %addr
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @extcodesize
// CHECK-SAME:      (%[[ADDR:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[ADDR]]) <{id = {{[0-9]+}} : i32, name = "evm.extcodesize"}> : (i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @extcodesize : (i256) -> i256 {
^bb0(%addr: i256):
  %0 = yul.extcodesize %addr
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @extcodecopy
// CHECK-SAME:      (%[[ADDR:.*]]: i256, %[[DST:.*]]: i256, %[[SRC:.*]]: i256, %[[LEN:.*]]: i256)
// CHECK-NEXT:    %[[DSTP:.*]] = llvm.inttoptr %[[DST]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[SRCP:.*]] = llvm.inttoptr %[[SRC]] : i256 to !llvm.ptr<4>
// CHECK-NEXT:    "llvm.intrcall"(%[[ADDR]], %[[DSTP]], %[[SRCP]], %[[LEN]]) <{id = {{[0-9]+}} : i32, name = "evm.extcodecopy"}> : (i256, !llvm.ptr<1>, !llvm.ptr<4>, i256) -> ()
// CHECK-NEXT:    return
yul.func @extcodecopy : (i256, i256, i256, i256) -> () {
^bb0(%addr: i256, %dst: i256, %src: i256, %len: i256):
  yul.extcodecopy %addr, %dst, %src, %len
  yul.func_return
}
