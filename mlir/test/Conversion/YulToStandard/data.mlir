// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test {
// CHECK:       func.func @__entry()
// CHECK-NEXT:    %[[C0:.*]] = arith.constant 0 : i256
// CHECK-NEXT:    %[[OFF:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, metadata = ["Test_deployed"], name = "evm.dataoffset"}> : () -> i256
// CHECK-NEXT:    %[[SIZE:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, metadata = ["Test_deployed"], name = "evm.datasize"}> : () -> i256
// CHECK-NEXT:    %[[DST:.*]] = llvm.inttoptr %[[C0]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[SRC:.*]] = llvm.inttoptr %[[OFF]] : i256 to !llvm.ptr<4>
// CHECK-NEXT:    "llvm.intr.memcpy"(%[[DST]], %[[SRC]], %[[SIZE]]) <{isVolatile = false}> : (!llvm.ptr<1>, !llvm.ptr<4>, i256) -> ()
// CHECK:       module @Test_deployed {

yul.object @Test {
  %c0 = yul.constant 0
  %0 = yul.dataoffset {obj = @Test_deployed}
  %1 = yul.datasize {obj = @Test_deployed}
  yul.codecopy %c0, %0, %1
  yul.object @Test_deployed {
  }
}
