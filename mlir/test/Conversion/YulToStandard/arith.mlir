// RUN: mlir-opt %s --convert-yul-to-std | FileCheck %s

// CHECK-LABEL: func.func @add
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = arith.addi %[[A]], %[[B]] : i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @add : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.add %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @sub
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = arith.subi %[[A]], %[[B]] : i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @sub : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.sub %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @mul
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = arith.muli %[[A]], %[[B]] : i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @mul : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.mul %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @div
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[A]], %[[B]]) <{id = {{[0-9]+}} : i32, name = "evm.div"}> : (i256, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @div : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.div %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @sdiv
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[A]], %[[B]]) <{id = {{[0-9]+}} : i32, name = "evm.sdiv"}> : (i256, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @sdiv : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.sdiv %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @mod
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[A]], %[[B]]) <{id = {{[0-9]+}} : i32, name = "evm.mod"}> : (i256, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @mod : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.mod %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @smod
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[A]], %[[B]]) <{id = {{[0-9]+}} : i32, name = "evm.smod"}> : (i256, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @smod : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.smod %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @addmod
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256, %[[C:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[A]], %[[B]], %[[C]]) <{id = {{[0-9]+}} : i32, name = "evm.addmod"}> : (i256, i256, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @addmod : (i256, i256, i256) -> i256 {
^bb0(%a: i256, %b: i256, %c: i256):
  %0 = yul.addmod %a, %b, %c
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @mulmod
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256, %[[C:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[A]], %[[B]], %[[C]]) <{id = {{[0-9]+}} : i32, name = "evm.mulmod"}> : (i256, i256, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @mulmod : (i256, i256, i256) -> i256 {
^bb0(%a: i256, %b: i256, %c: i256):
  %0 = yul.mulmod %a, %b, %c
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @exp
// CHECK-SAME:      (%[[BASE:.*]]: i256, %[[EXP:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[BASE]], %[[EXP]]) <{id = {{[0-9]+}} : i32, name = "evm.exp"}> : (i256, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @exp : (i256, i256) -> i256 {
^bb0(%base: i256, %exp: i256):
  %0 = yul.exp %base, %exp
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @signextend
// CHECK-SAME:      (%[[B:.*]]: i256, %[[X:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = "llvm.intrcall"(%[[B]], %[[X]]) <{id = {{[0-9]+}} : i32, name = "evm.signextend"}> : (i256, i256) -> i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @signextend : (i256, i256) -> i256 {
^bb0(%b: i256, %x: i256):
  %0 = yul.signextend %b, %x
  yul.func_return %0 : i256
}

// The arith_* ops have plain arith semantics, unlike div/shl/... which lower
// to the EVM intrinsics.

// CHECK-LABEL: func.func @arith_div
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = arith.divui %[[A]], %[[B]] : i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @arith_div : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.arith_div %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @arith_sdiv
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = arith.divsi %[[A]], %[[B]] : i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @arith_sdiv : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.arith_sdiv %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @arith_mod
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = arith.remui %[[A]], %[[B]] : i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @arith_mod : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.arith_mod %a, %b
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @arith_select
// CHECK-SAME:      (%{{.*}}: i256, %[[T:.*]]: i256, %[[F:.*]]: i256)
// CHECK:         %[[W:.*]] = arith.extui %{{.*}} : i1 to i256
// CHECK:         %[[C:.*]] = arith.cmpi ne, %[[W]], %{{.*}} : i256
// CHECK:         arith.select %[[C]], %[[T]], %[[F]] : i256
yul.func @arith_select : (i256, i256, i256) -> i256 {
^bb0(%c: i256, %t: i256, %f: i256):
  %c0_i256 = yul.constant 0
  %0 = yul.cmp ne, %c, %c0_i256
  %1 = yul.arith_select %0, %t, %f
  yul.func_return %1 : i256
}

// arith_shl takes the value first, the shift amount second.
// CHECK-LABEL: func.func @arith_shl
// CHECK-SAME:      (%[[N:.*]]: i256)
// CHECK:         %[[ONES:.*]] = arith.constant -1 : i256
// CHECK:         arith.shli %[[ONES]], %[[N]] : i256
yul.func @arith_shl : (i256) -> i256 {
^bb0(%n: i256):
  %c-1_i256 = yul.constant -1
  %0 = yul.arith_shl %c-1_i256, %n
  yul.func_return %0 : i256
}

// CHECK-LABEL: func.func @arith_shr
// CHECK-SAME:      (%[[A:.*]]: i256, %[[B:.*]]: i256) -> i256
// CHECK-NEXT:    %[[V:.*]] = arith.shrui %[[A]], %[[B]] : i256
// CHECK-NEXT:    return %[[V]] : i256
yul.func @arith_shr : (i256, i256) -> i256 {
^bb0(%a: i256, %b: i256):
  %0 = yul.arith_shr %a, %b
  yul.func_return %0 : i256
}
