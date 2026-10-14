// RUN: mlir-opt %s --split-input-file --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Foo {
// CHECK-NEXT:    func.func @__entry()
// CHECK-NEXT:      return
// CHECK-NEXT:    }
module {
  yul.object @Foo {
    yul.func @__entry : () -> () {
      yul.func_return
    }
  }
}

// -----

// CHECK-LABEL: module @Foo_deployed {
// CHECK-NEXT:    func.func @__entry()
// CHECK-NEXT:      return
module {
  yul.object @Foo_deployed {
    yul.func @__entry : () -> () {
      yul.func_return
    }
  }
}

// -----

// CHECK-LABEL: module @Test {
// CHECK:         func.func @__entry()
// CHECK:           %[[OFF:.*]] = arith.constant 10 : i256
// CHECK:           %[[LEN:.*]] = arith.constant 11 : i256
// CHECK:           %[[P:.*]] = llvm.inttoptr %[[OFF]] : i256 to !llvm.ptr<1>
// CHECK:           "llvm.intrcall"(%[[P]], %[[LEN]]) <{id = {{[0-9]+}} : i32, name = "evm.return"}>
module {
  yul.object @Test {
    yul.func @__entry : () -> () {
      %c10_i256 = yul.constant 10
      %c11_i256 = yul.constant 11
      yul.return %c10_i256, %c11_i256
      yul.func_return
    }
  }
}

// -----

// CHECK-LABEL: module @Test_deployed {
// CHECK:         func.func @__entry()
// CHECK:           %[[OFF:.*]] = arith.constant 20 : i256
// CHECK:           %[[LEN:.*]] = arith.constant 21 : i256
// CHECK:           %[[P:.*]] = llvm.inttoptr %[[OFF]] : i256 to !llvm.ptr<1>
// CHECK:           "llvm.intrcall"(%[[P]], %[[LEN]]) <{id = {{[0-9]+}} : i32, name = "evm.return"}>
module {
  yul.object @Test_deployed {
    yul.func @__entry : () -> () {
      %c20_i256 = yul.constant 20
      %c21_i256 = yul.constant 21
      yul.return %c20_i256, %c21_i256
      yul.func_return
    }
  }
}
