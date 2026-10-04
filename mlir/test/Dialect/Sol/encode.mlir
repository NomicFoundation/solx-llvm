// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK-LABEL: func @roundtrip
func.func @roundtrip(%sel: !sol.fixedbytes<4>, %a: ui256, %b: !sol.address) {
  // CHECK: sol.encode : : !sol.string<Memory>
  %0 = sol.encode : : !sol.string<Memory>
  // CHECK: sol.encode %{{.*}} : ui256 : !sol.string<Memory>
  %1 = sol.encode %a : ui256 : !sol.string<Memory>
  // CHECK: sol.encode %{{.*}}, %{{.*}} : ui256, !sol.address : !sol.string<Memory> {packed}
  %2 = sol.encode %a, %b : ui256, !sol.address : !sol.string<Memory> {packed}
  // CHECK: sol.encode selector(%{{.*}}) : !sol.fixedbytes<4> : !sol.string<Memory>
  %3 = sol.encode selector(%sel) : !sol.fixedbytes<4> : !sol.string<Memory>
  // CHECK: sol.encode selector(%{{.*}}) %{{.*}} : !sol.fixedbytes<4> ui256 : !sol.string<Memory>
  %4 = sol.encode selector(%sel) %a : !sol.fixedbytes<4> ui256 : !sol.string<Memory>
  // CHECK: sol.encode selector(%{{.*}}) %{{.*}}, %{{.*}} : !sol.fixedbytes<4> ui256, !sol.address : !sol.string<Memory>
  %5 = sol.encode selector(%sel) %a, %b : !sol.fixedbytes<4> ui256, !sol.address : !sol.string<Memory>
  return
}
