// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// A `leave` in a Yul for's step ends the region in yul.func_return; the
// lowering keeps it as the return.

// CHECK-LABEL: func.func @leave_in_step
// CHECK:         cf.cond_br %{{.*}}, ^[[BODY:.*]], ^[[EXIT:.*]]
// CHECK:       ^[[BODY]]:
// CHECK:         cf.br ^[[STEP:.*]]
// CHECK:       ^[[STEP]]:
// CHECK-NEXT:    llvm.load
// CHECK-NEXT:    return %
yul.func @leave_in_step : (i256) -> i256 {
^bb0(%arg0: i256):
  %0 = yul.alloca : !yul.ptr
  yul.store %arg0, %0 : i256, !yul.ptr
  %c0 = yul.constant 0
  %1 = yul.alloca : !yul.ptr
  yul.store %c0, %1 : i256, !yul.ptr
  yul.for cond {
    %2 = yul.load %0 : !yul.ptr -> i256
    %3 = yul.load %1 : !yul.ptr -> i256
    %4 = yul.cmp ult, %3, %2
    yul.condition %4
  } body {
    yul.yield
  } step {
    %2 = yul.load %1 : !yul.ptr -> i256
    yul.func_return %2 : i256
  }
  %5 = yul.load %1 : !yul.ptr -> i256
  yul.func_return %5 : i256
}
