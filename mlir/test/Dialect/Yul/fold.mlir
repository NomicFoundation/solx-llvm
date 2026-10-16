// RUN: mlir-opt %s -canonicalize | FileCheck %s

// CHECK-LABEL: yul.func @add
// CHECK:       ^bb0(%[[X:.*]]: i256):
// CHECK-NEXT:    %[[C7:.*]] = yul.constant 7
// CHECK-NEXT:    yul.func_return %[[X]], %[[X]], %[[C7]]
yul.func @add : (i256) -> (i256, i256, i256) {
^bb0(%x: i256):
  %c0 = yul.constant 0
  %c3 = yul.constant 3
  %c4 = yul.constant 4
  %0 = yul.add %x, %c0
  %1 = yul.add %c0, %x
  %2 = yul.add %c3, %c4
  yul.func_return %0, %1, %2 : i256, i256, i256
}

// CHECK-LABEL: yul.func @sub
// CHECK:       ^bb0(%[[X:.*]]: i256):
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[CM2:.*]] = yul.constant -2
// CHECK:         yul.func_return %[[X]], %[[C0]], %[[CM2]]
yul.func @sub : (i256) -> (i256, i256, i256) {
^bb0(%x: i256):
  %c0 = yul.constant 0
  %c3 = yul.constant 3
  %c5 = yul.constant 5
  %0 = yul.sub %x, %c0
  %1 = yul.sub %x, %x
  %2 = yul.sub %c3, %c5
  yul.func_return %0, %1, %2 : i256, i256, i256
}

// CHECK-LABEL: yul.func @mul
// CHECK:       ^bb0(%[[X:.*]]: i256):
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C42:.*]] = yul.constant 42
// CHECK:         yul.func_return %[[X]], %[[C0]], %[[C42]]
yul.func @mul : (i256) -> (i256, i256, i256) {
^bb0(%x: i256):
  %c0 = yul.constant 0
  %c1 = yul.constant 1
  %c6 = yul.constant 6
  %c7 = yul.constant 7
  %0 = yul.mul %x, %c1
  %1 = yul.mul %c0, %x
  %2 = yul.mul %c6, %c7
  yul.func_return %0, %1, %2 : i256, i256, i256
}

// CHECK-LABEL: yul.func @and
// CHECK:       ^bb0(%[[X:.*]]: i256):
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C8:.*]] = yul.constant 8
// CHECK:         yul.func_return %[[C0]], %[[X]], %[[X]], %[[C8]]
yul.func @and : (i256) -> (i256, i256, i256, i256) {
^bb0(%x: i256):
  %c0 = yul.constant 0
  %cm1 = yul.constant -1
  %c12 = yul.constant 12
  %c10 = yul.constant 10
  %0 = yul.and %x, %c0
  %1 = yul.and %cm1, %x
  %2 = yul.and %x, %x
  %3 = yul.and %c12, %c10
  yul.func_return %0, %1, %2, %3 : i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @or
// CHECK:       ^bb0(%[[X:.*]]: i256):
// CHECK-DAG:     %[[CM1:.*]] = yul.constant -1
// CHECK-DAG:     %[[C14:.*]] = yul.constant 14
// CHECK:         yul.func_return %[[X]], %[[CM1]], %[[X]], %[[C14]]
yul.func @or : (i256) -> (i256, i256, i256, i256) {
^bb0(%x: i256):
  %c0 = yul.constant 0
  %cm1 = yul.constant -1
  %c12 = yul.constant 12
  %c10 = yul.constant 10
  %0 = yul.or %x, %c0
  %1 = yul.or %x, %cm1
  %2 = yul.or %x, %x
  %3 = yul.or %c12, %c10
  yul.func_return %0, %1, %2, %3 : i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @xor
// CHECK:       ^bb0(%[[X:.*]]: i256):
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C6:.*]] = yul.constant 6
// CHECK:         yul.func_return %[[X]], %[[C0]], %[[C6]]
yul.func @xor : (i256) -> (i256, i256, i256) {
^bb0(%x: i256):
  %c0 = yul.constant 0
  %c12 = yul.constant 12
  %c10 = yul.constant 10
  %0 = yul.xor %x, %c0
  %1 = yul.xor %x, %x
  %2 = yul.xor %c12, %c10
  yul.func_return %0, %1, %2 : i256, i256, i256
}

