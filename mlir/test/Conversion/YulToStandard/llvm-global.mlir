// RUN: mlir-opt %s --split-input-file --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test {
// CHECK:         func.func @__entry()
// CHECK:           %[[G:.*]] = llvm.mlir.addressof @__data_in_code__0 : !llvm.ptr<4>
// CHECK-NEXT:      %[[GI:.*]] = llvm.ptrtoint %[[G]] : !llvm.ptr<4> to i256
// CHECK:           %[[SRC:.*]] = llvm.inttoptr %[[GI]] : i256 to !llvm.ptr<4>
// CHECK-NEXT:      "llvm.intr.memcpy"(%{{.*}}, %[[SRC]], %{{.*}})
// CHECK:           llvm.unreachable
// CHECK-NEXT:    }
// CHECK-NEXT:    llvm.mlir.global private unnamed_addr constant @__data_in_code__0("abc") {addr_space = 4 : i32}
// CHECK-NOT:     llvm.mlir.global

module {
  yul.object @Test {
    llvm.mlir.global private unnamed_addr constant @__data_in_code__0("abc") {addr_space = 4 : i32}
    yul.func @__entry : () -> () {
      %c0_i256 = yul.constant 0
      %c3_i256 = yul.constant 3
      %0 = llvm.mlir.addressof @__data_in_code__0 : !llvm.ptr<4>
      %1 = llvm.ptrtoint %0 : !llvm.ptr<4> to i256
      yul.codecopy %c0_i256, %1, %c3_i256
      yul.return %c0_i256, %c3_i256
    }
  }
}

// -----

// CHECK-LABEL: module @Test_deployed {
// CHECK-NEXT:    func.func @__entry()
// CHECK:           %[[G:.*]] = llvm.mlir.addressof @__data_in_code__0 : !llvm.ptr<4>
// CHECK-NEXT:      %[[GI:.*]] = llvm.ptrtoint %[[G]] : !llvm.ptr<4> to i256
// CHECK:           %[[SRC:.*]] = llvm.inttoptr %[[GI]] : i256 to !llvm.ptr<4>
// CHECK-NEXT:      "llvm.intr.memcpy"(%{{.*}}, %[[SRC]], %{{.*}})
// CHECK:           llvm.unreachable
// CHECK-NEXT:    }
// CHECK-NEXT:    llvm.mlir.global private unnamed_addr constant @__data_in_code__0("wxyz") {addr_space = 4 : i32}
// CHECK-NOT:     llvm.mlir.global

module {
  yul.object @Test_deployed {
    llvm.mlir.global private unnamed_addr constant @__data_in_code__0("wxyz") {addr_space = 4 : i32}
    yul.func @__entry : () -> () {
      %c0_i256_0 = yul.constant 0
      %c4_i256 = yul.constant 4
      %2 = llvm.mlir.addressof @__data_in_code__0 : !llvm.ptr<4>
      %3 = llvm.ptrtoint %2 : !llvm.ptr<4> to i256
      yul.codecopy %c0_i256_0, %3, %c4_i256
      yul.return %c0_i256_0, %c4_i256
    }
  }
}
