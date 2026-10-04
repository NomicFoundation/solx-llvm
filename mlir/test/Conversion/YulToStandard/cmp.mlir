// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @cmp
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256)
// CHECK:         %[[EQ:.*]] = arith.cmpi eq, %[[A]], %[[B]] : i256
// CHECK-NEXT:    arith.extui %[[EQ]] : i1 to i256
// CHECK-NEXT:    arith.cmpi ne, %[[A]], %[[B]] : i256
// CHECK-NEXT:    arith.extui
// CHECK-NEXT:    arith.cmpi ult, %[[A]], %[[B]] : i256
// CHECK-NEXT:    arith.extui
// CHECK-NEXT:    arith.cmpi ule, %[[A]], %[[B]] : i256
// CHECK-NEXT:    arith.extui
// CHECK-NEXT:    arith.cmpi ugt, %[[A]], %[[B]] : i256
// CHECK-NEXT:    arith.extui
// CHECK-NEXT:    arith.cmpi uge, %[[A]], %[[B]] : i256
// CHECK-NEXT:    arith.extui
// CHECK-NEXT:    arith.cmpi slt, %[[A]], %[[B]] : i256
// CHECK-NEXT:    arith.extui
// CHECK-NEXT:    arith.cmpi sle, %[[A]], %[[B]] : i256
// CHECK-NEXT:    arith.extui
// CHECK-NEXT:    arith.cmpi sgt, %[[A]], %[[B]] : i256
// CHECK-NEXT:    arith.extui
// CHECK-NEXT:    arith.cmpi sge, %[[A]], %[[B]] : i256
// CHECK-NEXT:    arith.extui

yul.func @cmp : (i256, i256) -> (i256, i256, i256, i256, i256, i256, i256, i256, i256, i256) {
^bb0(%a: i256, %b: i256):
  %0 = yul.cmp eq, %a, %b
  %1 = yul.cmp ne, %a, %b
  %2 = yul.cmp ult, %a, %b
  %3 = yul.cmp ule, %a, %b
  %4 = yul.cmp ugt, %a, %b
  %5 = yul.cmp uge, %a, %b
  %6 = yul.cmp slt, %a, %b
  %7 = yul.cmp sle, %a, %b
  %8 = yul.cmp sgt, %a, %b
  %9 = yul.cmp sge, %a, %b
  yul.func_return %0, %1, %2, %3, %4, %5, %6, %7, %8, %9 : i256, i256, i256, i256, i256, i256, i256, i256, i256, i256
}
