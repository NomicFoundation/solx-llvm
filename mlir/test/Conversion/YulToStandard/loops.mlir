// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @while_break_continue
// CHECK-SAME:      (%[[C:.*]]: i256, %[[BRK_C:.*]]: i256, %[[CONT_C:.*]]: i256)
// CHECK-NEXT:    cf.br ^[[COND:bb[0-9]+]]
// CHECK:       ^[[COND]]:
// CHECK:         %[[CV:.*]] = arith.cmpi ne, %[[C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[CV]], ^[[BODY:bb[0-9]+]], ^[[EXIT:bb[0-9]+]]
// CHECK:       ^[[BODY]]:
// CHECK:         %[[BRKV:.*]] = arith.cmpi ne, %[[BRK_C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[BRKV]], ^[[BRK:bb[0-9]+]], ^{{bb[0-9]+}}
// CHECK:       ^[[BRK]]:
// CHECK-NEXT:    cf.br ^[[EXIT]]
// CHECK:         %[[CONTV:.*]] = arith.cmpi ne, %[[CONT_C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[CONTV]], ^[[CONT:bb[0-9]+]], ^{{bb[0-9]+}}
// CHECK:       ^[[CONT]]:
// CHECK-NEXT:    cf.br ^[[COND]]
// CHECK:         cf.br ^[[COND]]
// CHECK:       ^[[EXIT]]:
// CHECK-NEXT:    return
yul.func @while_break_continue : (i256, i256, i256) -> () {
^bb0(%c: i256, %brk: i256, %cont: i256):
  yul.while {
    yul.condition %c
  } do {
    yul.if %brk {
      yul.break
    ^bb1:  // no predecessors
      yul.yield
    } else {
    }
    yul.if %cont {
      yul.continue
    ^bb1:  // no predecessors
      yul.yield
    } else {
    }
    yul.yield
  }
  yul.func_return
}

// The body runs before the first condition check.
// CHECK-LABEL: func.func @do_while
// CHECK-SAME:      (%[[C:.*]]: i256)
// CHECK-NEXT:    cf.br ^[[BODY:bb[0-9]+]]
// CHECK:       ^[[COND:bb[0-9]+]]:
// CHECK:         %[[CV:.*]] = arith.cmpi ne, %[[C]], %{{.*}} : i256
// CHECK-NEXT:    cf.cond_br %[[CV]], ^[[BODY]], ^[[EXIT:bb[0-9]+]]
// CHECK:       ^[[BODY]]:
// CHECK-NEXT:    cf.br ^[[COND]]
// CHECK:       ^[[EXIT]]:
// CHECK-NEXT:    return
yul.func @do_while : (i256) -> () {
^bb0(%c: i256):
  yul.do {
    yul.yield
  } while {
    yul.condition %c
  }
  yul.func_return
}

// A break ending the body's entry block leaves the body's next block dead.
// CHECK-LABEL: func.func @break_in_body
// CHECK:         cf.br ^[[COND:bb[0-9]+]]
// CHECK:       ^[[COND]]:
// CHECK:         cf.cond_br %{{.*}}, ^[[BODY:bb[0-9]+]], ^[[EXIT:bb[0-9]+]]
// CHECK:       ^[[BODY]]:
// CHECK-NEXT:    cf.br ^[[EXIT]]
// CHECK:       ^{{bb[0-9]+}}:  // no predecessors
// CHECK-NEXT:    cf.br ^[[COND]]
// CHECK:       ^[[EXIT]]:
// CHECK-NEXT:    return
yul.func @break_in_body : (i256) -> () {
^bb0(%arg0: i256):
  yul.while {
    yul.condition %arg0
  } do {
    yul.break
  ^bb1:
    yul.yield
  }
  yul.func_return
}

// CHECK-LABEL: func.func @while_iter_args
// CHECK-SAME:      (%[[B:.*]]: i256, %[[E:.*]]: i256, %[[N:.*]]: i256) -> i256
// CHECK:         cf.br ^[[COND:bb[0-9]+]](%[[B]], %[[E]], %[[N]] : i256, i256, i256)
// CHECK:       ^[[COND]](%[[CR:.*]]: i256, %[[CB:.*]]: i256, %[[CN:.*]]: i256):
// CHECK:         cf.cond_br %{{.*}}, ^[[BODY:bb[0-9]+]](%[[CR]], %[[CB]], %[[CN]] : i256, i256, i256), ^[[EXIT:bb[0-9]+]](%[[CR]], %[[CB]], %[[CN]] : i256, i256, i256)
// CHECK:       ^[[BODY]](%{{.*}}: i256, %{{.*}}: i256, %{{.*}}: i256):
// CHECK:         %[[R:.*]] = arith.select
// CHECK:         %[[SQ:.*]] = arith.muli
// CHECK:         %[[SH:.*]] = arith.shrui
// CHECK:         cf.br ^[[COND]](%[[R]], %[[SQ]], %[[SH]] : i256, i256, i256)
// CHECK:       ^[[EXIT]](%[[RES:.*]]: i256, %{{.*}}: i256, %{{.*}}: i256):
// CHECK-NEXT:    return %[[RES]] : i256
yul.func @while_iter_args : (i256, i256, i256) -> i256 {
^bb0(%arg0: i256, %arg1: i256, %arg2: i256):
  %c1_i256 = yul.constant 1
  %0:3 = yul.while %arg0, %arg1, %arg2 : i256, i256, i256 -> i256, i256, i256 {
  ^bb0(%arg3: i256, %arg4: i256, %arg5: i256):
    %1 = yul.cmp ugt, %arg5, %c1_i256
    yul.condition %1, %arg3, %arg4, %arg5 : i256, i256, i256
  } do {
  ^bb0(%arg3: i256, %arg4: i256, %arg5: i256):
    %1 = yul.and %arg5, %c1_i256
    %c0_i256 = yul.constant 0
    %2 = yul.cmp ne, %1, %c0_i256
    %3 = yul.mul %arg3, %arg4
    %4 = yul.arith_select %2, %3, %arg3
    %5 = yul.mul %arg4, %arg4
    %6 = yul.arith_shr %arg5, %c1_i256
    yul.yield %4, %5, %6 : i256, i256, i256
  }
  yul.func_return %0#0 : i256
}
