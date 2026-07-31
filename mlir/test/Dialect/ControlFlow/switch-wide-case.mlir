// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// Case values wider than 64 bits must survive the parse/print round trip
// intact.

// CHECK-LABEL: func @switch_wide_cases
func.func @switch_wide_cases(%flag: i256) {
  // CHECK:      cf.switch %{{.*}} : i256, [
  // CHECK-NEXT:   default: ^bb1,
  // CHECK-NEXT:   1: ^bb1,
  // CHECK-NEXT:   340282366920938463463374607431768211457: ^bb2,
  // CHECK-NEXT:   115792089237316195423570985008687907853269984665640564039457584007913129639935: ^bb3
  // CHECK-NEXT: ]
  cf.switch %flag : i256, [
    default: ^bb1,
    1: ^bb1,
    340282366920938463463374607431768211457: ^bb2,
    115792089237316195423570985008687907853269984665640564039457584007913129639935: ^bb3
  ]
^bb1:
  return
^bb2:
  return
^bb3:
  return
}

// Negative case values must keep round-tripping: they are stored sign
// extended to the flag type and printed back as full-width unsigned values.

// CHECK-LABEL: func @switch_negative_case
func.func @switch_negative_case(%flag: i32) {
  // CHECK:      cf.switch %{{.*}} : i32, [
  // CHECK-NEXT:   default: ^bb1,
  // CHECK-NEXT:   4294967295: ^bb2
  // CHECK-NEXT: ]
  cf.switch %flag : i32, [
    default: ^bb1,
    -1: ^bb2
  ]
^bb1:
  return
^bb2:
  return
}
