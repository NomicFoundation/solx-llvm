// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test {
// CHECK:       func.func @__entry()
// CHECK:         %[[A:.*]] = llvm.load
// CHECK-NEXT:    call @no_ret() : () -> ()
// CHECK-NEXT:    %[[R:.*]] = call @ret(%[[A]]) : (i256) -> i256
// CHECK-NEXT:    %[[R2:.*]]:2 = call @ret2(%[[A]], %[[R]]) : (i256, i256) -> (i256, i256)
// CHECK-NEXT:    %[[P:.*]] = llvm.inttoptr %[[R2]]#0 : i256 to !llvm.ptr<1>
// CHECK-NEXT:    "llvm.intrcall"(%[[P]], %[[R2]]#1) <{id = {{[0-9]+}} : i32, name = "evm.return"}> : (!llvm.ptr<1>, i256) -> ()
yul.object @Test {
  // CHECK-LABEL: func.func @no_ret()
  // CHECK-NEXT:    return
  yul.func @no_ret : () -> () {
    yul.func_return
  }

  // CHECK-LABEL: func.func @ret
  // CHECK-SAME:      (%[[A:.*]]: i256) -> i256
  // CHECK-NEXT:    return %[[A]] : i256
  yul.func @ret : (i256) -> i256 {
  ^bb0(%a: i256):
    yul.func_return %a : i256
  }

  // CHECK-LABEL: func.func @ret2
  // CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> (i256, i256)
  // CHECK-NEXT:    return %[[A]], %[[B]] : i256, i256
  yul.func @ret2 : (i256, i256) -> (i256, i256) {
  ^bb0(%a: i256, %b: i256):
    yul.func_return %a, %b : i256, i256
  }
  yul.func @__entry : () -> () {
    %c0 = yul.constant 0
    %0 = yul.calldataload %c0
    yul.func_call @no_ret() : () -> ()
    %1 = yul.func_call @ret(%0) : (i256) -> i256
    %2:2 = yul.func_call @ret2(%0, %1) : (i256, i256) -> (i256, i256)
    yul.return %2#0, %2#1
    yul.func_return
  }
}
