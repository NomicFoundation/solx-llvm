// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @create
// CHECK-SAME:      (%[[VAL:.*]]: i256, %[[OFF:.*]]: i256, %[[SZ:.*]]: i256) -> i256
// CHECK-NEXT:    %[[CODE:.*]] = llvm.inttoptr %[[OFF]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[VAL]], %[[CODE]], %[[SZ]]) <{id = {{[0-9]+}} : i32, name = "evm.create"}> : (i256, !llvm.ptr<1>, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @create : (i256, i256, i256) -> i256 {
^bb0(%val: i256, %off: i256, %sz: i256):
  %0 = yul.create %val, %off, %sz
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @create2
// CHECK-SAME:      (%[[VAL:.*]]: i256, %[[OFF:.*]]: i256, %[[SZ:.*]]: i256, %[[SALT:.*]]: i256) -> i256
// CHECK-NEXT:    %[[CODE:.*]] = llvm.inttoptr %[[OFF]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[VAL]], %[[CODE]], %[[SZ]], %[[SALT]]) <{id = {{[0-9]+}} : i32, name = "evm.create2"}> : (i256, !llvm.ptr<1>, i256, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @create2 : (i256, i256, i256, i256) -> i256 {
^bb0(%val: i256, %off: i256, %sz: i256, %salt: i256):
  %0 = yul.create2 %val, %off, %sz, %salt
  yul.func_return %0 : i256
}
