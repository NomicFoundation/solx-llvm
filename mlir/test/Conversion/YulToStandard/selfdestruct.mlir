// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @selfdestruct
// CHECK:         %[[ADDR:.*]] = arith.andi %{{.*}}, %{{.*}} : i256
// CHECK:         "llvm.intrcall"(%[[ADDR]]) <{id = {{[0-9]+}} : i32, name = "evm.selfdestruct"}> : (i256) -> ()
// CHECK-NEXT:    call @".unreachable"() : () -> ()

yul.func @selfdestruct : (i256) -> () {
^bb0(%arg0: i256):
  %c1461501637330902918203684832716283019655932542975_i256 = yul.constant 1461501637330902918203684832716283019655932542975
  %0 = yul.and %arg0, %c1461501637330902918203684832716283019655932542975_i256
  yul.selfdestruct %0
  yul.func_return
}
