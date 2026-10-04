// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test
// CHECK:       func.func @__entry()
// CHECK:         %[[LDPTR:.*]] = llvm.inttoptr %{{.*}} : i256 to !llvm.ptr<2>
// CHECK:         %[[OFF:.*]] = llvm.load %[[LDPTR]] {alignment = 1 : i64} : !llvm.ptr<2> -> i256
// CHECK:         %[[SIZE:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.calldatasize"}> : () -> i256
// CHECK:         %[[DST:.*]] = llvm.inttoptr %{{.*}} : i256 to !llvm.ptr<1>
// CHECK:         %[[SRC:.*]] = llvm.inttoptr %[[OFF]] : i256 to !llvm.ptr<2>
// CHECK:         "llvm.intr.memcpy"(%[[DST]], %[[SRC]], %[[SIZE]]) <{isVolatile = false}> : (!llvm.ptr<1>, !llvm.ptr<2>, i256) -> ()

module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown"} {
  yul.object @Test {
    %c0_i256 = yul.constant 0
    %c0_i256_0 = yul.constant 0
    %0 = yul.calldataload %c0_i256_0
    %1 = yul.calldatasize
    yul.calldatacopy %c0_i256, %0, %1
  }
}