// CHECK-LABEL: yul.func @not
// CHECK:       ^bb0(%[[X:.*]]: i256):
// CHECK-NEXT:    %[[CM1:.*]] = yul.constant -1
// CHECK-NEXT:    yul.func_return %[[X]], %[[CM1]]
yul.func @not : (i256) -> (i256, i256) {
^bb0(%x: i256):
  %c0 = yul.constant 0
  %0 = yul.not %x
  %1 = yul.not %0
  %2 = yul.not %c0
  yul.func_return %1, %2 : i256, i256
}

// CHECK-LABEL: yul.func @cmp
// CHECK:       ^bb0(%[[X:.*]]: i256, %[[Y:.*]]: i256):
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C1:.*]] = yul.constant 1
// CHECK-DAG:     %[[C5:.*]] = yul.constant 5
// CHECK-DAG:     %[[LT:.*]] = yul.cmp ult, %[[X]], %[[Y]]
// CHECK-DAG:     %[[GT5:.*]] = yul.cmp ugt, %[[X]], %[[C5]]
// CHECK:         yul.func_return %[[C0]], %[[C1]], %[[C1]], %[[C0]], %[[LT]], %[[GT5]]
yul.func @cmp : (i256, i256) -> (i256, i256, i256, i256, i256, i256) {
^bb0(%x: i256, %y: i256):
  %c0 = yul.constant 0
  %c3 = yul.constant 3
  %c5 = yul.constant 5
  %cm1 = yul.constant -1
  %0 = yul.cmp ult, %x, %x
  %1 = yul.cmp ule, %x, %x
  %2 = yul.cmp ult, %c3, %c5
  %3 = yul.cmp sgt, %cm1, %c0
  %4 = yul.cmp ult, %x, %y
  %5 = yul.cmp ne, %4, %c0
  %6 = yul.cmp ult, %c5, %x
  yul.func_return %0, %1, %2, %3, %5, %6 : i256, i256, i256, i256, i256, i256
}

// A comparison tested against zero is negated into its inverse predicate.

// CHECK-LABEL: yul.func @negated_cmp
// CHECK:       ^bb0(%[[X:.*]]: i256, %[[Y:.*]]: i256):
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[GE:.*]] = yul.cmp uge, %[[X]], %[[Y]]
// CHECK-DAG:     %[[NE:.*]] = yul.cmp ne, %[[X]], %[[C0]]
// CHECK:         yul.func_return %[[GE]], %[[NE]]
yul.func @negated_cmp : (i256, i256) -> (i256, i256) {
^bb0(%x: i256, %y: i256):
  %c0 = yul.constant 0
  %0 = yul.cmp ult, %x, %y
  %1 = yul.cmp eq, %0, %c0
  %2 = yul.cmp eq, %x, %c0
  %3 = yul.cmp eq, %2, %c0
  yul.func_return %1, %3 : i256, i256
}

// CHECK-LABEL: yul.func @arith_select
// CHECK:       ^bb0(%[[C:.*]]: i256, %[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK-NEXT:    yul.func_return %[[A]], %[[B]], %[[A]]
yul.func @arith_select : (i256, i256, i256) -> (i256, i256, i256) {
^bb0(%c: i256, %a: i256, %b: i256):
  %c0 = yul.constant 0
  %c5 = yul.constant 5
  %0 = yul.arith_select %c5, %a, %b
  %1 = yul.arith_select %c0, %a, %b
  %2 = yul.arith_select %c, %a, %a
  yul.func_return %0, %1, %2 : i256, i256, i256
}

// The arith wrappers fold what the arith ops they lower to fold: a shift of
// the word width or more and a division by zero stay.

