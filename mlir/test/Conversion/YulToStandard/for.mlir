// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @for
// CHECK-SAME:      (%[[C:.*]]: i256, %[[CONT_C:.*]]: i256, %[[BRK_C:.*]]: i256)
// CHECK-NEXT:    cf.br ^[[COND:bb[0-9]+]]
// CHECK:       ^[[COND]]:
// CHECK:         %[[CV:.*]] = arith.cmpi ne, %[[C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[CV]], ^[[BODY:bb[0-9]+]], ^[[EXIT:bb[0-9]+]]
// CHECK:       ^[[BODY]]:
// CHECK:         %[[CONTV:.*]] = arith.cmpi ne, %[[CONT_C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[CONTV]], ^[[CONT:bb[0-9]+]], ^{{bb[0-9]+}}
// CHECK:       ^[[CONT]]:
// CHECK-NEXT:    cf.br ^[[STEP:bb[0-9]+]]
// CHECK:         %[[BRKV:.*]] = arith.cmpi ne, %[[BRK_C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[BRKV]], ^[[BRK:bb[0-9]+]], ^{{bb[0-9]+}}
// CHECK:       ^[[BRK]]:
// CHECK-NEXT:    cf.br ^[[EXIT]]
// CHECK:       ^[[STEP]]:
// CHECK-NEXT:    cf.br ^[[COND]]
// CHECK:       ^[[EXIT]]:
// CHECK-NEXT:    return
yul.func @for : (i256, i256, i256) -> () {
^bb0(%c: i256, %cont: i256, %brk: i256):
  yul.for cond {
    yul.condition %c
  } body {
    yul.if %cont {
      yul.continue
    ^bb1:  // no predecessors
      yul.yield
    } else {
    }
    yul.if %brk {
      yul.break
    ^bb1:  // no predecessors
      yul.yield
    } else {
    }
    yul.yield
  } step {
    yul.yield
  }
  yul.func_return
}

// CHECK-LABEL: func.func @nested_for
// CHECK-SAME:      (%[[C:[^:]*]]: i256, %[[CONT_C:[^:]*]]: i256, %[[BRK_C:[^:]*]]: i256, %[[IC:[^:]*]]: i256, %[[ICONT_C:[^:]*]]: i256, %[[IBRK_C:[^:]*]]: i256)
// CHECK-NEXT:    cf.br ^[[COND:bb[0-9]+]]
// CHECK:       ^[[COND]]:
// CHECK:         %[[CV:.*]] = arith.cmpi ne, %[[C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[CV]], ^[[BODY:bb[0-9]+]], ^[[EXIT:bb[0-9]+]]
// CHECK:       ^[[BODY]]:
// CHECK-NEXT:    cf.br ^[[ICOND:bb[0-9]+]]
// CHECK:       ^[[ICOND]]:
// CHECK:         %[[ICV:.*]] = arith.cmpi ne, %[[IC]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[ICV]], ^{{bb[0-9]+}}, ^[[IEXIT:bb[0-9]+]]
// CHECK:         %[[ICONTV:.*]] = arith.cmpi ne, %[[ICONT_C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[ICONTV]], ^[[ICONT:bb[0-9]+]], ^{{bb[0-9]+}}
// CHECK:       ^[[ICONT]]:
// CHECK-NEXT:    cf.br ^[[ISTEP:bb[0-9]+]]
// CHECK:         %[[IBRKV:.*]] = arith.cmpi ne, %[[IBRK_C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[IBRKV]], ^[[IBRK:bb[0-9]+]], ^{{bb[0-9]+}}
// CHECK:       ^[[IBRK]]:
// CHECK-NEXT:    cf.br ^[[IEXIT]]
// CHECK:       ^[[ISTEP]]:
// CHECK-NEXT:    cf.br ^[[ICOND]]
// CHECK:       ^[[IEXIT]]:
// CHECK:         %[[CONTV:.*]] = arith.cmpi ne, %[[CONT_C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[CONTV]], ^[[CONT:bb[0-9]+]], ^{{bb[0-9]+}}
// CHECK:       ^[[CONT]]:
// CHECK-NEXT:    cf.br ^[[STEP:bb[0-9]+]]
// CHECK:         %[[BRKV:.*]] = arith.cmpi ne, %[[BRK_C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[BRKV]], ^[[BRK:bb[0-9]+]], ^{{bb[0-9]+}}
// CHECK:       ^[[BRK]]:
// CHECK-NEXT:    cf.br ^[[EXIT]]
// CHECK:       ^[[STEP]]:
// CHECK-NEXT:    cf.br ^[[COND]]
// CHECK:       ^[[EXIT]]:
// CHECK-NEXT:    return
yul.func @nested_for: (i256, i256, i256, i256, i256, i256) -> () {
^bb0(%c: i256, %cont: i256, %brk: i256, %ic: i256, %icont: i256, %ibrk: i256):
  yul.for cond {
    yul.condition %c
  } body {
    yul.for cond {
      yul.condition %ic
    } body {
      yul.if %icont {
        yul.continue
      ^bb1:  // no predecessors
        yul.yield
      } else {
      }
      yul.if %ibrk {
        yul.break
      ^bb1:  // no predecessors
        yul.yield
      } else {
      }
      yul.yield
    } step {
      yul.yield
    }
    yul.if %cont {
      yul.continue
    ^bb1:  // no predecessors
      yul.yield
    } else {
    }
    yul.if %brk {
      yul.break
    ^bb1:  // no predecessors
      yul.yield
    } else {
    }
    yul.yield
  } step {
    yul.yield
  }
  yul.func_return
}
