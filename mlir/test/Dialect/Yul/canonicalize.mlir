// RUN: mlir-opt %s -canonicalize | FileCheck %s

// A comparison tested against zero is negated into its inverse predicate.

// CHECK-LABEL: yul.func @negated_cmp
// CHECK:       ^bb0(%[[X:.*]]: i256, %[[Y:.*]]: i256):
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[GE:.*]] = yul.cmp uge, %[[X]], %[[Y]]
// CHECK-DAG:     %[[NE:.*]] = yul.cmp ne, %[[X]], %[[C0]]
// CHECK:         yul.func_return %[[GE]], %[[NE]]
yul.func @negated_cmp : (i256, i256) -> (i256, i256) {
^bb0(%x: i256, %y: i256):
  %c0 = yul.constant 0
  %0 = yul.cmp ult, %x, %y
  %1 = yul.cmp eq, %0, %c0
  %2 = yul.cmp eq, %x, %c0
  %3 = yul.cmp eq, %2, %c0
  yul.func_return %1, %3 : i256, i256
}
