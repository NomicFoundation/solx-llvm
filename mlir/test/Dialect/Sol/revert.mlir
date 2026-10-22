// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// Each revert form ends its own block; the next line must be the following
// block's label (or the closing brace), not absorbed into the revert.

// CHECK-LABEL: func @roundtrip
func.func @roundtrip(%a: ui256, %msg: !sol.string<Memory>) {
  // CHECK:      sol.revert{{$}}
  // CHECK-NEXT: ^bb1:
  sol.revert
^bb1:
  // CHECK:      sol.revert "oops"{{$}}
  // CHECK-NEXT: ^bb2:
  sol.revert "oops"
^bb2:
  // CHECK:      sol.revert ""{{$}}
  // CHECK-NEXT: ^bb3:
  sol.revert ""
^bb3:
  // CHECK:      sol.revert "Error(string)"(%{{.*}} : !sol.string<Memory>) {call}{{$}}
  // CHECK-NEXT: ^bb4:
  sol.revert "Error(string)"(%msg : !sol.string<Memory>) {call}
^bb4:
  // CHECK:      sol.revert "E(uint256,uint256)"(%{{.*}}, %{{.*}} : ui256, ui256) {call}{{$}}
  // CHECK-NEXT: ^bb5:
  sol.revert "E(uint256,uint256)"(%a, %a : ui256, ui256) {call}
^bb5:
  // CHECK:      sol.revert(%{{.*}} : ui256){{$}}
  // CHECK-NEXT: }
  sol.revert(%a : ui256)
}

// CHECK-LABEL: func @require
func.func @require(%c: i1, %a: ui256, %msg: !sol.string<Memory>) {
  // CHECK: sol.require %{{[^ ]*}}{{$}}
  sol.require %c
  // CHECK: sol.require %{{.*}}, "oops"{{$}}
  sol.require %c, "oops"
  // CHECK: sol.require %{{.*}}(%{{.*}} : ui256){{$}}
  sol.require %c(%a : ui256)
  // CHECK: sol.require %{{.*}}, "Error(string)"(%{{.*}} : !sol.string<Memory>) {call}
  sol.require %c, "Error(string)"(%msg : !sol.string<Memory>) {call}
  // CHECK: sol.require %{{.*}}, "E(uint256,string)"(%{{.*}}, %{{.*}} : ui256, !sol.string<Memory>) {call}
  sol.require %c, "E(uint256,string)"(%a, %msg : ui256, !sol.string<Memory>) {call}
  return
}
