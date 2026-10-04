// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test
// CHECK:         func.func @__entry()
// CHECK:           %[[OFF:.*]] = arith.constant 0 : i256
// CHECK:           %[[LEN:.*]] = arith.constant 1 : i256
// CHECK:           %[[P:.*]] = llvm.inttoptr %[[OFF]] : i256 to !llvm.ptr<1>
// CHECK:           "llvm.intrcall"(%[[P]], %[[LEN]]) <{id = {{[0-9]+}} : i32, name = "evm.revert"}> : (!llvm.ptr<1>, i256) -> ()
// CHECK-NEXT:      call @".unreachable"() : () -> ()
// CHECK-NEXT:      llvm.unreachable

module {
  yul.object @Test {
    %c0_i256 = yul.constant 0
    %c1_i256 = yul.constant 1
    yul.revert %c0_i256, %c1_i256
  }
}

