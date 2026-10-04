// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK-LABEL: func @roundtrip
func.func @roundtrip(%size: ui256) {
  // CHECK: sol.malloc : () -> !sol.string<Memory>{{$}}
  %0 = sol.malloc : () -> !sol.string<Memory>
  // CHECK: sol.malloc zero_init : () -> !sol.array<? x ui256, Memory>{{$}}
  %1 = sol.malloc zero_init : () -> !sol.array<? x ui256, Memory>
  // CHECK: sol.malloc %{{.*}} : (ui256) -> !sol.string<Memory>{{$}}
  %2 = sol.malloc %size : (ui256) -> !sol.string<Memory>
  // CHECK: sol.malloc %{{.*}} zero_init : (ui256) -> !sol.array<? x ui256, Memory>{{$}}
  %3 = sol.malloc %size zero_init : (ui256) -> !sol.array<? x ui256, Memory>
  return
}

// CHECK-LABEL: func @alloca
func.func @alloca() {
  // CHECK: sol.alloca : !sol.ptr<ui256, Stack>
  %0 = sol.alloca : !sol.ptr<ui256, Stack>
  // CHECK: sol.alloca {foo} : !sol.ptr<!sol.string<Memory>, Stack>
  %1 = sol.alloca {foo} : !sol.ptr<!sol.string<Memory>, Stack>
  return
}
