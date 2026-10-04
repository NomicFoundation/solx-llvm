// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @address() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.address"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @address : () -> i256 {
  %0 = yul.address
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @caller() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.caller"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @caller : () -> i256 {
  %0 = yul.caller
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @callvalue() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.callvalue"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @callvalue : () -> i256 {
  %0 = yul.callvalue
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @origin() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.origin"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @origin : () -> i256 {
  %0 = yul.origin
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @gas() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.gas"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @gas : () -> i256 {
  %0 = yul.gas
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @selfbalance() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.selfbalance"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @selfbalance : () -> i256 {
  %0 = yul.selfbalance
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @codesize() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.codesize"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @codesize : () -> i256 {
  %0 = yul.codesize
  yul.func_return %0 : i256
}
