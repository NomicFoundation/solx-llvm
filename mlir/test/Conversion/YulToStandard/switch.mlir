// RUN: mlir-opt %s --split-input-file --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test {
// CHECK:         func.func @__entry()
// CHECK:           name = "evm.return"

module {
  yul.object @Test {
    %c0_i256 = yul.constant 0
    %c0_i256_0 = yul.constant 0
    yul.return %c0_i256, %c0_i256_0
  }
}

// -----

// CHECK-LABEL: module @Test_deployed
// CHECK:         func.func @__entry()
// CHECK:           %[[SEL:.*]] = llvm.load %{{.*}} : !llvm.ptr<1> -> i256
// CHECK:           cf.switch %[[SEL]] : i256, [
// CHECK-NEXT:        default: ^[[DEF:bb[0-9]+]],
// CHECK-NEXT:        0: ^[[C0:bb[0-9]+]],
// CHECK-NEXT:        1: ^[[C1:bb[0-9]+]]
// CHECK-NEXT:      ]
// CHECK:         ^[[C0]]:
// CHECK-NEXT:      arith.constant 0 : i256
// CHECK-NEXT:      %[[V0:.*]] = arith.constant 0 : i256
// CHECK:           llvm.store %[[V0]], %{{.*}} {alignment = 1 : i64} : i256, !llvm.ptr<1>
// CHECK:           cf.br ^[[END:bb[0-9]+]]
// CHECK:         ^[[C1]]:
// CHECK:           %[[V1:.*]] = arith.constant 1 : i256
// CHECK:           llvm.store %[[V1]], %{{.*}} {alignment = 1 : i64} : i256, !llvm.ptr<1>
// CHECK:           cf.br ^[[END]]
// CHECK:         ^[[DEF]]:
// CHECK-NEXT:      cf.br ^[[END]]
// CHECK:         ^[[END]]:
// CHECK:           name = "evm.return"

module {
  yul.object @Test_deployed {
    %c0_i256_1 = yul.constant 0
    %0 = yul.mload %c0_i256_1
    yul.switch %0 : i256
    case 0 {
      %c0_i256_4 = yul.constant 0
      %c0_i256_5 = yul.constant 0
      yul.mstore %c0_i256_4, %c0_i256_5
      yul.yield
    }
    case 1 {
      %c0_i256_4 = yul.constant 0
      %c1_i256 = yul.constant 1
      yul.mstore %c0_i256_4, %c1_i256
      yul.yield
    }
    default {
      yul.yield
    }
    %c0_i256_2 = yul.constant 0
    %c0_i256_3 = yul.constant 0
    yul.return %c0_i256_2, %c0_i256_3
  }
}

// -----

// The default region ends in the revert and yields nothing.
// CHECK-LABEL: func.func @switch_result
// CHECK-SAME:      (%[[V:.*]]: i256, %[[X:.*]]: i256) -> i256
// CHECK:         cf.switch %[[V]] : i256, [
// CHECK-NEXT:      default: ^[[DEFAULT:bb[0-9]+]],
// CHECK-NEXT:      7: ^[[CASE:bb[0-9]+]]
// CHECK-NEXT:    ]
// CHECK:       ^[[CASE]]:
// CHECK-NEXT:    %[[SUM:.*]] = arith.addi %[[X]], %[[X]] : i256
// CHECK-NEXT:    cf.br ^[[JOIN:bb[0-9]+]](%[[SUM]] : i256)
// CHECK:       ^[[DEFAULT]]:
// CHECK:         name = "evm.revert"
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  ^[[JOIN]](%[[R:.*]]: i256):  // pred: ^[[CASE]]
// CHECK-NEXT:    return %[[R]] : i256

yul.func @switch_result : (i256, i256) -> i256 {
^bb0(%arg0: i256, %arg1: i256):
  %0 = yul.switch %arg0 : i256 -> i256
  case 7 {
    %1 = yul.add %arg1, %arg1
    yul.yield %1 : i256
  }
  default {
    %c0 = yul.constant 0
    yul.revert %c0, %c0
  }
  yul.func_return %0 : i256
}
