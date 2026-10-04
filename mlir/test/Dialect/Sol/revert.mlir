// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// Each revert is followed by a result-defining op that must not be taken for
// its operands.

// CHECK-LABEL: func @roundtrip
func.func @roundtrip(%a: ui256, %msg: !sol.string<Memory>) {
  // CHECK:      sol.revert{{$}}
  // CHECK-NEXT: sol.constant 1
  sol.revert
  %c1 = sol.constant 1 : ui256
  // CHECK:      sol.revert "oops"{{$}}
  // CHECK-NEXT: sol.constant 2
  sol.revert "oops"
  %c2 = sol.constant 2 : ui256
  // CHECK:      sol.revert ""{{$}}
  // CHECK-NEXT: sol.constant 3
  sol.revert ""
  %c3 = sol.constant 3 : ui256
  // CHECK:      sol.revert "Error(string)"(%{{.*}} : !sol.string<Memory>) {call}
  // CHECK-NEXT: sol.constant 4
  sol.revert "Error(string)"(%msg : !sol.string<Memory>) {call}
  %c4 = sol.constant 4 : ui256
  // CHECK:      sol.revert "E(uint256,uint256)"(%{{.*}}, %{{.*}} : ui256, ui256) {call}
  // CHECK-NEXT: sol.constant 5
  sol.revert "E(uint256,uint256)"(%a, %a : ui256, ui256) {call}
  %c5 = sol.constant 5 : ui256
  // CHECK:      sol.revert(%{{.*}} : ui256){{$}}
  // CHECK-NEXT: sol.constant 6
  sol.revert(%a : ui256)
  %c6 = sol.constant 6 : ui256
  return
}

// CHECK-LABEL: func @require
func.func @require(%c: i1, %a: ui256, %msg: !sol.string<Memory>) {
  // CHECK: sol.require %{{.*}}(){{$}}
  sol.require %c()
  // CHECK: sol.require %{{.*}}, "oops"(){{$}}
  sol.require %c, "oops"()
  // CHECK: sol.require %{{.*}}(%{{.*}} : ui256){{$}}
  sol.require %c(%a : ui256)
  // CHECK: sol.require %{{.*}}, "Error(string)"(%{{.*}} : !sol.string<Memory>) {call}
  sol.require %c, "Error(string)"(%msg : !sol.string<Memory>) {call}
  // CHECK: sol.require %{{.*}}, "E(uint256,string)"(%{{.*}}, %{{.*}} : ui256, !sol.string<Memory>) {call}
  sol.require %c, "E(uint256,string)"(%a, %msg : ui256, !sol.string<Memory>) {call}
  return
}
