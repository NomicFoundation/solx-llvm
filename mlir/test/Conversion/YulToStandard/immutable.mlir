// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @set
// CHECK-SAME:      (%[[OFF:.*]]: i256, %[[V:.*]]: i256)
// CHECK-NEXT:    "llvm.intrcall"(%[[OFF]], %[[V]]) <{id = {{[0-9]+}} : i32, metadata = ["foo"], name = "evm.setimmutable"}> : (i256, i256) -> ()
// CHECK-NEXT:    "llvm.intrcall"(%[[OFF]], %[[V]]) <{id = {{[0-9]+}} : i32, metadata = ["10000000000000000000000000"], name = "evm.setimmutable"}> : (i256, i256) -> ()
// CHECK-NEXT:    return
yul.func @set : (i256, i256) -> () {
^bb0(%off: i256, %v: i256):
  yul.setimmutable %off, "foo", %v
  yul.setimmutable %off, "10000000000000000000000000", %v
  yul.func_return
}

// CHECK-LABEL: func.func @load() -> (i256, i256)
// CHECK-NEXT:    %[[A:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, metadata = ["foo"], name = "evm.loadimmutable"}> : () -> i256
// CHECK-NEXT:    %[[B:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, metadata = ["10000000000000000000000000"], name = "evm.loadimmutable"}> : () -> i256
// CHECK-NEXT:    return %[[A]], %[[B]] : i256, i256
yul.func @load : () -> (i256, i256) {
  %0 = yul.loadimmutable "foo"
  %1 = yul.loadimmutable "10000000000000000000000000"
  yul.func_return %0, %1 : i256, i256
}
