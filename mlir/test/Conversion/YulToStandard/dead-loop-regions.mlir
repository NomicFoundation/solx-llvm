// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// A body that only breaks leaves the step without predecessors; it goes,
// and the condition keeps its entry.

// CHECK-LABEL: func.func @body_breaks
// CHECK:         cf.br ^[[COND:bb[0-9]+]]
// CHECK:       ^[[COND]]:
// CHECK:         cf.cond_br %{{.*}}, ^[[BODY:bb[0-9]+]], ^[[EXIT:bb[0-9]+]]
// CHECK:       ^[[BODY]]:
// CHECK-NEXT:    cf.br ^[[EXIT]]
// CHECK-NEXT:  ^[[EXIT]]:
// CHECK-NEXT:    return
func.func @body_breaks(%c: i256, %x: i256) {
  yul.for cond {
    yul.condition %c
  } body {
    yul.break
  } step {
    yul.mstore %x, %x
    yul.yield
  }
  return
}

// A do-while body that only breaks leaves the condition without
// predecessors; the exit keeps the break.

// CHECK-LABEL: func.func @do_body_breaks
// CHECK:         cf.br ^[[BODY:bb[0-9]+]]
// CHECK:       ^[[BODY]]:
// CHECK-NEXT:    cf.br ^[[EXIT:bb[0-9]+]]
// CHECK-NEXT:  ^[[EXIT]]:
// CHECK-NEXT:    return
func.func @do_body_breaks(%c: i256) {
  yul.do {
    yul.break
  } while {
    yul.condition %c
  }
  return
}
