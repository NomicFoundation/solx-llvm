// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @nested_scopes
// CHECK-NEXT:    cf.br ^[[OUTER:bb[0-9]+]]
// CHECK:       ^[[OUTER]]:
// CHECK:         llvm.alloca
// CHECK:         cf.br ^[[INNER:bb[0-9]+]]
// CHECK:       ^[[INNER]]:
// CHECK-NEXT:    cf.br ^[[REST:bb[0-9]+]]
// CHECK:       ^[[REST]]:
// CHECK:         call @g(
// CHECK-NEXT:    cf.br ^[[EXIT:bb[0-9]+]]
// CHECK:       ^[[EXIT]]:
// CHECK-NEXT:    return

yul.func @g : (i256) -> () {
^bb0(%arg0: i256):
  yul.func_return
}

yul.func @nested_scopes : (i256) -> () {
^bb0(%arg0: i256):
  yul.scope {
    %c1_i256 = yul.constant 1
    %0 = llvm.alloca %c1_i256 x i256 : (i256) -> !llvm.ptr
    llvm.store %arg0, %0 {alignment = 32 : i64} : i256, !llvm.ptr
    yul.scope {
      yul.leave_scope
    }
    %1 = llvm.load %0 {alignment = 32 : i64} : !llvm.ptr -> i256
    yul.func_call @g(%1) : (i256) -> ()
    yul.leave_scope
  }
  yul.func_return
}
