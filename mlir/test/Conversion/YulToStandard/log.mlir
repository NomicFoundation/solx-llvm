// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: module @Test
// CHECK:         func.func @__entry()
// CHECK:           %[[OFF:.*]] = arith.constant 100 : i256
// CHECK:           %[[LEN:.*]] = arith.constant 5 : i256
// CHECK:           %[[P:.*]] = llvm.inttoptr %[[OFF]] : i256 to !llvm.ptr<1>
// CHECK:           "llvm.intrcall"(%[[P]], %[[LEN]]) <{id = {{[0-9]+}} : i32, name = "evm.log0"}> : (!llvm.ptr<1>, i256) -> ()
// CHECK:           %[[T:.*]] = arith.constant 10 : i256
// CHECK:           "llvm.intrcall"(%{{.*}}, %{{.*}}, %[[T]]) <{id = {{[0-9]+}} : i32, name = "evm.log1"}> : (!llvm.ptr<1>, i256, i256) -> ()
// CHECK:           "llvm.intrcall"({{.*}}) <{id = {{[0-9]+}} : i32, name = "evm.log2"}> : (!llvm.ptr<1>, i256, i256, i256) -> ()
// CHECK:           "llvm.intrcall"({{.*}}) <{id = {{[0-9]+}} : i32, name = "evm.log3"}> : (!llvm.ptr<1>, i256, i256, i256, i256) -> ()
// CHECK:           "llvm.intrcall"({{.*}}) <{id = {{[0-9]+}} : i32, name = "evm.log4"}> : (!llvm.ptr<1>, i256, i256, i256, i256, i256) -> ()

module {
  yul.object @Test {
    %c100_i256 = yul.constant 100
    %c5_i256 = yul.constant 5
    yul.log %c100_i256, %c5_i256
    %c100_i256_0 = yul.constant 100
    %c5_i256_1 = yul.constant 5
    %c10_i256 = yul.constant 10
    yul.log %c100_i256_0, %c5_i256_1 topics(%c10_i256)
    %c100_i256_2 = yul.constant 100
    %c5_i256_3 = yul.constant 5
    %c10_i256_4 = yul.constant 10
    %c11_i256 = yul.constant 11
    yul.log %c100_i256_2, %c5_i256_3 topics(%c10_i256_4, %c11_i256)
    %c100_i256_5 = yul.constant 100
    %c5_i256_6 = yul.constant 5
    %c10_i256_7 = yul.constant 10
    %c11_i256_8 = yul.constant 11
    %c12_i256 = yul.constant 12
    yul.log %c100_i256_5, %c5_i256_6 topics(%c10_i256_7, %c11_i256_8, %c12_i256)
    %c100_i256_9 = yul.constant 100
    %c5_i256_10 = yul.constant 5
    %c10_i256_11 = yul.constant 10
    %c11_i256_12 = yul.constant 11
    %c12_i256_13 = yul.constant 12
    %c13_i256 = yul.constant 13
    yul.log %c100_i256_9, %c5_i256_10 topics(%c10_i256_11, %c11_i256_12, %c12_i256_13, %c13_i256)
  }
}

