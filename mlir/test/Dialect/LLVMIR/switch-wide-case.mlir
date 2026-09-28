// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// Case values wider than 64 bits must survive the parse/print round trip
// intact. The printer emits the values as signed integers, so a value with
// the top bit set prints and parses back in its negative form.

// CHECK-LABEL: llvm.func @switch_wide_cases
llvm.func @switch_wide_cases(%flag: i256) {
  // CHECK:      llvm.switch %{{.*}} : i256, ^bb1 [
  // CHECK-NEXT:   1: ^bb1,
  // CHECK-NEXT:   9223372036854775808: ^bb2,
  // CHECK-NEXT:   340282366920938463463374607431768211457: ^bb3,
  // CHECK-NEXT:   -57896044618658097711785492504343953926634992332820282019728792003956564819968: ^bb4,
  // CHECK-NEXT:   -1: ^bb5
  // CHECK-NEXT: ]
  llvm.switch %flag : i256, ^bb1 [
    1: ^bb1,
    9223372036854775808: ^bb2,
    340282366920938463463374607431768211457: ^bb3,
    57896044618658097711785492504343953926634992332820282019728792003956564819968: ^bb4,
    0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff: ^bb5
  ]
^bb1:
  llvm.return
^bb2:
  llvm.return
^bb3:
  llvm.return
^bb4:
  llvm.return
^bb5:
  llvm.return
}

// Small flag types still accept both the signed and the unsigned spelling
// of a value with the top bit set.

// CHECK-LABEL: llvm.func @switch_i8_cases
llvm.func @switch_i8_cases(%flag: i8) {
  // CHECK:      llvm.switch %{{.*}} : i8, ^bb1 [
  // CHECK-NEXT:   -1: ^bb1,
  // CHECK-NEXT:   -128: ^bb2
  // CHECK-NEXT: ]
  llvm.switch %flag : i8, ^bb1 [
    255: ^bb1,
    -128: ^bb2
  ]
^bb1:
  llvm.return
^bb2:
  llvm.return
}
