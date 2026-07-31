// RUN: mlir-translate -mlir-to-llvmir %s | FileCheck %s

// Switch case values wider than 64 bits must be emitted intact.

llvm.func @switch_wide_cases(%arg0: i256) -> i32 {
  "llvm.switch"(%arg0)[^bb3, ^bb1, ^bb2] <{
      case_operand_segments = array<i32: 0, 0>,
      case_values = dense<[18446744073709551617,
                           340282366920938463463374607431768211457]>
          : vector<2xi256>,
      operandSegmentSizes = array<i32: 1, 0, 0>}> : (i256) -> ()
^bb1:
  %0 = llvm.mlir.constant(1 : i32) : i32
  llvm.return %0 : i32
^bb2:
  %1 = llvm.mlir.constant(2 : i32) : i32
  llvm.return %1 : i32
^bb3:
  %2 = llvm.mlir.constant(0 : i32) : i32
  llvm.return %2 : i32
}

// CHECK-LABEL: define i32 @switch_wide_cases(i256 %0)
// CHECK: switch i256 %0, label %{{.*}} [
// CHECK-NEXT:   i256 18446744073709551617, label %{{.*}}
// CHECK-NEXT:   i256 340282366920938463463374607431768211457, label %{{.*}}
// CHECK-NEXT: ]
