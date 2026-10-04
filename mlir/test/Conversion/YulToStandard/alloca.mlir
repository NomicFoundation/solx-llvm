// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @alloca
// CHECK-SAME:      (%[[A:.*]]: i256) -> i256
// CHECK-NEXT:    %[[ONE:.*]] = arith.constant 1 : i256
// CHECK-NEXT:    %[[P:.*]] = llvm.alloca %[[ONE]] x i256 {alignment = 32 : i64} : (i256) -> !llvm.ptr
// CHECK-NEXT:    llvm.store %[[A]], %[[P]] {alignment = 32 : i64} : i256, !llvm.ptr
// CHECK-NEXT:    %[[V:.*]] = llvm.load %[[P]] {alignment = 32 : i64} : !llvm.ptr -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @alloca : (i256) -> i256 {
^bb0(%a: i256):
  %0 = yul.alloca : !yul.ptr
  yul.store %a, %0 : i256, !yul.ptr
  %1 = yul.load %0 : !yul.ptr -> i256
  yul.func_return %1 : i256
}

// `let x` then `x := a`: the zero-initializing store and the assignment.
// CHECK-LABEL: func.func @uninitialized
// CHECK-SAME:      (%[[A:.*]]: i256) -> i256
// CHECK:         %[[ZERO:.*]] = arith.constant 0 : i256
// CHECK:         %[[P:.*]] = llvm.alloca %{{.*}} x i256 {alignment = 32 : i64} : (i256) -> !llvm.ptr
// CHECK-NEXT:    llvm.store %[[ZERO]], %[[P]] {alignment = 32 : i64} : i256, !llvm.ptr
// CHECK-NEXT:    llvm.store %[[A]], %[[P]] {alignment = 32 : i64} : i256, !llvm.ptr
// CHECK-NEXT:    %[[V:.*]] = llvm.load %[[P]] {alignment = 32 : i64} : !llvm.ptr -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @uninitialized : (i256) -> i256 {
^bb0(%a: i256):
  %c0 = yul.constant 0
  %0 = yul.alloca : !yul.ptr
  yul.store %c0, %0 : i256, !yul.ptr
  yul.store %a, %0 : i256, !yul.ptr
  %1 = yul.load %0 : !yul.ptr -> i256
  yul.func_return %1 : i256
}