// CHECK-LABEL: yul.func @arith_shifts
// CHECK:       ^bb0(%[[X:.*]]: i256):
// CHECK-DAG:     %[[C1:.*]] = yul.constant 1
// CHECK-DAG:     %[[C256:.*]] = yul.constant 256
// CHECK-DAG:     %[[MIN:.*]] = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
// CHECK-DAG:     %[[CM1:.*]] = yul.constant -1
// CHECK-DAG:     %[[SHL:.*]] = yul.arith_shl %[[C1]], %[[C256]]
// CHECK-DAG:     %[[SHR:.*]] = yul.arith_shr %[[X]], %[[C256]]
// CHECK-DAG:     %[[SAR:.*]] = yul.arith_sar %[[X]], %[[C256]]
// CHECK:         yul.func_return %[[X]], %[[MIN]], %[[SHL]], %[[X]], %[[C1]], %[[SHR]], %[[X]], %[[CM1]], %[[SAR]]
yul.func @arith_shifts : (i256) -> (i256, i256, i256, i256, i256, i256, i256, i256, i256) {
^bb0(%x: i256):
  %c0 = yul.constant 0
  %c1 = yul.constant 1
  %c8 = yul.constant 8
  %c255 = yul.constant 255
  %c256 = yul.constant 256
  %cm256 = yul.constant -256
  %0 = yul.arith_shl %x, %c0
  %1 = yul.arith_shl %c1, %c255
  %2 = yul.arith_shl %c1, %c256
  %3 = yul.arith_shr %x, %c0
  %4 = yul.arith_shr %c256, %c8
  %5 = yul.arith_shr %x, %c256
  %6 = yul.arith_sar %x, %c0
  %7 = yul.arith_sar %cm256, %c8
  %8 = yul.arith_sar %x, %c256
  yul.func_return %0, %1, %2, %3, %4, %5, %6, %7, %8 : i256, i256, i256, i256, i256, i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @arith_div
// CHECK:       ^bb0(%[[X:.*]]: i256):
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C3:.*]] = yul.constant 3
// CHECK-DAG:     %[[C7:.*]] = yul.constant 7
// CHECK-DAG:     %[[CM1:.*]] = yul.constant -1
// CHECK-DAG:     %[[CM3:.*]] = yul.constant -3
// CHECK-DAG:     %[[MIN:.*]] = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
// CHECK-DAG:     %[[DIV0:.*]] = yul.arith_div %[[C7]], %[[C0]]
// CHECK-DAG:     %[[SDIV0:.*]] = yul.arith_sdiv %[[C7]], %[[C0]]
// CHECK-DAG:     %[[SDIVOVF:.*]] = yul.arith_sdiv %[[MIN]], %[[CM1]]
// CHECK:         yul.func_return %[[X]], %[[C3]], %[[DIV0]], %[[X]], %[[CM3]], %[[SDIV0]], %[[SDIVOVF]]
yul.func @arith_div : (i256) -> (i256, i256, i256, i256, i256, i256, i256) {
^bb0(%x: i256):
  %c0 = yul.constant 0
  %c1 = yul.constant 1
  %c2 = yul.constant 2
  %c7 = yul.constant 7
  %cm1 = yul.constant -1
  %cm7 = yul.constant -7
  %min = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
  %0 = yul.arith_div %x, %c1
  %1 = yul.arith_div %c7, %c2
  %2 = yul.arith_div %c7, %c0
  %3 = yul.arith_sdiv %x, %c1
  %4 = yul.arith_sdiv %cm7, %c2
  %5 = yul.arith_sdiv %c7, %c0
  %6 = yul.arith_sdiv %min, %cm1
  yul.func_return %0, %1, %2, %3, %4, %5, %6 : i256, i256, i256, i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @arith_mod
// CHECK:       ^bb0(%[[X:.*]]: i256):
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C1:.*]] = yul.constant 1
// CHECK-DAG:     %[[C7:.*]] = yul.constant 7
// CHECK-DAG:     %[[CM1:.*]] = yul.constant -1
// CHECK-DAG:     %[[MOD0:.*]] = yul.arith_mod %[[C7]], %[[C0]]
// CHECK-DAG:     %[[SMOD0:.*]] = yul.arith_smod %[[C7]], %[[C0]]
// CHECK:         yul.func_return %[[C0]], %[[C1]], %[[MOD0]], %[[C0]], %[[CM1]], %[[SMOD0]]
yul.func @arith_mod : (i256) -> (i256, i256, i256, i256, i256, i256) {
^bb0(%x: i256):
  %c0 = yul.constant 0
  %c1 = yul.constant 1
  %c2 = yul.constant 2
  %c7 = yul.constant 7
  %cm7 = yul.constant -7
  %0 = yul.arith_mod %x, %c1
  %1 = yul.arith_mod %c7, %c2
  %2 = yul.arith_mod %c7, %c0
  %3 = yul.arith_smod %x, %c1
  %4 = yul.arith_smod %cm7, %c2
  %5 = yul.arith_smod %c7, %c0
  yul.func_return %0, %1, %2, %3, %4, %5 : i256, i256, i256, i256, i256, i256
}

