// RUN: mlir-opt %s --split-input-file --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test {
// CHECK:         func.func @__entry()
// CHECK:           %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.callvalue"}> : () -> i256
// CHECK:           %[[ZERO:.*]] = arith.constant 0 : i256
// CHECK:           %[[C:.*]] = arith.cmpi ne, %[[V]], %[[ZERO]] : i256
// CHECK:           cf.cond_br %[[C]], ^[[THEN:bb[0-9]+]], ^[[END:bb[0-9]+]]
// CHECK:         ^[[THEN]]:
// CHECK:           llvm.store %{{.*}}, %{{.*}} {alignment = 1 : i64} : i256, !llvm.ptr<1>
// CHECK:           cf.br ^[[END]]
// CHECK:         ^[[END]]:
// CHECK:           name = "evm.return"

module {
  yul.object @Test {
    yul.func @__entry : () -> () {
      %0 = yul.callvalue
      yul.if %0 {
        %c0_i256_1 = yul.constant 0
        %c42_i256 = yul.constant 42
        yul.mstore %c0_i256_1, %c42_i256
        yul.yield
      } else {
      }
      %c0_i256 = yul.constant 0
      %c0_i256_0 = yul.constant 0
      yul.return %c0_i256, %c0_i256_0
    }
  }
}

// -----

// CHECK-LABEL: module @Test_deployed
// CHECK:         func.func @__entry()
// CHECK:           %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.callvalue"}> : () -> i256
// CHECK:           %[[ZERO:.*]] = arith.constant 0 : i256
// CHECK:           %[[C:.*]] = arith.cmpi ne, %[[V]], %[[ZERO]] : i256
// CHECK:           cf.cond_br %[[C]], ^[[THEN:bb[0-9]+]], ^[[END:bb[0-9]+]]
// CHECK:         ^[[THEN]]:
// CHECK:           llvm.store %{{.*}}, %{{.*}} {alignment = 1 : i64} : i256, !llvm.ptr<1>
// CHECK:           cf.br ^[[END]]
// CHECK:         ^[[END]]:
// CHECK:           name = "evm.return"

module {
  yul.object @Test_deployed {
    yul.func @__entry : () -> () {
      %1 = yul.callvalue
      yul.if %1 {
        %c1_i256 = yul.constant 1
        %c42_i256 = yul.constant 42
        yul.mstore %c1_i256, %c42_i256
        yul.yield
      } else {
      }
      %c0_i256_1 = yul.constant 0
      %c0_i256_2 = yul.constant 0
      yul.return %c0_i256_1, %c0_i256_2
    }
  }
}

// -----

// CHECK-LABEL: func.func @if_result
// CHECK-SAME:      (%[[C:.*]]: i256, %[[X:.*]]: i256) -> i256
// CHECK:         cf.cond_br %{{.*}}, ^[[THEN:bb[0-9]+]], ^[[ELSE:bb[0-9]+]]
// CHECK:       ^[[ELSE]]:
// CHECK-NEXT:    cf.br ^[[JOIN:bb[0-9]+]](%[[X]] : i256)
// CHECK:       ^[[THEN]]:
// CHECK-NEXT:    %[[SUM:.*]] = arith.addi %[[X]], %[[C]] : i256
// CHECK-NEXT:    cf.br ^[[JOIN]](%[[SUM]] : i256)
// CHECK:       ^[[JOIN]](%[[R:.*]]: i256):
// CHECK-NEXT:    return %[[R]] : i256

yul.func @if_result : (i256, i256) -> i256 {
^bb0(%arg0: i256, %arg1: i256):
  %0 = yul.if %arg0 -> i256 {
    %1 = yul.add %arg1, %arg0
    yul.yield %1 : i256
  } else {
    yul.yield %arg1 : i256
  }
  yul.func_return %0 : i256
}
