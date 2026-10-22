// RUN: mlir-opt %s -convert-yul-to-std -mlir-print-debuginfo \
// RUN:   -mlir-print-local-scope | FileCheck %s

// A halting op's intrinsic call and the unreachable terminating it are both at
// the op's location.

module {
  func.func @f() {
    %c0 = arith.constant 0 : i256 loc(#loc_revert)
    yul.revert %c0, %c0 loc(#loc_revert)
  }
}

#loc_revert = loc("A.sol":2:5)

// CHECK-LABEL: func.func @f()
// CHECK:         "llvm.intrcall"{{.*}}evm.revert{{.*}} loc("A.sol":2:5)
// CHECK-NEXT:    llvm.unreachable loc("A.sol":2:5)