// The builtins fold with the EVM's total semantics.

// CHECK-LABEL: yul.func @div_mod
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C1:.*]] = yul.constant 1
// CHECK-DAG:     %[[C3:.*]] = yul.constant 3
// CHECK-DAG:     %[[CM1:.*]] = yul.constant -1
// CHECK-DAG:     %[[CM3:.*]] = yul.constant -3
// CHECK-DAG:     %[[MIN:.*]] = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
// CHECK:         yul.func_return %[[C3]], %[[C0]], %[[CM3]], %[[C0]], %[[MIN]], %[[C1]], %[[C0]], %[[CM1]], %[[C0]]
yul.func @div_mod : () -> (i256, i256, i256, i256, i256, i256, i256, i256, i256) {
  %c0 = yul.constant 0
  %c2 = yul.constant 2
  %c7 = yul.constant 7
  %cm1 = yul.constant -1
  %cm7 = yul.constant -7
  %min = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
  %0 = yul.div %c7, %c2
  %1 = yul.div %c7, %c0
  %2 = yul.sdiv %cm7, %c2
  %3 = yul.sdiv %c7, %c0
  %4 = yul.sdiv %min, %cm1
  %5 = yul.mod %c7, %c2
  %6 = yul.mod %c7, %c0
  %7 = yul.smod %cm7, %c2
  %8 = yul.smod %c7, %c0
  yul.func_return %0, %1, %2, %3, %4, %5, %6, %7, %8 : i256, i256, i256, i256, i256, i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @shifts
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C1:.*]] = yul.constant 1
// CHECK-DAG:     %[[CM1:.*]] = yul.constant -1
// CHECK-DAG:     %[[MIN:.*]] = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
// CHECK:         yul.func_return %[[MIN]], %[[C0]], %[[C1]], %[[C0]], %[[CM1]], %[[CM1]], %[[C0]]
yul.func @shifts : () -> (i256, i256, i256, i256, i256, i256, i256) {
  %c1 = yul.constant 1
  %c8 = yul.constant 8
  %c255 = yul.constant 255
  %c256 = yul.constant 256
  %cm1 = yul.constant -1
  %cm256 = yul.constant -256
  %0 = yul.shl %c255, %c1
  %1 = yul.shl %c256, %c1
  %2 = yul.shr %c8, %c256
  %3 = yul.shr %c256, %c1
  %4 = yul.sar %c8, %cm256
  %5 = yul.sar %c256, %cm1
  %6 = yul.sar %c256, %c1
  yul.func_return %0, %1, %2, %3, %4, %5, %6 : i256, i256, i256, i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @clz_exp
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C1:.*]] = yul.constant 1{{$}}
// CHECK-DAG:     %[[C255:.*]] = yul.constant 255
// CHECK-DAG:     %[[C256:.*]] = yul.constant 256
// CHECK-DAG:     %[[C1024:.*]] = yul.constant 1024
// CHECK:         yul.func_return %[[C256]], %[[C255]], %[[C1024]], %[[C0]], %[[C1]], %[[C1]]
yul.func @clz_exp : () -> (i256, i256, i256, i256, i256, i256) {
  %c0 = yul.constant 0
  %c1 = yul.constant 1
  %c2 = yul.constant 2
  %c3 = yul.constant 3
  %c10 = yul.constant 10
  %c256 = yul.constant 256
  %0 = yul.clz %c0
  %1 = yul.clz %c1
  %2 = yul.exp %c2, %c10
  %3 = yul.exp %c2, %c256
  %4 = yul.exp %c3, %c0
  %5 = yul.exp %c0, %c0
  yul.func_return %0, %1, %2, %3, %4, %5 : i256, i256, i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @signextend_byte
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C52:.*]] = yul.constant 52
// CHECK-DAG:     %[[C127:.*]] = yul.constant 127
// CHECK-DAG:     %[[C128:.*]] = yul.constant 128
// CHECK-DAG:     %[[C171:.*]] = yul.constant 171
// CHECK-DAG:     %[[C255:.*]] = yul.constant 255
// CHECK-DAG:     %[[CM1:.*]] = yul.constant -1
// CHECK:         yul.func_return %[[CM1]], %[[C127]], %[[C255]], %[[C128]], %[[C171]], %[[C52]], %[[C0]]
yul.func @signextend_byte : () -> (i256, i256, i256, i256, i256, i256, i256) {
  %c0 = yul.constant 0
  %c31 = yul.constant 31
  %c32 = yul.constant 32
  %c127 = yul.constant 127
  %c128 = yul.constant 128
  %c255 = yul.constant 255
  %c4660 = yul.constant 4660
  %top = yul.constant 0xab00000000000000000000000000000000000000000000000000000000000000
  %0 = yul.signextend %c0, %c255
  %1 = yul.signextend %c0, %c127
  %2 = yul.signextend %c31, %c255
  %3 = yul.signextend %c32, %c128
  %4 = yul.byte %c0, %top
  %5 = yul.byte %c31, %c4660
  %6 = yul.byte %c32, %c255
  yul.func_return %0, %1, %2, %3, %4, %5, %6 : i256, i256, i256, i256, i256, i256, i256
}

