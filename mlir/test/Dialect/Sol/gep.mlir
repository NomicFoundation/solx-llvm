// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK-LABEL: func @roundtrip
func.func @roundtrip(%a: !sol.array<? x ui256, Storage>, %i: ui256) {
  // CHECK: sol.gep %{{.*}}, %{{.*}} : !sol.array<? x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
  %0 = sol.gep %a, %i : !sol.array<? x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
  // CHECK: sol.gep %{{.*}}, %{{.*}} no_panic_bounds : !sol.array<? x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
  %1 = sol.gep %a, %i no_panic_bounds : !sol.array<? x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
  return
}
