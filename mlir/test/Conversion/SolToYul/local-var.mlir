// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @f : (i256) -> i256
// CHECK:         %[[V:.*]] = llvm.alloca %{{.*}} x i256 : (i256) -> !llvm.ptr
// CHECK:         llvm.store %arg0, %[[V]] {alignment = 32 : i64} : i256, !llvm.ptr
// CHECK:         %[[R:.*]] = llvm.load %[[V]] {alignment = 32 : i64} : !llvm.ptr -> i256
// CHECK:         yul.func_return %[[R]] : i256

sol.func @f(%a: ui256) -> ui256 {
  %0 = sol.alloca : !sol.ptr<ui256, Stack>
  sol.store %a, %0 : ui256, !sol.ptr<ui256, Stack>
  %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
  sol.return %1 : ui256
}