// addmod and mulmod do not wrap at the word.

// CHECK-LABEL: yul.func @addmod_mulmod
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C5:.*]] = yul.constant 5
// CHECK-DAG:     %[[C7:.*]] = yul.constant 7
// CHECK:         yul.func_return %[[C7]], %[[C0]], %[[C5]], %[[C0]]
yul.func @addmod_mulmod : () -> (i256, i256, i256, i256) {
  %c0 = yul.constant 0
  %c1 = yul.constant 1
  %c2 = yul.constant 2
  %c3 = yul.constant 3
  %c10 = yul.constant 10
  %max = yul.constant -1
  %0 = yul.addmod %max, %c2, %c10
  %1 = yul.addmod %c1, %c2, %c0
  %2 = yul.mulmod %max, %c3, %c10
  %3 = yul.mulmod %c1, %c2, %c0
  yul.func_return %0, %1, %2, %3 : i256, i256, i256, i256
}

// The corner cases of the EVM opcodes. The same cases run on REVM in
// solx's fold_corner_cases.sol, folded and unfolded.

// CHECK-LABEL: yul.func @wrap
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C1:.*]] = yul.constant 1
// CHECK-DAG:     %[[CM1:.*]] = yul.constant -1
// CHECK-DAG:     %[[CM2:.*]] = yul.constant -2
// CHECK:         yul.func_return %[[C0]], %[[CM2]], %[[CM1]], %[[C0]], %[[C1]]
yul.func @wrap : () -> (i256, i256, i256, i256, i256) {
  %c0 = yul.constant 0
  %c1 = yul.constant 1
  %c2 = yul.constant 2
  %max = yul.constant -1
  %min = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
  %0 = yul.add %max, %c1
  %1 = yul.add %max, %max
  %2 = yul.sub %c0, %c1
  %3 = yul.mul %min, %c2
  %4 = yul.mul %max, %max
  yul.func_return %0, %1, %2, %3, %4 : i256, i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @signed_div_mod
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C1:.*]] = yul.constant 1
// CHECK-DAG:     %[[C3:.*]] = yul.constant 3
// CHECK-DAG:     %[[CM1:.*]] = yul.constant -1
// CHECK-DAG:     %[[CM3:.*]] = yul.constant -3
// CHECK-DAG:     %[[HALFMIN:.*]] = yul.constant -28948022309329048855892746252171976963317496166410141009864396001978282409984
// CHECK:         yul.func_return %[[CM3]], %[[C3]], %[[HALFMIN]], %[[C1]], %[[CM1]], %[[C0]]
yul.func @signed_div_mod : () -> (i256, i256, i256, i256, i256, i256) {
  %c2 = yul.constant 2
  %c7 = yul.constant 7
  %cm1 = yul.constant -1
  %cm2 = yul.constant -2
  %cm7 = yul.constant -7
  %min = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
  %0 = yul.sdiv %c7, %cm2
  %1 = yul.sdiv %cm7, %cm2
  %2 = yul.sdiv %min, %c2
  %3 = yul.smod %c7, %cm2
  %4 = yul.smod %cm7, %cm2
  %5 = yul.smod %min, %cm1
  yul.func_return %0, %1, %2, %3, %4, %5 : i256, i256, i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @exp_corners
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C1:.*]] = yul.constant 1
// CHECK-DAG:     %[[MIN:.*]] = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
// CHECK-DAG:     %[[POW:.*]] = yul.constant -38597363079105398474523661669562635951089994888546854679819194669304376546645
// CHECK:         yul.func_return %[[C0]], %[[C1]], %[[MIN]], %[[POW]]
yul.func @exp_corners : () -> (i256, i256, i256, i256) {
  %c0 = yul.constant 0
  %c2 = yul.constant 2
  %c3 = yul.constant 3
  %c5 = yul.constant 5
  %c255 = yul.constant 255
  %max = yul.constant -1
  %0 = yul.exp %c0, %c5
  %1 = yul.exp %max, %c2
  %2 = yul.exp %c2, %c255
  %3 = yul.exp %c3, %max
  yul.func_return %0, %1, %2, %3 : i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @signextend_corners
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C5:.*]] = yul.constant 5
// CHECK-DAG:     %[[C32767:.*]] = yul.constant 32767
// CHECK-DAG:     %[[CM1:.*]] = yul.constant -1{{$}}
// CHECK-DAG:     %[[CM128:.*]] = yul.constant -128
// CHECK-DAG:     %[[CM32768:.*]] = yul.constant -32768
// CHECK-DAG:     %[[MIN:.*]] = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
// CHECK:         yul.func_return %[[CM128]], %[[CM32768]], %[[C32767]], %[[CM1]], %[[C0]], %[[MIN]], %[[C5]]
yul.func @signextend_corners : () -> (i256, i256, i256, i256, i256, i256, i256) {
  %c0 = yul.constant 0
  %c1 = yul.constant 1
  %c5 = yul.constant 5
  %c30 = yul.constant 30
  %c31 = yul.constant 31
  %c128 = yul.constant 128
  %c511 = yul.constant 511
  %c32767 = yul.constant 32767
  %c32768 = yul.constant 32768
  %big = yul.constant 1606938044258990275541962092341162602522202993782792835301376
  %min = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
  %0 = yul.signextend %c0, %c128
  %1 = yul.signextend %c1, %c32768
  %2 = yul.signextend %c1, %c32767
  %3 = yul.signextend %c0, %c511
  %4 = yul.signextend %c30, %min
  %5 = yul.signextend %c31, %min
  %6 = yul.signextend %big, %c5
  yul.func_return %0, %1, %2, %3, %4, %5, %6 : i256, i256, i256, i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @byte_corners
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C255:.*]] = yul.constant 255
// CHECK:         yul.func_return %[[C255]], %[[C255]], %[[C0]]
yul.func @byte_corners : () -> (i256, i256, i256) {
  %c0 = yul.constant 0
  %c31 = yul.constant 31
  %big = yul.constant 1606938044258990275541962092341162602522202993782792835301376
  %max = yul.constant -1
  %0 = yul.byte %c0, %max
  %1 = yul.byte %c31, %max
  %2 = yul.byte %big, %max
  yul.func_return %0, %1, %2 : i256, i256, i256
}

