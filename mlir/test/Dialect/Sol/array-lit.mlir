// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK-LABEL: func @roundtrip
func.func @roundtrip(%a: ui256, %b: ui256) {
  // CHECK: sol.array_lit : () -> !sol.array<0 x ui256, Memory>
  %0 = sol.array_lit : () -> !sol.array<0 x ui256, Memory>
  // CHECK: sol.array_lit %{{.*}} : (ui256) -> !sol.array<1 x ui256, Memory>
  %1 = sol.array_lit %a : (ui256) -> !sol.array<1 x ui256, Memory>
  // CHECK: sol.array_lit %{{.*}}, %{{.*}} : (ui256, ui256) -> !sol.array<2 x ui256, Memory>
  %2 = sol.array_lit %a, %b : (ui256, ui256) -> !sol.array<2 x ui256, Memory>
  return
}
