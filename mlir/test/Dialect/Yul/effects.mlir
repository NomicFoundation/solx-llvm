// RUN: mlir-opt %s -canonicalize | FileCheck %s --check-prefix=CANON
// RUN: mlir-opt %s -cse | FileCheck %s --check-prefix=CSE

// CANON-LABEL: yul.func @dead_loads
// CANON:         yul.alloca
// CANON-NEXT:    yul.func_return
yul.func @dead_loads : (i256) -> () {
^bb0(%a: i256):
  %p = yul.alloca : !yul.ptr
  %0 = yul.sload %a
  %1 = yul.tload %a
  %2 = yul.calldataload %a
  %3 = yul.load %p : !yul.ptr -> i256
  %4 = yul.byte %a, %a
  yul.func_return
}

// CSE-LABEL: yul.func @repeated_loads
// CSE:       ^bb0(%[[A:.*]]: i256):
// CSE-DAG:     %[[S:.*]] = yul.sload %[[A]]
// CSE-DAG:     %[[T:.*]] = yul.tload %[[A]]
// CSE-DAG:     %[[C:.*]] = yul.calldataload %[[A]]
// CSE:         yul.func_return %[[S]], %[[S]], %[[T]], %[[T]], %[[C]], %[[C]]
yul.func @repeated_loads : (i256) -> (i256, i256, i256, i256, i256, i256) {
^bb0(%a: i256):
  %0 = yul.sload %a
  %1 = yul.sload %a
  %2 = yul.tload %a
  %3 = yul.tload %a
  %4 = yul.calldataload %a
  %5 = yul.calldataload %a
  yul.func_return %0, %1, %2, %3, %4, %5 : i256, i256, i256, i256, i256, i256
}

// CSE-LABEL: yul.func @load_after_store
// CSE:       ^bb0(%[[A:.*]]: i256, %[[V:.*]]: i256):
// CSE-NEXT:    %[[S0:.*]] = yul.sload %[[A]]
// CSE-NEXT:    %[[C:.*]] = yul.calldataload %[[A]]
// CSE-NEXT:    yul.sstore %[[A]], %[[V]]
// CSE-NEXT:    yul.mstore %[[A]], %[[V]]
// CSE-NEXT:    %[[S1:.*]] = yul.sload %[[A]]
// CSE-NEXT:    yul.func_return %[[S0]], %[[S1]], %[[C]], %[[C]]
yul.func @load_after_store : (i256, i256) -> (i256, i256, i256, i256) {
^bb0(%a: i256, %v: i256):
  %0 = yul.sload %a
  %1 = yul.calldataload %a
  yul.sstore %a, %v
  yul.mstore %a, %v
  %2 = yul.sload %a
  %3 = yul.calldataload %a
  yul.func_return %0, %2, %1, %3 : i256, i256, i256, i256
}
