// RUN: mlir-translate --mlir-to-llvmir %s | FileCheck %s

// CHECK-LABEL: define void @__entry(
// CHECK-SAME: ) #{{[0-9]+}} {
// CHECK-NEXT: call void @llvm.evm.stop()
// CHECK-NEXT: unreachable
// CHECK-NEXT: }
// CHECK-LABEL: define private void @cmp_cond(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V3:[0-9]+]] = icmp ult i256 %[[V0]], %[[V1]]
// CHECK-NEXT: %[[V4:[0-9]+]] = zext i1 %[[V3]] to i256
// CHECK-NEXT: br i1 %[[V3]], label %[[V5:[0-9]+]], label %[[V7:[0-9]+]]
// CHECK: [[V5]]:
// CHECK-NEXT: %[[V6:[0-9]+]] = inttoptr i256 %[[V0]] to ptr addrspace(5)
// CHECK-NEXT: store i256 %[[V1]], ptr addrspace(5) %[[V6]], align 1
// CHECK-NEXT: br label %[[V7]]
// CHECK: [[V7]]:
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private i256 @not_select(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]], i256 %[[V2:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V4:[0-9]+]] = xor i256 %[[V1]], -1
// CHECK-NEXT: %[[V5:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: %[[V6:[0-9]+]] = select i1 %[[V5]], i256 %[[V4]], i256 %[[V2]]
// CHECK-NEXT: ret i256 %[[V6]]
// CHECK-NEXT: }
// CHECK-LABEL: define private i256 @sub_of_add(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V3:[0-9]+]] = add i256 %[[V0]], 32
// CHECK-NEXT: %[[V4:[0-9]+]] = add i256 %[[V1]], 32
// CHECK-NEXT: ret i256 %[[V4]]
// CHECK-NEXT: }
// CHECK-LABEL: define private i256 @sub_self(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V3:[0-9]+]] = add i256 %[[V1]], 0
// CHECK-NEXT: ret i256 %[[V3]]
// CHECK-NEXT: }
// CHECK-LABEL: define private i256 @and_not(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = xor i256 %[[V0]], -1
// CHECK-NEXT: ret i256 0
// CHECK-NEXT: }
// CHECK-LABEL: define private i256 @select_cmp(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V3:[0-9]+]] = icmp eq i256 %[[V0]], %[[V1]]
// CHECK-NEXT: %[[V4:[0-9]+]] = zext i1 %[[V3]] to i256
// CHECK-NEXT: ret i256 %[[V1]]
// CHECK-NEXT: }
// CHECK-LABEL: define private void @constant_cond(
// CHECK-SAME: ) #{{[0-9]+}} {
// CHECK-NEXT: br i1 true, label %[[V1:[0-9]+]], label %[[V2:[0-9]+]]
// CHECK: [[V1]]:
// CHECK-NEXT: call void @llvm.evm.invalid()
// CHECK-NEXT: unreachable
// CHECK: [[V2]]:
// CHECK-NEXT: ret void
// CHECK-NEXT: }
// CHECK-LABEL: define private { i256, i256, i256, i256 } @add(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V3:[0-9]+]] = sub i256 %[[V0]], %[[V1]]
// CHECK-NEXT: %[[V4:[0-9]+]] = insertvalue { i256, i256, i256, i256 } poison, i256 %[[V0]], 0
// CHECK-NEXT: %[[V5:[0-9]+]] = insertvalue { i256, i256, i256, i256 } %[[V4]], i256 %[[V0]], 1
// CHECK-NEXT: %[[V6:[0-9]+]] = insertvalue { i256, i256, i256, i256 } %[[V5]], i256 %[[V0]], 2
// CHECK-NEXT: %[[V7:[0-9]+]] = insertvalue { i256, i256, i256, i256 } %[[V6]], i256 7, 3
// CHECK-NEXT: ret { i256, i256, i256, i256 } %[[V7]]
// CHECK-NEXT: }
// CHECK-LABEL: define private { i256, i256, i256 } @mul(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = insertvalue { i256, i256, i256 } { i256 0, i256 poison, i256 poison }, i256 %[[V0]], 1
// CHECK-NEXT: %[[V3:[0-9]+]] = insertvalue { i256, i256, i256 } %[[V2]], i256 12, 2
// CHECK-NEXT: ret { i256, i256, i256 } %[[V3]]
// CHECK-NEXT: }
// CHECK-LABEL: define private { i256, i256, i256, i256, i256, i256 } @div(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = udiv i256 %[[V0]], 0
// CHECK-NEXT: %[[V3:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256, i256 } poison, i256 %[[V0]], 0
// CHECK-NEXT: %[[V4:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256, i256 } %[[V3]], i256 3, 1
// CHECK-NEXT: %[[V5:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256, i256 } %[[V4]], i256 %[[V0]], 2
// CHECK-NEXT: %[[V6:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256, i256 } %[[V5]], i256 3, 3
// CHECK-NEXT: %[[V7:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256, i256 } %[[V6]], i256 %[[V2]], 4
// CHECK-NEXT: %[[V8:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256, i256 } %[[V7]], i256 poison, 5
// CHECK-NEXT: ret { i256, i256, i256, i256, i256, i256 } %[[V8]]
// CHECK-NEXT: }
// CHECK-LABEL: define private { i256, i256, i256, i256, i256 } @rem(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = urem i256 %[[V0]], 0
// CHECK-NEXT: %[[V3:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } { i256 0, i256 1, i256 0, i256 -1, i256 poison }, i256 %[[V2]], 4
// CHECK-NEXT: ret { i256, i256, i256, i256, i256 } %[[V3]]
// CHECK-NEXT: }
// CHECK-LABEL: define private { i256, i256, i256, i256, i256 } @shift(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = shl i256 %[[V0]], 256
// CHECK-NEXT: %[[V3:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } poison, i256 %[[V0]], 0
// CHECK-NEXT: %[[V4:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } %[[V3]], i256 16, 1
// CHECK-NEXT: %[[V5:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } %[[V4]], i256 16, 2
// CHECK-NEXT: %[[V6:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } %[[V5]], i256 -16, 3
// CHECK-NEXT: %[[V7:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } %[[V6]], i256 %[[V2]], 4
// CHECK-NEXT: ret { i256, i256, i256, i256, i256 } %[[V7]]
// CHECK-NEXT: }
// CHECK-LABEL: define private { i256, i256, i256, i256, i256 } @and(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V3:[0-9]+]] = and i256 %[[V0]], %[[V1]]
// CHECK-NEXT: %[[V4:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } { i256 0, i256 poison, i256 poison, i256 poison, i256 poison }, i256 %[[V0]], 1
// CHECK-NEXT: %[[V5:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } %[[V4]], i256 %[[V0]], 2
// CHECK-NEXT: %[[V6:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } %[[V5]], i256 %[[V3]], 3
// CHECK-NEXT: %[[V7:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } %[[V6]], i256 8, 4
// CHECK-NEXT: ret { i256, i256, i256, i256, i256 } %[[V7]]
// CHECK-NEXT: }
// CHECK-LABEL: define private { i256, i256, i256, i256, i256 } @or(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = xor i256 %[[V0]], -1
// CHECK-NEXT: %[[V3:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } poison, i256 %[[V0]], 0
// CHECK-NEXT: %[[V4:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } %[[V3]], i256 -1, 1
// CHECK-NEXT: %[[V5:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } %[[V4]], i256 %[[V0]], 2
// CHECK-NEXT: %[[V6:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } %[[V5]], i256 -1, 3
// CHECK-NEXT: %[[V7:[0-9]+]] = insertvalue { i256, i256, i256, i256, i256 } %[[V6]], i256 14, 4
// CHECK-NEXT: ret { i256, i256, i256, i256, i256 } %[[V7]]
// CHECK-NEXT: }
// CHECK-LABEL: define private { i256, i256, i256, i256 } @xor(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V3:[0-9]+]] = xor i256 %[[V0]], %[[V1]]
// CHECK-NEXT: %[[V4:[0-9]+]] = insertvalue { i256, i256, i256, i256 } poison, i256 %[[V0]], 0
// CHECK-NEXT: %[[V5:[0-9]+]] = insertvalue { i256, i256, i256, i256 } %[[V4]], i256 0, 1
// CHECK-NEXT: %[[V6:[0-9]+]] = insertvalue { i256, i256, i256, i256 } %[[V5]], i256 %[[V0]], 2
// CHECK-NEXT: %[[V7:[0-9]+]] = insertvalue { i256, i256, i256, i256 } %[[V6]], i256 6, 3
// CHECK-NEXT: ret { i256, i256, i256, i256 } %[[V7]]
// CHECK-NEXT: }
// CHECK-LABEL: define private { i256, i256, i256 } @cmp(
// CHECK-SAME: i256 %[[V0:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V2:[0-9]+]] = icmp ugt i256 %[[V0]], 5
// CHECK-NEXT: %[[V3:[0-9]+]] = zext i1 %[[V2]] to i256
// CHECK-NEXT: %[[V4:[0-9]+]] = insertvalue { i256, i256, i256 } poison, i256 %[[V3]], 0
// CHECK-NEXT: %[[V5:[0-9]+]] = insertvalue { i256, i256, i256 } %[[V4]], i256 1, 1
// CHECK-NEXT: %[[V6:[0-9]+]] = insertvalue { i256, i256, i256 } %[[V5]], i256 0, 2
// CHECK-NEXT: ret { i256, i256, i256 } %[[V6]]
// CHECK-NEXT: }
// CHECK-LABEL: define private { i256, i256, i256 } @select(
// CHECK-SAME: i256 %[[V0:[0-9]+]], i256 %[[V1:[0-9]+]], i256 %[[V2:[0-9]+]]) #{{[0-9]+}} {
// CHECK-NEXT: %[[V4:[0-9]+]] = select i1 true, i256 %[[V1]], i256 %[[V2]]
// CHECK-NEXT: %[[V5:[0-9]+]] = select i1 false, i256 %[[V1]], i256 %[[V2]]
// CHECK-NEXT: %[[V6:[0-9]+]] = icmp ne i256 %[[V0]], 0
// CHECK-NEXT: %[[V7:[0-9]+]] = insertvalue { i256, i256, i256 } poison, i256 %[[V4]], 0
// CHECK-NEXT: %[[V8:[0-9]+]] = insertvalue { i256, i256, i256 } %[[V7]], i256 %[[V5]], 1
// CHECK-NEXT: %[[V9:[0-9]+]] = insertvalue { i256, i256, i256 } %[[V8]], i256 %[[V1]], 2
// CHECK-NEXT: ret { i256, i256, i256 } %[[V9]]
// CHECK-NEXT: }
// The folds of the conversions the translation replaces: convert-func-to-llvm
// folds to existing values, convert-arith-to-llvm folds what that leaves.
module {
  yul.object @Test {
    yul.func @__entry : () -> () {
      yul.stop
      yul.func_return
    }

    // The branch takes the comparison; its widening stays, unused.
    yul.func @cmp_cond : (i256, i256) -> () {
    ^bb0(%a: i256, %b: i256):
      %0 = yul.cmp ult, %a, %b
      yul.if %0 {
        yul.sstore %a, %b
        yul.yield
      } else {
      }
      yul.func_return
    }

    yul.func @not_select : (i256, i256, i256) -> i256 {
    ^bb0(%c: i256, %a: i256, %b: i256):
      %0 = yul.not %a
      %1 = yul.arith_select %c, %0, %b
      yul.func_return %1 : i256
    }

    // (p + 32) - p folds to 32 in the first round; the second sees the
    // constant on the left of the add and moves it right.
    yul.func @sub_of_add : (i256, i256) -> i256 {
    ^bb0(%p: i256, %x: i256):
      %c32 = yul.constant 32
      %0 = yul.add %p, %c32
      %1 = yul.sub %0, %p
      %2 = yul.add %1, %x
      yul.func_return %2 : i256
    }

    // x - x folds to a constant only in the second round, which sees the
    // add of it as the first round left it.
    yul.func @sub_self : (i256, i256) -> i256 {
    ^bb0(%x: i256, %y: i256):
      %0 = yul.sub %x, %x
      %1 = yul.add %y, %0
      yul.func_return %1 : i256
    }

    yul.func @and_not : (i256) -> i256 {
    ^bb0(%x: i256):
      %0 = yul.not %x
      %1 = yul.and %x, %0
      yul.func_return %1 : i256
    }

    // select (a == b), a, b is b.
    yul.func @select_cmp : (i256, i256) -> i256 {
    ^bb0(%a: i256, %b: i256):
      %0 = yul.cmp eq, %a, %b
      %1 = yul.arith_select %0, %a, %b
      yul.func_return %1 : i256
    }

    yul.func @constant_cond : () -> () {
      %c1 = yul.constant 1
      yul.if %c1 {
        yul.invalid
        yul.yield
      } else {
      }
      yul.func_return
    }

    // A constant on the left moves right; (a - b) + b and b + (a - b) are a.
    yul.func @add : (i256, i256) -> (i256, i256, i256, i256) {
    ^bb0(%a: i256, %b: i256):
      %c0 = yul.constant 0
      %c3 = yul.constant 3
      %c4 = yul.constant 4
      %0 = yul.add %c0, %a
      %1 = yul.sub %a, %b
      %2 = yul.add %1, %b
      %3 = yul.add %b, %1
      %4 = yul.add %c3, %c4
      yul.func_return %0, %2, %3, %4 : i256, i256, i256, i256
    }

    yul.func @mul : (i256) -> (i256, i256, i256) {
    ^bb0(%x: i256):
      %c0 = yul.constant 0
      %c1 = yul.constant 1
      %c3 = yul.constant 3
      %c4 = yul.constant 4
      %0 = yul.mul %x, %c0
      %1 = yul.mul %x, %c1
      %2 = yul.mul %c3, %c4
      yul.func_return %0, %1, %2 : i256, i256, i256
    }

    // A zero divisor and the overflowing signed quotient are not folded.
    yul.func @div : (i256) -> (i256, i256, i256, i256, i256, i256) {
    ^bb0(%x: i256):
      %c0 = yul.constant 0
      %c1 = yul.constant 1
      %c2 = yul.constant 2
      %c7 = yul.constant 7
      %cm1 = yul.constant -1
      %min = yul.constant 57896044618658097711785492504343953926634992332820282019728792003956564819968
      %0 = yul.arith_div %x, %c1
      %1 = yul.arith_div %c7, %c2
      %2 = yul.arith_sdiv %x, %c1
      %3 = yul.arith_sdiv %c7, %c2
      %4 = yul.arith_div %x, %c0
      %5 = yul.arith_sdiv %min, %cm1
      yul.func_return %0, %1, %2, %3, %4, %5 : i256, i256, i256, i256, i256, i256
    }

    yul.func @rem : (i256) -> (i256, i256, i256, i256, i256) {
    ^bb0(%x: i256):
      %c0 = yul.constant 0
      %c1 = yul.constant 1
      %c2 = yul.constant 2
      %cm7 = yul.constant -7
      %0 = yul.arith_mod %x, %c1
      %1 = yul.arith_mod %cm7, %c2
      %2 = yul.arith_smod %x, %c1
      %3 = yul.arith_smod %cm7, %c2
      %4 = yul.arith_mod %x, %c0
      yul.func_return %0, %1, %2, %3, %4 : i256, i256, i256, i256, i256
    }

    // A shift by the width or more is not folded.
    yul.func @shift : (i256) -> (i256, i256, i256, i256, i256) {
    ^bb0(%x: i256):
      %c0 = yul.constant 0
      %c1 = yul.constant 1
      %c4 = yul.constant 4
      %c256 = yul.constant 256
      %cm256 = yul.constant -256
      %0 = yul.arith_shl %x, %c0
      %1 = yul.arith_shl %c1, %c4
      %2 = yul.arith_shr %c256, %c4
      %3 = yul.arith_sar %cm256, %c4
      %4 = yul.arith_shl %x, %c256
      yul.func_return %0, %1, %2, %3, %4 : i256, i256, i256, i256, i256
    }

    yul.func @and : (i256, i256) -> (i256, i256, i256, i256, i256) {
    ^bb0(%x: i256, %y: i256):
      %c0 = yul.constant 0
      %c10 = yul.constant 10
      %c12 = yul.constant 12
      %cm1 = yul.constant -1
      %0 = yul.and %x, %c0
      %1 = yul.and %x, %cm1
      %2 = yul.and %x, %x
      %3 = yul.and %x, %y
      %4 = yul.and %3, %x
      %5 = yul.and %c12, %c10
      yul.func_return %0, %1, %2, %4, %5 : i256, i256, i256, i256, i256
    }

    yul.func @or : (i256) -> (i256, i256, i256, i256, i256) {
    ^bb0(%x: i256):
      %c0 = yul.constant 0
      %c10 = yul.constant 10
      %c12 = yul.constant 12
      %cm1 = yul.constant -1
      %0 = yul.or %x, %c0
      %1 = yul.or %x, %cm1
      %2 = yul.or %x, %x
      %3 = yul.not %x
      %4 = yul.or %x, %3
      %5 = yul.or %c12, %c10
      yul.func_return %0, %1, %2, %4, %5 : i256, i256, i256, i256, i256
    }

    yul.func @xor : (i256, i256) -> (i256, i256, i256, i256) {
    ^bb0(%x: i256, %y: i256):
      %c0 = yul.constant 0
      %c10 = yul.constant 10
      %c12 = yul.constant 12
      %0 = yul.xor %x, %c0
      %1 = yul.xor %x, %x
      %2 = yul.xor %x, %y
      %3 = yul.xor %2, %y
      %4 = yul.xor %c12, %c10
      yul.func_return %0, %1, %3, %4 : i256, i256, i256, i256
    }

    // A constant on the left of a comparison swaps the predicate.
    yul.func @cmp : (i256) -> (i256, i256, i256) {
    ^bb0(%x: i256):
      %c1 = yul.constant 1
      %c5 = yul.constant 5
      %0 = yul.cmp ult, %c5, %x
      %1 = yul.cmp eq, %c1, %c1
      %2 = yul.cmp slt, %x, %x
      yul.func_return %0, %1, %2 : i256, i256, i256
    }

    yul.func @select : (i256, i256, i256) -> (i256, i256, i256) {
    ^bb0(%c: i256, %a: i256, %b: i256):
      %c0 = yul.constant 0
      %c1 = yul.constant 1
      %0 = yul.arith_select %c1, %a, %b
      %1 = yul.arith_select %c0, %a, %b
      %2 = yul.arith_select %c, %a, %a
      yul.func_return %0, %1, %2 : i256, i256, i256
    }
  }
}
