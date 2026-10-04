// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// The switch is generic: its custom parser adds the default region after the
// cases, but the op stores it first.

// CHECK-LABEL: func.func @for_switch
// CHECK-SAME:      (%[[C:.*]]: i256, %[[SEL:.*]]: i256)
// CHECK-NEXT:    cf.br ^[[COND:bb[0-9]+]]
// CHECK:       ^[[COND]]:
// CHECK:         %[[CV:.*]] = arith.cmpi ne, %[[C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[CV]], ^[[BODY:bb[0-9]+]], ^[[EXIT:bb[0-9]+]]
// CHECK:       ^[[BODY]]:
// CHECK-NEXT:    cf.switch %[[SEL]] : i256, [
// CHECK-NEXT:      default: ^[[DEF:bb[0-9]+]],
// CHECK-NEXT:      0: ^[[C0:bb[0-9]+]],
// CHECK-NEXT:      1: ^[[C1:bb[0-9]+]]
// CHECK-NEXT:    ]
// CHECK:       ^[[C0]]:
// CHECK-NEXT:    cf.br ^[[EXIT]]
// CHECK:       ^[[C1]]:
// CHECK-NEXT:    cf.br ^[[STEP:bb[0-9]+]]
// CHECK:       ^[[DEF]]:
// CHECK-NEXT:    cf.br ^[[MERGE:bb[0-9]+]]
// CHECK:       ^[[MERGE]]:
// CHECK-NEXT:    cf.br ^[[STEP]]
// CHECK:       ^[[STEP]]:
// CHECK-NEXT:    cf.br ^[[COND]]
// CHECK:       ^[[EXIT]]:
// CHECK-NEXT:    return
yul.func @for_switch : (i256, i256) -> () {
^bb0(%c: i256, %sel: i256):
  yul.for cond {
    yul.condition %c
  } body {
    yul.switch %sel : i256
    case 0 {
      yul.break
    ^bb1:  // no predecessors
      yul.yield
    }
    case 1 {
      yul.continue
    ^bb1:  // no predecessors
      yul.yield
    }
    default {
      yul.yield
    }
    yul.yield
  } step {
    yul.yield
  }
  yul.func_return
}
