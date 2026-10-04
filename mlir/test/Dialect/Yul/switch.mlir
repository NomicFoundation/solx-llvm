// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// Case values wider than 64 bits and each region's body must survive the
// parse/print round trip intact.

// CHECK-LABEL: func @roundtrip
func.func @roundtrip(%arg0: i256) {
  // CHECK:      yul.switch %{{.*}} : i256
  // CHECK-NEXT: case 1 {
  // CHECK-NEXT:   yul.constant 10
  // CHECK:      case 340282366920938463463374607431768211457 {
  // CHECK-NEXT:   yul.constant 20
  // CHECK:      case 115792089237316195423570985008687907853269984665640564039457584007913129639935 {
  // CHECK-NEXT:   yul.constant 30
  // CHECK:      default {
  // CHECK-NEXT:   yul.constant 40
  yul.switch %arg0 : i256
  case 1 {
    %c10 = yul.constant 10
    yul.yield
  }
  case 340282366920938463463374607431768211457 {
    %c20 = yul.constant 20
    yul.yield
  }
  case 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff {
    %c30 = yul.constant 30
    yul.yield
  }
  default {
    %c40 = yul.constant 40
    yul.yield
  }
  return
}

// CHECK-LABEL: func @attrs
func.func @attrs(%arg0: i256) -> i256 {
  // CHECK:      yul.switch %{{.*}} : i256 -> i256 {foo}
  // CHECK-NEXT: case 1 {
  // CHECK:      default {
  %0 = yul.switch %arg0 : i256 -> i256 {foo}
  case 1 {
    %c10 = yul.constant 10
    yul.yield %c10 : i256
  }
  default {
    %c40 = yul.constant 40
    yul.yield %c40 : i256
  }
  return %0 : i256
}
