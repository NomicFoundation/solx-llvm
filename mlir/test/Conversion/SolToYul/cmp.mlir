// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @ui : (i256, i256) -> ()
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK:         yul.cmp eq, %[[A]], %[[B]]
// CHECK:         yul.cmp ne, %[[A]], %[[B]]
// CHECK:         yul.cmp ult, %[[A]], %[[B]]
// CHECK:         yul.cmp ule, %[[A]], %[[B]]
// CHECK:         yul.cmp ugt, %[[A]], %[[B]]
// CHECK:         yul.cmp uge, %[[A]], %[[B]]

// CHECK-LABEL: yul.func @si : (i256, i256) -> ()
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK:         yul.cmp slt, %[[A]], %[[B]]
// CHECK:         yul.cmp sle, %[[A]], %[[B]]
// CHECK:         yul.cmp sgt, %[[A]], %[[B]]
// CHECK:         yul.cmp sge, %[[A]], %[[B]]

// !a: both i1 operands are cleaned before the compare.
// CHECK-LABEL: yul.func @bool : (i256) -> i256
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
// CHECK:         %[[AB:.*]] = yul.cmp ne, %[[A]], %{{.*}}
// CHECK:         %[[F:.*]] = yul.cmp ne, %{{.*}}, %{{.*}}
// CHECK:         %[[NOT:.*]] = yul.cmp eq, %[[AB]], %[[F]]
// CHECK:         yul.func_return %[[NOT]] : i256

// Both bytes4 operands are cleaned to their top 4 bytes.
// CHECK-LABEL: yul.func @fixedbytes : (i256, i256) -> i256
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK:         %[[M:.*]] = yul.constant -26959946667150639794667015087019630673637144422540572481103610249216{{$}}
// CHECK:         %[[CA:.*]] = yul.and %[[A]], %[[M]]
// CHECK:         %[[M2:.*]] = yul.constant -26959946667150639794667015087019630673637144422540572481103610249216{{$}}
// CHECK:         %[[CB:.*]] = yul.and %[[B]], %[[M2]]
// CHECK:         %[[R:.*]] = yul.cmp ult, %[[CA]], %[[CB]]
// CHECK:         yul.func_return %[[R]] : i256

// CHECK-LABEL: yul.func @address : (i256, i256) -> i256
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK:         %[[MA:.*]] = yul.constant 1461501637330902918203684832716283019655932542975
// CHECK:         %[[CA:.*]] = yul.and %[[A]], %[[MA]]
// CHECK:         %[[MB:.*]] = yul.constant 1461501637330902918203684832716283019655932542975
// CHECK:         %[[CB:.*]] = yul.and %[[B]], %[[MB]]
// CHECK:         %[[EQ:.*]] = yul.cmp eq, %[[CA]], %[[CB]]
// CHECK:         yul.func_return %[[EQ]] : i256

// Internal function refs are function ids, compared after cleanup to 64 bits.
// CHECK-LABEL: yul.func @func_ref : (i256, i256) -> i256
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK:         %[[M:.*]] = yul.constant 18446744073709551615
// CHECK:         %[[CA:.*]] = yul.and %[[A]], %[[M]]
// CHECK:         %[[M2:.*]] = yul.constant 18446744073709551615
// CHECK:         %[[CB:.*]] = yul.and %[[B]], %[[M2]]
// CHECK:         %[[C:.*]] = yul.cmp ne, %[[CA]], %[[CB]]
// CHECK:         yul.func_return %[[C]] : i256

// Ext func refs compare the masked address and selector separately: eq
// combines the lanes with and, ne with or.
// CHECK-LABEL: yul.func @ext_func_ref : (!llvm.struct<(i256, i256)>, !llvm.struct<(i256, i256)>) -> (i256, i256)
// CHECK-NEXT:  ^bb0(%[[L:.*]]: !llvm.struct<(i256, i256)>, %[[R:.*]]: !llvm.struct<(i256, i256)>):
// CHECK:         %[[EQA:.*]] = yul.cmp eq
// CHECK:         %[[EQS:.*]] = yul.cmp eq
// CHECK:         %[[EQ:.*]] = yul.and %[[EQA]], %[[EQS]]
// CHECK:         %[[AMASK:.*]] = yul.constant 1461501637330902918203684832716283019655932542975
// CHECK:         %[[LA:.*]] = llvm.extractvalue %[[L]][0]
// CHECK:         %[[RA:.*]] = llvm.extractvalue %[[R]][0]
// CHECK:         %[[LAM:.*]] = yul.and %[[LA]], %[[AMASK]]
// CHECK:         %[[RAM:.*]] = yul.and %[[RA]], %[[AMASK]]
// CHECK:         %[[NEA:.*]] = yul.cmp ne, %[[LAM]], %[[RAM]]
// CHECK:         %[[SMASK:.*]] = yul.constant 4294967295
// CHECK:         %[[LS:.*]] = llvm.extractvalue %[[L]][1]
// CHECK:         %[[RS:.*]] = llvm.extractvalue %[[R]][1]
// CHECK:         %[[LSM:.*]] = yul.and %[[LS]], %[[SMASK]]
// CHECK:         %[[RSM:.*]] = yul.and %[[RS]], %[[SMASK]]
// CHECK:         %[[NES:.*]] = yul.cmp ne, %[[LSM]], %[[RSM]]
// CHECK:         %[[NE:.*]] = yul.or %[[NEA]], %[[NES]]
// CHECK:         yul.func_return %[[EQ]], %[[NE]] : i256, i256

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @ui(%a: ui256, %b: ui256) {
    %0 = sol.cmp eq, %a, %b : ui256
    %1 = sol.cmp ne, %a, %b : ui256
    %2 = sol.cmp lt, %a, %b : ui256
    %3 = sol.cmp le, %a, %b : ui256
    %4 = sol.cmp gt, %a, %b : ui256
    %5 = sol.cmp ge, %a, %b : ui256
    sol.return
  }
  sol.func @si(%a: si256, %b: si256) {
    %0 = sol.cmp lt, %a, %b : si256
    %1 = sol.cmp le, %a, %b : si256
    %2 = sol.cmp gt, %a, %b : si256
    %3 = sol.cmp ge, %a, %b : si256
    sol.return
  }
  sol.func @bool(%a: i1) -> i1 {
    %false = sol.constant false
    %0 = sol.cmp eq, %a, %false : i1
    sol.return %0 : i1
  }
  sol.func @fixedbytes(%a: !sol.fixedbytes<4>, %b: !sol.fixedbytes<4>) -> i1 {
    %0 = sol.cmp lt, %a, %b : !sol.fixedbytes<4>
    sol.return %0 : i1
  }
  sol.func @address(%a: !sol.address, %b: !sol.address) -> i1 {
    %0 = sol.cmp eq, %a, %b : !sol.address
    sol.return %0 : i1
  }
  sol.func @func_ref(%a: !sol.func_ref<() -> ()>, %b: !sol.func_ref<() -> ()>) -> i1 {
    %0 = sol.cmp ne, %a, %b : !sol.func_ref<() -> ()>
    sol.return %0 : i1
  }
  sol.func @ext_func_ref(%a: !sol.ext_func_ref<() -> ui256>, %b: !sol.ext_func_ref<() -> ui256>) -> (i1, i1) {
    %0 = sol.cmp eq, %a, %b : !sol.ext_func_ref<() -> ui256>
    %1 = sol.cmp ne, %a, %b : !sol.ext_func_ref<() -> ui256>
    sol.return %0, %1 : i1, i1
  }
}
