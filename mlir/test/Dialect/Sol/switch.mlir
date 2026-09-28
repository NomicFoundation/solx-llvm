// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// Case values wider than 64 bits must survive the parse/print round trip
// intact.

// CHECK-LABEL: func @roundtrip
func.func @roundtrip(%arg0: i256) {
  // CHECK:      sol.switch %{{.*}} : i256
  // CHECK-NEXT: case 1 {
  // CHECK:      case 9223372036854775808 {
  // CHECK:      case 340282366920938463463374607431768211457 {
  // CHECK:      case 57896044618658097711785492504343953926634992332820282019728792003956564819968 {
  // CHECK:      case 115792089237316195423570985008687907853269984665640564039457584007913129639935 {
  // CHECK:      default {
  sol.switch %arg0 : i256
  case 1 {
    sol.yield
  }
  case 9223372036854775808 {
    sol.yield
  }
  case 340282366920938463463374607431768211457 {
    sol.yield
  }
  case 57896044618658097711785492504343953926634992332820282019728792003956564819968 {
    sol.yield
  }
  case 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff {
    sol.yield
  }
  default {
    sol.yield
  }
  return
}
