// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// !llvm.struct values and the llvm ops on them pass through unchanged.

// CHECK-LABEL: func.func @make
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> !llvm.struct<(i256, i256)>
// CHECK:         %[[U:.*]] = llvm.mlir.undef : !llvm.struct<(i256, i256)>
// CHECK-NEXT:    %[[I0:.*]] = llvm.insertvalue %[[A]], %[[U]][0] : !llvm.struct<(i256, i256)>
// CHECK-NEXT:    %[[I1:.*]] = llvm.insertvalue %[[B]], %[[I0]][1] : !llvm.struct<(i256, i256)>
// CHECK-NEXT:    return %[[I1]] : !llvm.struct<(i256, i256)>
yul.func @make : (i256, i256) -> !llvm.struct<(i256, i256)> {
^bb0(%arg0: i256, %arg1: i256):
  %0 = llvm.mlir.undef : !llvm.struct<(i256, i256)>
  %1 = llvm.insertvalue %arg0, %0[0] : !llvm.struct<(i256, i256)>
  %2 = llvm.insertvalue %arg1, %1[1] : !llvm.struct<(i256, i256)>
  yul.func_return %2 : !llvm.struct<(i256, i256)>
}

// CHECK-LABEL: func.func @sum
// CHECK-SAME:      (%[[S:.*]]: !llvm.struct<(i256, i256)>) -> i256
// CHECK:         %[[X:.*]] = llvm.extractvalue %[[S]][0] : !llvm.struct<(i256, i256)>
// CHECK-NEXT:    %[[Y:.*]] = llvm.extractvalue %[[S]][1] : !llvm.struct<(i256, i256)>
// CHECK-NEXT:    %[[R:.*]] = arith.addi %[[X]], %[[Y]] : i256
// CHECK-NEXT:    return %[[R]] : i256
yul.func @sum : (!llvm.struct<(i256, i256)>) -> i256 {
^bb0(%arg0: !llvm.struct<(i256, i256)>):
  %0 = llvm.extractvalue %arg0[0] : !llvm.struct<(i256, i256)>
  %1 = llvm.extractvalue %arg0[1] : !llvm.struct<(i256, i256)>
  %2 = yul.add %0, %1
  yul.func_return %2 : i256
}

// CHECK-LABEL: func.func @if_result
// CHECK:         cf.cond_br %{{.*}}, ^[[THEN:bb[0-9]+]], ^[[ELSE:bb[0-9]+]]
// CHECK:       ^[[ELSE]]:
// CHECK-NEXT:    %[[C0:.*]] = call @make
// CHECK-NEXT:    cf.br ^[[JOIN:bb[0-9]+]](%[[C0]] : !llvm.struct<(i256, i256)>)
// CHECK:       ^[[THEN]]:
// CHECK-NEXT:    %[[C1:.*]] = call @make
// CHECK-NEXT:    cf.br ^[[JOIN]](%[[C1]] : !llvm.struct<(i256, i256)>)
// CHECK:       ^[[JOIN]](%[[V:.*]]: !llvm.struct<(i256, i256)>):
// CHECK-NEXT:    %[[R:.*]] = call @sum(%[[V]]) : (!llvm.struct<(i256, i256)>) -> i256
// CHECK-NEXT:    return %[[R]] : i256
yul.func @if_result : (i256, i256) -> i256 {
^bb0(%arg0: i256, %arg1: i256):
  %0 = yul.if %arg0 -> !llvm.struct<(i256, i256)> {
    %1 = yul.func_call @make(%arg0, %arg1) : (i256, i256) -> !llvm.struct<(i256, i256)>
    yul.yield %1 : !llvm.struct<(i256, i256)>
  } else {
    %1 = yul.func_call @make(%arg1, %arg0) : (i256, i256) -> !llvm.struct<(i256, i256)>
    yul.yield %1 : !llvm.struct<(i256, i256)>
  }
  %3 = yul.func_call @sum(%0) : (!llvm.struct<(i256, i256)>) -> i256
  yul.func_return %3 : i256
}
