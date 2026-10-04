// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @basefee() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.basefee"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @basefee : () -> i256 {
  %0 = yul.basefee
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @blobbasefee() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.blobbasefee"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @blobbasefee : () -> i256 {
  %0 = yul.blobbasefee
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @blobhash
// CHECK-SAME:      (%[[IDX:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[IDX]]) <{id = {{[0-9]+}} : i32, name = "evm.blobhash"}> : (i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @blobhash : (i256) -> i256 {
^bb0(%idx: i256):
  %0 = yul.blobhash %idx
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @blockhash
// CHECK-SAME:      (%[[NUM:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[NUM]]) <{id = {{[0-9]+}} : i32, name = "evm.blockhash"}> : (i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @blockhash : (i256) -> i256 {
^bb0(%num: i256):
  %0 = yul.blockhash %num
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @chainid() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.chainid"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @chainid : () -> i256 {
  %0 = yul.chainid
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @coinbase() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.coinbase"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @coinbase : () -> i256 {
  %0 = yul.coinbase
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @gaslimit() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.gaslimit"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @gaslimit : () -> i256 {
  %0 = yul.gaslimit
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @gasprice() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.gasprice"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @gasprice : () -> i256 {
  %0 = yul.gasprice
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @number() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.number"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @number : () -> i256 {
  %0 = yul.number
  yul.func_return %0 : i256
}

// prevrandao reuses the pre-Paris difficulty opcode.
// CHECK-LABEL: func.func @prevrandao() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.difficulty"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @prevrandao : () -> i256 {
  %0 = yul.prevrandao
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @timestamp() -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"() <{id = {{[0-9]+}} : i32, name = "evm.timestamp"}> : () -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @timestamp : () -> i256 {
  %0 = yul.timestamp
  yul.func_return %0 : i256
}
