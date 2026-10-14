// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test
// CHECK:         func.func @__entry()
// CHECK:           %[[SZ:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.returndatasize"}> : () -> i256
// CHECK:           %[[D:.*]] = llvm.inttoptr %{{.*}} : i256 to !llvm.ptr<1>
// CHECK:           %[[S:.*]] = llvm.inttoptr %{{.*}} : i256 to !llvm.ptr<3>
// CHECK:           "llvm.intr.memcpy"(%[[D]], %[[S]], %[[SZ]]) <{isVolatile = false}> : (!llvm.ptr<1>, !llvm.ptr<3>, i256) -> ()

module {
  yul.object @Test {
    yul.func @__entry : () -> () {
      %c0_i256 = yul.constant 0
      %c0_i256_0 = yul.constant 0
      %0 = yul.returndatasize
      yul.returndatacopy %c0_i256, %c0_i256_0, %0
      yul.func_return
    }
  }
}

