// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test
// CHECK:         func.func @__entry()
// CHECK:           %[[G:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.memoryguard"}> : () -> i256
// CHECK:           llvm.store %[[G]], %{{.*}} {alignment = 1 : i64} : i256, !llvm.ptr<1>
// CHECK:           %[[V:.*]] = llvm.load %{{.*}} {alignment = 1 : i64} : !llvm.ptr<1> -> i256
// CHECK:           llvm.store %[[V]], %{{.*}} {alignment = 1 : i64} : i256, !llvm.ptr<1>
// CHECK:           "llvm.intr.memmove"(%{{.*}}, %{{.*}}, %{{.*}}) <{isVolatile = false}> : (!llvm.ptr<1>, !llvm.ptr<1>, i256) -> ()
// CHECK:           %[[B:.*]] = "llvm.intrcall"(%{{.*}}, %{{.*}}) <{id = {{[0-9]+}} : i32, name = "evm.byte"}> : (i256, i256) -> i256
// CHECK:           "llvm.intrcall"(%{{.*}}, %[[B]]) <{id = {{[0-9]+}} : i32, name = "evm.mstore8"}> : (!llvm.ptr<1>, i256) -> ()
// CHECK:           %[[MSZ:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.msize"}> : () -> i256
// CHECK:           llvm.store %[[MSZ]], %{{.*}} {alignment = 1 : i64} : i256, !llvm.ptr<1>
// CHECK:         llvm.module_flags [#llvm.mlir.module_flag<error, "evm-memory-guard", 1 : i64>

module {
  yul.object @Test {
    yul.func @__entry : () -> () {
      %c0_i256 = yul.constant 0
      %0 = yul.memoryguard 1
      yul.mstore %c0_i256, %0
      %c0_i256_0 = yul.constant 0
      %c1_i256 = yul.constant 1
      %1 = yul.mload %c1_i256
      yul.mstore %c0_i256_0, %1
      %c0_i256_1 = yul.constant 0
      %c10_i256 = yul.constant 10
      %c5_i256 = yul.constant 5
      yul.mcopy %c0_i256_1, %c10_i256, %c5_i256
      %c0_i256_2 = yul.constant 0
      %c0_i256_3 = yul.constant 0
      %2 = yul.byte %c0_i256_3, %1
      yul.mstore8 %c0_i256_2, %2
      %c0_i256_4 = yul.constant 0
      %3 = yul.msize
      yul.mstore %c0_i256_4, %3
      yul.func_return
    }
  }
}

