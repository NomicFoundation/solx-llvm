// RUN: mlir-opt --split-input-file --convert-yul-to-std %s | FileCheck %s

// A function marked unsafe_asm voids the object's memoryguard.

// CHECK-LABEL: func.func @__entry
// CHECK:         %[[MARK:.*]] = arith.constant 128 : i256
// CHECK:         llvm.store %[[MARK]], %{{.*}} : i256, !llvm.ptr<1>
// CHECK-NOT:     evm.memoryguard
// CHECK-NOT:     llvm.module_flags
module {
  "yul.object"() ({
    %guard = yul.memoryguard 128
    %addr = yul.constant 64
    yul.mstore %addr, %guard
    yul.func @f : () -> () {
      yul.func_return
    } {unsafe_asm}
  }) {sym_name = "obj"} : () -> ()
}

// -----

// The check is per module: unsafe_asm in the creation object leaves the
// runtime object's memoryguard intact.

// CHECK-LABEL: module @C
// CHECK:         func.func @__entry
// CHECK:           %[[MARK:.*]] = arith.constant 128 : i256
// CHECK:           llvm.store %[[MARK]], %{{.*}} : i256, !llvm.ptr<1>
// CHECK:         module @C_deployed
// CHECK:           func.func @__entry
// CHECK:             %[[GUARD:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.memoryguard"}> : () -> i256
// CHECK:             llvm.store %[[GUARD]], %{{.*}} : i256, !llvm.ptr<1>
// CHECK:           llvm.module_flags [#llvm.mlir.module_flag<error, "evm-memory-guard", 128 : i64>
yul.object @C {
  %guard = yul.memoryguard 128
  %addr = yul.constant 64
  yul.mstore %addr, %guard
  yul.func @f : () -> () {
    yul.func_return
  } {unsafe_asm}
  yul.object @C_deployed {
    %guard2 = yul.memoryguard 128
    %addr2 = yul.constant 64
    yul.mstore %addr2, %guard2
  }
}