// CHECK-LABEL: yul.func @shift_corners
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C1:.*]] = yul.constant 1
// CHECK-DAG:     %[[CM1:.*]] = yul.constant -1
// CHECK-DAG:     %[[MAXPOS:.*]] = yul.constant 57896044618658097711785492504343953926634992332820282019728792003956564819967
// CHECK-DAG:     %[[HALFMIN:.*]] = yul.constant -28948022309329048855892746252171976963317496166410141009864396001978282409984
// CHECK:         yul.func_return %[[C0]], %[[C1]], %[[MAXPOS]], %[[CM1]], %[[HALFMIN]], %[[CM1]], %[[C0]]
yul.func @shift_corners : () -> (i256, i256, i256, i256, i256, i256, i256) {
  %c1 = yul.constant 1
  %c5 = yul.constant 5
  %c255 = yul.constant 255
  %big = yul.constant 1606938044258990275541962092341162602522202993782792835301376
  %max = yul.constant -1
  %cm5 = yul.constant -5
  %min = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
  %0 = yul.shl %big, %c1
  %1 = yul.shr %c255, %min
  %2 = yul.shr %c1, %max
  %3 = yul.sar %c255, %min
  %4 = yul.sar %c1, %min
  %5 = yul.sar %big, %cm5
  %6 = yul.sar %big, %c5
  yul.func_return %0, %1, %2, %3, %4, %5, %6 : i256, i256, i256, i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @addmod_mulmod_corners
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C1:.*]] = yul.constant 1
// CHECK-DAG:     %[[C2:.*]] = yul.constant 2
// CHECK-DAG:     %[[C9:.*]] = yul.constant 9
// CHECK:         yul.func_return %[[C0]], %[[C2]], %[[C0]], %[[C0]], %[[C1]], %[[C9]]
yul.func @addmod_mulmod_corners : () -> (i256, i256, i256, i256, i256, i256) {
  %c1 = yul.constant 1
  %c2 = yul.constant 2
  %c5 = yul.constant 5
  %c6 = yul.constant 6
  %c7 = yul.constant 7
  %c11 = yul.constant 11
  %max = yul.constant -1
  %min = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
  %0 = yul.addmod %max, %max, %max
  %1 = yul.addmod %max, %max, %c7
  %2 = yul.addmod %c5, %c6, %c1
  %3 = yul.mulmod %max, %max, %max
  %4 = yul.mulmod %min, %c2, %max
  %5 = yul.mulmod %max, %max, %c11
  yul.func_return %0, %1, %2, %3, %4, %5 : i256, i256, i256, i256, i256, i256
}

