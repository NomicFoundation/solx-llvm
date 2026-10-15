// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s
// RUN: mlir-opt %s --convert-yul-to-std -mlir-print-debuginfo \
// RUN:   -mlir-print-local-scope | FileCheck --check-prefix=LOC %s

// A halting op ends its block with llvm.unreachable, at the op's location,
// and takes what followed it in the block with it.

// CHECK-LABEL: func.func @halts
// CHECK:         "llvm.intrcall"(%{{.*}}, %{{.*}}) <{{{.*}}name = "evm.revert"}>
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  }
// CHECK-NOT:   mstore
// CHECK-NOT:   .unreachable
// LOC-LABEL:   func.func @halts
// LOC:           llvm.unreachable loc("A.sol":2:5)
func.func @halts(%x: i256) {
  %c0 = arith.constant 0 : i256
  yul.revert %c0, %c0 loc("A.sol":2:5)
  yul.mstore %x, %x
  return
}

// CHECK-LABEL: func.func @returns
// CHECK:         "llvm.intrcall"(%{{.*}}, %{{.*}}) <{{{.*}}name = "evm.return"}>
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  }
func.func @returns() {
  %c0 = arith.constant 0 : i256
  yul.return %c0, %c0
  return
}

// CHECK-LABEL: func.func @stops
// CHECK:         "llvm.intrcall"() <{{{.*}}name = "evm.stop"}>
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  }
func.func @stops() {
  yul.stop
  return
}

// CHECK-LABEL: func.func @invalid
// CHECK:         "llvm.intrcall"() <{{{.*}}name = "evm.invalid"}>
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  }
func.func @invalid() {
  yul.invalid
  return
}

// CHECK-LABEL: func.func @selfdestructs
// CHECK-SAME:  (%[[ADDR:.*]]: i256
// CHECK:         "llvm.intrcall"(%[[ADDR]]) <{{{.*}}name = "evm.selfdestruct"}>
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  }
func.func @selfdestructs(%addr: i256) {
  yul.selfdestruct %addr
  return
}

// The continuation of an if with one halting branch stays.

// CHECK-LABEL: func.func @if_one_branch_halts
// CHECK-SAME:  (%[[C:.*]]: i256{{.*}}, %[[X:.*]]: i256
// CHECK:         cf.cond_br %{{.*}}, ^[[THEN:.*]], ^[[CONT:.*]]
// CHECK:       ^[[THEN]]:
// CHECK:         "llvm.intrcall"({{.*}}name = "evm.revert"}>
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  ^[[CONT]]:
// CHECK:         llvm.store %[[X]]
// CHECK-NEXT:    return
func.func @if_one_branch_halts(%c: i256, %x: i256) {
  %c0 = arith.constant 0 : i256
  yul.if %c {
    yul.revert %c0, %c0
    yul.yield
  } else {
  }
  yul.mstore %x, %x
  return
}

// With both branches halting, the continuation and everything it led to go.

// CHECK-LABEL: func.func @if_both_branches_halt
// CHECK:         cf.cond_br %{{.*}}, ^[[THEN:bb[0-9]+]], ^[[ELSE:bb[0-9]+]]
// CHECK:       ^[[ELSE]]:
// CHECK:         "llvm.intrcall"({{.*}}name = "evm.return"}>
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  ^[[THEN]]:
// CHECK:         "llvm.intrcall"({{.*}}name = "evm.revert"}>
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  }
func.func @if_both_branches_halt(%c: i256, %x: i256, %y: i256) {
  %c0 = arith.constant 0 : i256
  yul.if %c {
    yul.revert %c0, %c0
    yul.yield
  } else {
    yul.return %c0, %c0
    yul.yield
  }
  yul.if %y {
    yul.mstore %x, %x
    yul.yield
  } else {
  }
  yul.mstore %y, %y
  return
}

// A halting loop body drops the step; the condition keeps its entry.

// CHECK-LABEL: func.func @loop_body_halts
// CHECK:         cf.br ^[[COND:bb[0-9]+]]
// CHECK:       ^[[COND]](
// CHECK:         cf.cond_br %{{.*}}, ^[[BODY:bb[0-9]+]](%{{.*}}), ^[[EXIT:bb[0-9]+]](
// CHECK:       ^[[BODY]](
// CHECK:         "llvm.intrcall"({{.*}}name = "evm.revert"}>
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  ^[[EXIT]](
// CHECK-NEXT:    return
func.func @loop_body_halts(%n: i256) {
  %c0 = arith.constant 0 : i256
  %c1 = arith.constant 1 : i256
  yul.for %c0 : i256 -> i256 cond {
  ^bb0(%i: i256):
    %lt = yul.cmp ult, %i, %n
    yul.condition %lt, %i : i256
  } body {
  ^bb0(%i: i256):
    yul.revert %c0, %c0
    yul.yield %i : i256
  } step {
  ^bb0(%i: i256):
    %next = yul.add %i, %c1
    yul.yield %next : i256
  }
  return
}

// Structured ops after a halting op go with it, regions and all.

// CHECK-LABEL: func.func @loop_after_halt
// CHECK:         "llvm.intrcall"({{.*}}name = "evm.stop"}>
// CHECK-NEXT:    llvm.unreachable
// CHECK-NEXT:  }
func.func @loop_after_halt(%n: i256) {
  %c0 = arith.constant 0 : i256
  %c1 = arith.constant 1 : i256
  yul.stop
  yul.for %c0 : i256 -> i256 cond {
  ^bb0(%i: i256):
    %lt = yul.cmp ult, %i, %n
    yul.condition %lt, %i : i256
  } body {
  ^bb0(%i: i256):
    yul.mstore %i, %i
    yul.yield %i : i256
  } step {
  ^bb0(%i: i256):
    %next = yul.add %i, %c1
    yul.yield %next : i256
  }
  return
}
