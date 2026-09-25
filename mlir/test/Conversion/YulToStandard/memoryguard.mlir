// RUN: mlir-opt --convert-yul-to-std %s | FileCheck %s

// CHECK-LABEL: func @free_ptr_init
// CHECK:       %[[MARK:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.memoryguard"}> : () -> i256
// CHECK:       llvm.store %[[MARK]], %{{.*}} : i256, !llvm.ptr<1>
// CHECK:       llvm.module_flags [#llvm.mlir.module_flag<error, "evm-memory-guard", 128 : i64>, #llvm.mlir.module_flag<error, "evm-stack-region-size", 0 : i64>]
func.func @free_ptr_init() {
  %guard = yul.memoryguard 128
  %addr = arith.constant 64 : i256
  yul.mstore %addr, %guard
  return
}
