// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK-LABEL: func @roundtrip
func.func @roundtrip() {
  // CHECK:      sol.inline_asm {
  // CHECK-NEXT: }
  sol.inline_asm {
  }
  // CHECK:      sol.inline_asm attributes {memory_safe} {
  // CHECK-NEXT: }
  sol.inline_asm attributes {memory_safe} {
  }
  // CHECK:      sol.inline_asm {
  // CHECK-NEXT:   yul.constant 1
  // CHECK-NEXT: }
  sol.inline_asm {
    %c1 = yul.constant 1
  }
  return
}
