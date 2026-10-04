// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @call
// CHECK-SAME:      (%[[GAS:.*]]: i256, %[[ADDR:.*]]: i256, %[[VAL:.*]]: i256, %[[IN:.*]]: i256, %[[INSZ:.*]]: i256, %[[OUT:.*]]: i256, %[[OUTSZ:.*]]: i256) -> i256
// CHECK-NEXT:    %[[INP:.*]] = llvm.inttoptr %[[IN]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[OUTP:.*]] = llvm.inttoptr %[[OUT]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[GAS]], %[[ADDR]], %[[VAL]], %[[INP]], %[[INSZ]], %[[OUTP]], %[[OUTSZ]]) <{id = {{[0-9]+}} : i32, name = "evm.call"}> : (i256, i256, i256, !llvm.ptr<1>, i256, !llvm.ptr<1>, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @call : (i256, i256, i256, i256, i256, i256, i256) -> i256 {
^bb0(%gas: i256, %addr: i256, %val: i256, %in: i256, %insz: i256, %out: i256, %outsz: i256):
  %0 = yul.call %gas, %addr, %val, %in, %insz, %out, %outsz
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @callcode
// CHECK-SAME:      (%[[GAS:.*]]: i256, %[[ADDR:.*]]: i256, %[[VAL:.*]]: i256, %[[IN:.*]]: i256, %[[INSZ:.*]]: i256, %[[OUT:.*]]: i256, %[[OUTSZ:.*]]: i256) -> i256
// CHECK-NEXT:    %[[INP:.*]] = llvm.inttoptr %[[IN]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[OUTP:.*]] = llvm.inttoptr %[[OUT]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[GAS]], %[[ADDR]], %[[VAL]], %[[INP]], %[[INSZ]], %[[OUTP]], %[[OUTSZ]]) <{id = {{[0-9]+}} : i32, name = "evm.callcode"}> : (i256, i256, i256, !llvm.ptr<1>, i256, !llvm.ptr<1>, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @callcode : (i256, i256, i256, i256, i256, i256, i256) -> i256 {
^bb0(%gas: i256, %addr: i256, %val: i256, %in: i256, %insz: i256, %out: i256, %outsz: i256):
  %0 = yul.callcode %gas, %addr, %val, %in, %insz, %out, %outsz
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @staticcall
// CHECK-SAME:      (%[[GAS:.*]]: i256, %[[ADDR:.*]]: i256, %[[IN:.*]]: i256, %[[INSZ:.*]]: i256, %[[OUT:.*]]: i256, %[[OUTSZ:.*]]: i256) -> i256
// CHECK-NEXT:    %[[INP:.*]] = llvm.inttoptr %[[IN]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[OUTP:.*]] = llvm.inttoptr %[[OUT]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[GAS]], %[[ADDR]], %[[INP]], %[[INSZ]], %[[OUTP]], %[[OUTSZ]]) <{id = {{[0-9]+}} : i32, name = "evm.staticcall"}> : (i256, i256, !llvm.ptr<1>, i256, !llvm.ptr<1>, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @staticcall : (i256, i256, i256, i256, i256, i256) -> i256 {
^bb0(%gas: i256, %addr: i256, %in: i256, %insz: i256, %out: i256, %outsz: i256):
  %0 = yul.static_call %gas, %addr, %in, %insz, %out, %outsz
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @delegatecall
// CHECK-SAME:      (%[[GAS:.*]]: i256, %[[ADDR:.*]]: i256, %[[IN:.*]]: i256, %[[INSZ:.*]]: i256, %[[OUT:.*]]: i256, %[[OUTSZ:.*]]: i256) -> i256
// CHECK-NEXT:    %[[INP:.*]] = llvm.inttoptr %[[IN]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[OUTP:.*]] = llvm.inttoptr %[[OUT]] : i256 to !llvm.ptr<1>
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[GAS]], %[[ADDR]], %[[INP]], %[[INSZ]], %[[OUTP]], %[[OUTSZ]]) <{id = {{[0-9]+}} : i32, name = "evm.delegatecall"}> : (i256, i256, !llvm.ptr<1>, i256, !llvm.ptr<1>, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @delegatecall : (i256, i256, i256, i256, i256, i256) -> i256 {
^bb0(%gas: i256, %addr: i256, %in: i256, %insz: i256, %out: i256, %outsz: i256):
  %0 = yul.delegate_call %gas, %addr, %in, %insz, %out, %outsz
  yul.func_return %0 : i256
}
