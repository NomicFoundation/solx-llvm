// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK:       #[[UNROLL:.*]] = #llvm.loop_unroll<full = true>
// CHECK:       #[[$ANNOT:.*]] = #llvm.loop_annotation<unroll = #[[UNROLL]]>

// CHECK-LABEL: func.func @unrolled()
// CHECK:         %[[C0:.*]] = arith.constant 0 : i256
// CHECK:         %[[C1:.*]] = arith.constant 1 : i256
// CHECK:         cf.br ^[[COND:bb[0-9]+]](%[[C0]] : i256)
// CHECK:       ^[[COND]](%[[I:.*]]: i256):
// CHECK:         cf.cond_br %{{.*}}, ^[[BODY:bb[0-9]+]](%[[I]] : i256), ^[[EXIT:bb[0-9]+]](%[[I]] : i256)
// CHECK:       ^[[BODY]](%[[BI:.*]]: i256):
// CHECK:         cf.br ^[[STEP:bb[0-9]+]](%[[BI]] : i256)
// CHECK:       ^[[STEP]](%[[SI:.*]]: i256):
// CHECK-NEXT:    %[[NEXT:.*]] = arith.addi %[[SI]], %[[C1]] : i256
// CHECK-NEXT:    cf.br ^[[COND]](%[[NEXT]] : i256) {loop_annotation = #[[$ANNOT]]}
// CHECK:       ^[[EXIT]](%{{.*}}: i256):
// CHECK-NEXT:    return

// The body's yul.if results become the loop-carried values.
// CHECK-LABEL: func.func @if_carried
// CHECK:         cf.br ^[[COND:bb[0-9]+]](%{{.*}}, %{{.*}}, %{{.*}} : i256, i256, i256)
// CHECK:       ^[[COND]](%[[I:.*]]: i256, %[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK:         cf.cond_br %{{.*}}, ^[[BODY:bb[0-9]+]](%[[I]], %[[A]], %[[B]] : i256, i256, i256), ^[[EXIT:bb[0-9]+]](%[[I]], %[[A]], %[[B]] : i256, i256, i256)
// CHECK:       ^[[BODY]](%[[BI:.*]]: i256, %[[BA:.*]]: i256, %[[BB:.*]]: i256):
// CHECK:         cf.cond_br %{{.*}}, ^[[THEN:bb[0-9]+]], ^[[ELSE:bb[0-9]+]]
// CHECK:       ^[[ELSE]]:
// CHECK-NEXT:    %[[NB:.*]] = arith.addi %[[BB]], %[[BI]] : i256
// CHECK-NEXT:    cf.br ^[[JOIN:bb[0-9]+]](%[[BA]], %[[NB]] : i256, i256)
// CHECK:       ^[[THEN]]:
// CHECK-NEXT:    %[[NA:.*]] = arith.addi %[[BA]], %[[BI]] : i256
// CHECK-NEXT:    cf.br ^[[JOIN]](%[[NA]], %[[BB]] : i256, i256)
// CHECK:       ^[[JOIN]](%[[RA:.*]]: i256, %[[RB:.*]]: i256):
// CHECK-NEXT:    cf.br ^[[STEP:bb[0-9]+]](%[[BI]], %[[RA]], %[[RB]] : i256, i256, i256)
// CHECK:       ^[[STEP]](%[[SI:.*]]: i256, %[[SA:.*]]: i256, %[[SB:.*]]: i256):
// CHECK-NEXT:    %[[NEXT:.*]] = arith.addi %[[SI]], %{{.*}} : i256
// CHECK-NEXT:    cf.br ^[[COND]](%[[NEXT]], %[[SA]], %[[SB]] : i256, i256, i256)
// CHECK-NOT:     loop_annotation
// CHECK:       ^[[EXIT]](%{{.*}}: i256, %[[EA:.*]]: i256, %[[EB:.*]]: i256):
// CHECK-NEXT:    return %[[EA]], %[[EB]] : i256, i256

yul.func @unrolled : () -> () {
  %c0 = yul.constant 0
  %c1 = yul.constant 1
  %c4 = yul.constant 4
  %0 = yul.for %c0 : i256 -> i256 cond {
  ^bb0(%i: i256):
    %1 = yul.cmp ult, %i, %c4
    yul.condition %1, %i : i256
  } body {
  ^bb0(%i: i256):
    yul.sstore %i, %c0
    yul.yield %i : i256
  } step {
  ^bb0(%i: i256):
    %1 = yul.add %i, %c1
    yul.yield %1 : i256
  } {full_unroll}
  yul.func_return
}
yul.func @if_carried : (i256) -> (i256, i256) {
^bb0(%n: i256):
  %c0 = yul.constant 0
  %c1 = yul.constant 1
  %0:3 = yul.for %c0, %c0, %c0 : i256, i256, i256 -> i256, i256, i256 cond {
  ^bb0(%i: i256, %a: i256, %b: i256):
    %1 = yul.cmp ult, %i, %n
    yul.condition %1, %i, %a, %b : i256, i256, i256
  } body {
  ^bb0(%i: i256, %a: i256, %b: i256):
    %1 = yul.and %i, %c1
    %2:2 = yul.if %1 -> i256, i256 {
      %3 = yul.add %a, %i
      yul.yield %3, %b : i256, i256
    } else {
      %3 = yul.add %b, %i
      yul.yield %a, %3 : i256, i256
    }
    yul.yield %i, %2#0, %2#1 : i256, i256, i256
  } step {
  ^bb0(%i: i256, %a: i256, %b: i256):
    %1 = yul.add %i, %c1
    yul.yield %1, %a, %b : i256, i256, i256
  }
  yul.func_return %0#1, %0#2 : i256, i256
}
