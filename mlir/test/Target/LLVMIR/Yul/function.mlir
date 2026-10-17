// RUN: mlir-translate --mlir-to-llvmir %s | FileCheck %s

// CHECK-LABEL: define void @__entry(
// CHECK-SAME: ) #[[$ENTRY:[0-9]+]] {
// CHECK-NEXT: %[[V1:[0-9]+]] = call i256 @llvm.evm.memoryguard()
// CHECK-NEXT: store i256 %[[V1]], ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1)), align 1
// CHECK-NEXT: %[[V2:[0-9]+]] = call { i256, i256 } @pair(i256 0)
// CHECK-NEXT: %[[V3:[0-9]+]] = extractvalue { i256, i256 } %[[V2]], 0
// CHECK-NEXT: %[[V4:[0-9]+]] = extractvalue { i256, i256 } %[[V2]], 1
// CHECK-NEXT: %[[V5:[0-9]+]] = call i256 @linked(i256 %[[V4]])
// CHECK-NEXT: call void @llvm.evm.return(ptr addrspace(1) inttoptr (i256 ptrtoint (ptr addrspace(4) @__data_in_code__0 to i256) to ptr addrspace(1)), i256 %[[V5]])
// CHECK-NEXT: unreachable
// CHECK-NEXT: }
// CHECK-LABEL: define private { i256, i256 } @pair(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #[[$FN:[0-9]+]] {
// CHECK-NEXT: %[[V2:[0-9]+]] = add i256 %[[V0]], 1
// CHECK-NEXT: %[[V3:[0-9]+]] = insertvalue { i256, i256 } poison, i256 %[[V0]], 0
// CHECK-NEXT: %[[V4:[0-9]+]] = insertvalue { i256, i256 } %[[V3]], i256 %[[V2]], 1
// CHECK-NEXT: ret { i256, i256 } %[[V4]]
// CHECK-NEXT: }
// CHECK-LABEL: define internal i256 @linked(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: ret i256 %[[V0]]
// CHECK-NEXT: }
// CHECK-LABEL: define private { i256, i256 } @llvm_ops(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = alloca i256, i256 1, align 8
// CHECK-NEXT: store i256 %[[V0]], ptr %[[V2]], align 32
// CHECK-NEXT: %[[V3:[0-9]+]] = load i256, ptr %[[V2]], align 32
// CHECK-NEXT: %[[V4:[0-9]+]] = insertvalue { i256, i256 } undef, i256 %[[V3]], 0
// CHECK-NEXT: %[[V5:[0-9]+]] = extractvalue { i256, i256 } %[[V4]], 0
// CHECK-NEXT: %[[V6:[0-9]+]] = insertvalue { i256, i256 } %[[V4]], i256 %[[V5]], 1
// CHECK-NEXT: ret { i256, i256 } %[[V6]]
// CHECK-NEXT: }
// CHECK: declare i256 @llvm.evm.memoryguard()
// CHECK: declare void @llvm.evm.return(ptr addrspace(1) readonly, i256)
// CHECK: attributes #[[$ENTRY]] = { nofree null_pointer_is_valid "evm-entry-function" "target-features"="+osaka" }
// CHECK: attributes #[[$FN]] = { nofree null_pointer_is_valid "target-features"="+osaka" }
// CHECK: !llvm.module.flags = !{!0, !1, !2}
// CHECK: !0 = !{i32 1, !"evm-memory-guard", i32 128}
// CHECK: !1 = !{i32 1, !"evm-stack-region-size", i32 0}
// CHECK: !2 = !{i32 2, !"Debug Info Version", i32 3}

module {
  yul.object @Test {
    llvm.mlir.global private unnamed_addr constant @__data_in_code__0("data") {addr_space = 4 : i32}

    // The entry function comes first, with external linkage.
    yul.func @pair : (i256) -> (i256, i256) {
    ^bb0(%x: i256):
      %c1 = yul.constant 1
      %0 = yul.add %x, %c1
      yul.func_return %x, %0 : i256, i256
    }

    yul.func @__entry : () -> () {
      %c0 = yul.constant 0
      %c64 = yul.constant 64
      %0 = yul.memoryguard 128
      yul.mstore %c64, %0
      %1:2 = yul.func_call @pair(%c0) : (i256) -> (i256, i256)
      %2 = yul.func_call @linked(%1#1) : (i256) -> i256
      %3 = llvm.mlir.addressof @__data_in_code__0 : !llvm.ptr<4>
      %4 = llvm.ptrtoint %3 : !llvm.ptr<4> to i256
      yul.return %4, %2
    }

    yul.func @linked : (i256) -> i256 {
    ^bb0(%x: i256):
      yul.func_return %x : i256
    } {llvm.linkage = #llvm.linkage<internal>}

    // LLVM dialect ops translate as they are; a stack slot cast to a Yul
    // pointer is the same pointer.
    yul.func @llvm_ops : (i256) -> !llvm.struct<(i256, i256)> {
    ^bb0(%x: i256):
      %c1 = yul.constant 1
      %0 = llvm.alloca %c1 x i256 : (i256) -> !llvm.ptr
      llvm.store %x, %0 {alignment = 32 : i64} : i256, !llvm.ptr
      %1 = builtin.unrealized_conversion_cast %0 : !llvm.ptr to !yul.ptr
      %2 = yul.load %1 : !yul.ptr -> i256
      %3 = llvm.mlir.undef : !llvm.struct<(i256, i256)>
      %4 = llvm.insertvalue %2, %3[0] : !llvm.struct<(i256, i256)>
      %5 = llvm.extractvalue %4[0] : !llvm.struct<(i256, i256)>
      %6 = llvm.insertvalue %5, %4[1] : !llvm.struct<(i256, i256)>
      yul.func_return %6 : !llvm.struct<(i256, i256)>
    }
  }
}
