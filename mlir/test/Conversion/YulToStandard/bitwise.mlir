// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @and
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = arith.andi %[[A]], %[[B]] : i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @and : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.and %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @or
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = arith.ori %[[A]], %[[B]] : i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @or : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.or %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @xor
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = arith.xori %[[A]], %[[B]] : i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @xor : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.xor %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @not
// CHECK-SAME:      (%[[A:.*]]: i256) -> i256
// CHECK-NEXT:    %[[ONES:.*]] = arith.constant -1 : i256
// CHECK-NEXT:    %[[V:.*]] = arith.xori %[[A]], %[[ONES]] : i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @not : (i256) -> i256 {
^bb0(%a: i256):
  %0 = yul.not %a
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @shl
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[A]], %[[B]]) <{id = {{[0-9]+}} : i32, name = "evm.shl"}> : (i256, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @shl : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.shl %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @shr
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[A]], %[[B]]) <{id = {{[0-9]+}} : i32, name = "evm.shr"}> : (i256, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @shr : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.shr %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @sar
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[A]], %[[B]]) <{id = {{[0-9]+}} : i32, name = "evm.sar"}> : (i256, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @sar : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.sar %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @clz
// CHECK-SAME:      (%[[X:.*]]: i256) -> i256
// CHECK:         %[[R:.*]] = "llvm.intr.ctlz"(%[[X]]) <{is_zero_poison = false}> : (i256) -> i256
// CHECK:         return %[[R]] : i256
yul.func @clz : (i256) -> i256 {
^bb0(%x: i256):
  %0 = yul.clz %x
  yul.func_return %0 : i256
}
