// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @sload
// CHECK-SAME:      (%[[SLOT:.*]]: i256) -> i256
// CHECK-NEXT:    %[[P:.*]] = llvm.inttoptr %[[SLOT]] : i256 to !llvm.ptr<5>
// CHECK-NEXT:    %[[V:.*]] = llvm.load %[[P]] {alignment = 1 : i64} : !llvm.ptr<5> -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @sload : (i256) -> i256 {
^bb0(%slot: i256):
  %0 = yul.sload %slot
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @sstore
// CHECK-SAME:      (%[[SLOT:.*]]: i256, %[[V:.*]]: i256)
// CHECK-NEXT:    %[[P:.*]] = llvm.inttoptr %[[SLOT]] : i256 to !llvm.ptr<5>
// CHECK-NEXT:    llvm.store %[[V]], %[[P]] {alignment = 1 : i64} : i256, !llvm.ptr<5>
// CHECK-NEXT:    return
yul.func @sstore : (i256, i256) -> () {
^bb0(%slot: i256, %v: i256):
  yul.sstore %slot, %v
  yul.func_return
}

// CHECK-LABEL: func.func @tload
// CHECK-SAME:      (%[[SLOT:.*]]: i256) -> i256
// CHECK-NEXT:    %[[P:.*]] = llvm.inttoptr %[[SLOT]] : i256 to !llvm.ptr<6>
// CHECK-NEXT:    %[[V:.*]] = llvm.load %[[P]] {alignment = 1 : i64} : !llvm.ptr<6> -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @tload : (i256) -> i256 {
^bb0(%slot: i256):
  %0 = yul.tload %slot
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @tstore
// CHECK-SAME:      (%[[SLOT:.*]]: i256, %[[V:.*]]: i256)
// CHECK-NEXT:    %[[P:.*]] = llvm.inttoptr %[[SLOT]] : i256 to !llvm.ptr<6>
// CHECK-NEXT:    llvm.store %[[V]], %[[P]] {alignment = 1 : i64} : i256, !llvm.ptr<6>
// CHECK-NEXT:    return
yul.func @tstore : (i256, i256) -> () {
^bb0(%slot: i256, %v: i256):
  yul.tstore %slot, %v
  yul.func_return
}
