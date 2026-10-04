// RUN: mlir-opt %s --split-input-file --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Foo attributes
// CHECK-NEXT:    func.func @__entry()
// CHECK-NEXT:      llvm.unreachable
// CHECK-NEXT:    }
// CHECK-NEXT:    module @Foo_deployed attributes
// CHECK-NEXT:      func.func @__entry()
// CHECK-NEXT:        llvm.unreachable

// CHECK-LABEL: module @Test attributes
// CHECK:         func.func @__entry()
// CHECK:           %[[OFF:.*]] = arith.constant 10 : i256
// CHECK:           %[[LEN:.*]] = arith.constant 11 : i256
// CHECK:           %[[P:.*]] = llvm.inttoptr %[[OFF]] : i256 to !llvm.ptr<1>
// CHECK:           "llvm.intrcall"(%[[P]], %[[LEN]]) <{id = {{[0-9]+}} : i32, name = "evm.return"}>
// CHECK:         module @Test_deployed attributes
// CHECK:           func.func @__entry()
// CHECK:             %[[OFF:.*]] = arith.constant 20 : i256
// CHECK:             %[[LEN:.*]] = arith.constant 21 : i256
// CHECK:             %[[P:.*]] = llvm.inttoptr %[[OFF]] : i256 to !llvm.ptr<1>
// CHECK:             "llvm.intrcall"(%[[P]], %[[LEN]]) <{id = {{[0-9]+}} : i32, name = "evm.return"}>

module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown"} {
  yul.object @Foo {
    yul.object @Foo_deployed {
    }
  }
}

// -----
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown"} {
  yul.object @Test {
    %c10_i256 = yul.constant 10
    %c11_i256 = yul.constant 11
    yul.return %c10_i256, %c11_i256
    yul.object @Test_deployed {
      %c20_i256 = yul.constant 20
      %c21_i256 = yul.constant 21
      yul.return %c20_i256, %c21_i256
    }
  }
}
