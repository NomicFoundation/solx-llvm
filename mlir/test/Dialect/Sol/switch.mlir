// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// Each region's body stays under its own case/default, case values print in
// the argument's signedness, and the attr-dict survives.

// CHECK-LABEL: func @unsigned
func.func @unsigned(%arg0: ui256) {
  // CHECK:      sol.switch %{{.*}} : ui256 {foo}
  // CHECK-NEXT: case 1 {
  // CHECK-NEXT:   sol.constant 10
  // CHECK:      case 115792089237316195423570985008687907853269984665640564039457584007913129639935 {
  // CHECK-NEXT:   sol.constant 20
  // CHECK:      default {
  // CHECK-NEXT:   sol.constant 30
  sol.switch %arg0 : ui256 {foo}
  case 1 {
    %c10 = sol.constant 10 : ui256
    sol.yield
  }
  case 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff {
    %c20 = sol.constant 20 : ui256
    sol.yield
  }
  default {
    %c30 = sol.constant 30 : ui256
    sol.yield
  }
  return
}

// CHECK-LABEL: func @signed
func.func @signed(%arg0: si8) {
  // CHECK:      sol.switch %{{.*}} : si8
  // CHECK-NEXT: case -128 {
  // CHECK-NEXT:   sol.constant 10
  // CHECK:      case 127 {
  // CHECK-NEXT:   sol.constant 20
  // CHECK:      default {
  // CHECK-NEXT:   sol.constant 30
  sol.switch %arg0 : si8
  case -128 {
    %c10 = sol.constant 10 : ui256
    sol.yield
  }
  case 127 {
    %c20 = sol.constant 20 : ui256
    sol.yield
  }
  default {
    %c30 = sol.constant 30 : ui256
    sol.yield
  }
  return
}
