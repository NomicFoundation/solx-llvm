// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// Case values wider than 64 bits must survive the parse/print round trip
// intact.

// CHECK-LABEL: func @roundtrip
func.func @roundtrip(%arg0: i256) {
  // CHECK:      yul.switch %{{.*}} : i256
  // CHECK-NEXT: case 1 {
  // CHECK:      case 340282366920938463463374607431768211457 {
  // CHECK:      case 115792089237316195423570985008687907853269984665640564039457584007913129639935 {
  // CHECK:      default {
  yul.switch %arg0 : i256
  case 1 {
    yul.yield
  }
  case 340282366920938463463374607431768211457 {
    yul.yield
  }
  case 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff {
    yul.yield
  }
  default {
    yul.yield
  }
  return
}
