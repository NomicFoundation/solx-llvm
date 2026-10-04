// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @library_address
// CHECK:         %[[SYM:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, metadata = ["library.sol:L"], name = "evm.linkersymbol"}> : () -> i256
// CHECK:         arith.andi %[[SYM]], %{{.*}} : i256

yul.func @library_address : () -> i256 {
  %0 = yul.linkersymbol "library.sol:L"
  %c1461501637330902918203684832716283019655932542975_i256 = yul.constant 1461501637330902918203684832716283019655932542975
  %1 = yul.and %0, %c1461501637330902918203684832716283019655932542975_i256
  yul.func_return %1 : i256
}