// CHECK-LABEL: yul.func @clz_corners
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C127:.*]] = yul.constant 127
// CHECK:         yul.func_return %[[C0]], %[[C0]], %[[C127]]
yul.func @clz_corners : () -> (i256, i256, i256) {
  %max = yul.constant -1
  %min = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
  %bit128 = yul.constant 340282366920938463463374607431768211456
  %0 = yul.clz %max
  %1 = yul.clz %min
  %2 = yul.clz %bit128
  yul.func_return %0, %1, %2 : i256, i256, i256
}

// CHECK-LABEL: yul.func @cmp_signed
// CHECK-DAG:     %[[C0:.*]] = yul.constant 0
// CHECK-DAG:     %[[C1:.*]] = yul.constant 1
// CHECK:         yul.func_return %[[C1]], %[[C0]], %[[C0]], %[[C1]], %[[C0]]
yul.func @cmp_signed : () -> (i256, i256, i256, i256, i256) {
  %c0 = yul.constant 0
  %max = yul.constant -1
  %min = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
  %0 = yul.cmp slt, %max, %c0
  %1 = yul.cmp sgt, %max, %c0
  %2 = yul.cmp ult, %max, %c0
  %3 = yul.cmp sle, %min, %max
  %4 = yul.cmp uge, %min, %max
  yul.func_return %0, %1, %2, %3, %4 : i256, i256, i256, i256, i256
}
