// RUN: mlir-opt --convert-yul-to-std %s | FileCheck %s

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
