// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

module {
  sol.contract @C {
    // Unchecked: plain ops; only division and modulo by zero panic (0x12).
    // CHECK-LABEL: yul.func @unchk_ui : (i256, i256) -> ()
    // CHECK:         yul.add
    // CHECK:         yul.sub
    // CHECK:         yul.mul
    // CHECK:         %[[Z:.*]] = yul.cmp eq, %[[D:.*]], %{{.*}}
    // CHECK:         yul.if %[[Z]] {
    // CHECK:           %[[C18:.*]] = yul.constant 18{{$}}
    // CHECK:           yul.mstore %{{.*}}, %[[C18]]
    // CHECK:         yul.arith_div %{{.*}}, %[[D]]
    // CHECK:         yul.arith_mod
    // CHECK:         yul.shl
    // CHECK:         yul.shr
    // CHECK:         yul.and
    // CHECK:         yul.or
    // CHECK:         yul.xor
    // CHECK:         yul.not
    sol.func @unchk_ui(%a: ui256, %b: ui256) {
      %0 = sol.add %a, %b : ui256
      %1 = sol.sub %a, %b : ui256
      %2 = sol.mul %a, %b : ui256
      %3 = sol.div %a, %b : ui256
      %4 = sol.mod %a, %b : ui256
      %5 = sol.shl %a, %b : ui256, ui256
      %6 = sol.shr %a, %b : ui256, ui256
      %7 = sol.and %a, %b : ui256
      %8 = sol.or %a, %b : ui256
      %9 = sol.xor %a, %b : ui256
      %10 = sol.not %a : ui256
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @unchk_si : (i256, i256, i256) -> ()
    // CHECK:         yul.sdiv
    // CHECK:         yul.smod
    // CHECK:         yul.shl
    // CHECK:         yul.sar
    sol.func @unchk_si(%a: si256, %b: si256, %s: ui256) {
      %0 = sol.div %a, %b : si256
      %1 = sol.mod %a, %b : si256
      %2 = sol.shl %a, %s : si256, ui256
      %3 = sol.shr %a, %s : si256, ui256
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // Narrow operands are cleaned (masked / sign-extended) where the result
    // depends on the high bits.
    // CHECK-LABEL: yul.func @unchk_ui8 : (i256, i256) -> ()
    // CHECK:         %[[M:.*]] = yul.constant 255
    // CHECK:         %[[A:.*]] = yul.and %{{.*}}, %[[M]]
    // CHECK:         %[[B:.*]] = yul.and %{{.*}}, %{{.*}}
    // CHECK:         yul.arith_div %[[A]], %[[B]]
    // CHECK:         yul.arith_mod
    // CHECK:         yul.shl
    // CHECK:         yul.shr
    // CHECK:         yul.exp
    sol.func @unchk_ui8(%a: ui8, %b: ui8) {
      %0 = sol.div %a, %b : ui8
      %1 = sol.mod %a, %b : ui8
      %2 = sol.shl %a, %b : ui8, ui8
      %3 = sol.shr %a, %b : ui8, ui8
      %4 = sol.exp %a, %b : ui8, ui8 -> ui8
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @unchk_si8 : (i256, i256, i256) -> ()
    // CHECK:         %[[A:.*]] = yul.signextend %{{.*}}, %{{.*}}
    // CHECK:         %[[B:.*]] = yul.signextend %{{.*}}, %{{.*}}
    // CHECK:         yul.sdiv %[[A]], %[[B]]
    // CHECK:         yul.smod
    // CHECK:         %[[SM:.*]] = yul.constant 255
    // CHECK:         %[[SH:.*]] = yul.and %{{.*}}, %[[SM]]
    // CHECK:         yul.shl %[[SH]], %{{.*}}
    // CHECK:         yul.sar
    sol.func @unchk_si8(%a: si8, %b: si8, %s: ui8) {
      %0 = sol.div %a, %b : si8
      %1 = sol.mod %a, %b : si8
      %2 = sol.shl %a, %s : si8, ui8
      %3 = sol.shr %a, %s : si8, ui8
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // Checked: overflow panics with 0x11.
    // CHECK-LABEL: yul.func @chk_ui : (i256, i256) -> ()
    // CHECK:         %[[S:.*]] = yul.add %[[X:.*]], %{{.*}}
    // CHECK:         %[[OV:.*]] = yul.cmp ugt, %[[X]], %[[S]]
    // CHECK:         yul.if %[[OV]] {
    // CHECK:           %[[C17:.*]] = yul.constant 17{{$}}
    // CHECK:           yul.mstore %{{.*}}, %[[C17]]
    // CHECK:         %[[D:.*]] = yul.sub %[[Y:.*]], %{{.*}}
    // CHECK:         yul.cmp ugt, %[[D]], %[[Y]]
    // CHECK:         %[[P:.*]] = yul.mul %[[MA:.*]], %[[MB:.*]]
    // CHECK:         %[[Q:.*]] = yul.div %[[P]], %[[MA]]
    // CHECK:         yul.cmp ne, %[[Q]], %[[MB]]
    // CHECK:         yul.constant 18{{$}}
    // CHECK:         yul.arith_div
    sol.func @chk_ui(%a: ui256, %b: ui256) {
      %0 = sol.cadd %a, %b : ui256
      %1 = sol.csub %a, %b : ui256
      %2 = sol.cmul %a, %b : ui256
      %3 = sol.cdiv %a, %b : ui256
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @chk_si : (i256, i256) -> ()
    // CHECK:         yul.add
    // CHECK:         yul.cmp sge
    // CHECK:         yul.cmp slt
    // CHECK:         yul.constant 17{{$}}
    // CHECK:         yul.sub
    // CHECK:         yul.cmp sgt
    // CHECK:         yul.mul
    // CHECK:         yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
    // CHECK:         yul.sdiv
    // CHECK:         yul.constant 18{{$}}
    // CHECK:         %[[MIN:.*]] = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968
    // CHECK:         yul.cmp eq, %{{.*}}, %[[MIN]]
    // CHECK:         %[[M1:.*]] = yul.constant -1
    // CHECK:         yul.cmp eq, %{{.*}}, %[[M1]]
    // CHECK:         yul.constant 17{{$}}
    // CHECK:         yul.arith_sdiv
    sol.func @chk_si(%a: si256, %b: si256) {
      %0 = sol.cadd %a, %b : si256
      %1 = sol.csub %a, %b : si256
      %2 = sol.cmul %a, %b : si256
      %3 = sol.cdiv %a, %b : si256
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @chk_ui8 : (i256, i256) -> ()
    // CHECK:         %[[S:.*]] = yul.add
    // CHECK:         %[[M:.*]] = yul.constant 255
    // CHECK:         %[[OV:.*]] = yul.cmp ugt, %[[S]], %[[M]]
    // CHECK:         yul.if %[[OV]] {
    // CHECK:           yul.constant 17{{$}}
    // CHECK:         %[[D:.*]] = yul.sub
    // CHECK:         yul.cmp ugt, %[[D]], %{{.*}}
    // CHECK:         %[[P:.*]] = yul.mul
    // CHECK:         %[[PC:.*]] = yul.and %[[P]], %{{.*}}
    // CHECK:         yul.cmp ne, %[[P]], %[[PC]]
    // CHECK:         yul.arith_div
    sol.func @chk_ui8(%a: ui8, %b: ui8) {
      %0 = sol.cadd %a, %b : ui8
      %1 = sol.csub %a, %b : ui8
      %2 = sol.cmul %a, %b : ui8
      %3 = sol.cdiv %a, %b : ui8
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @chk_si8 : (i256, i256) -> ()
    // CHECK:         %[[S:.*]] = yul.add
    // CHECK:         %[[MAX:.*]] = yul.constant 127
    // CHECK:         yul.cmp sgt, %[[S]], %[[MAX]]
    // CHECK:         %[[MIN:.*]] = yul.constant -128
    // CHECK:         yul.cmp slt, %[[S]], %[[MIN]]
    // CHECK:         yul.sub
    // CHECK:         %[[P:.*]] = yul.mul
    // CHECK:         %[[PS:.*]] = yul.signextend %{{.*}}, %[[P]]
    // CHECK:         yul.cmp ne, %[[P]], %[[PS]]
    // CHECK:         yul.constant -128
    // CHECK:         yul.constant -1
    // CHECK:         yul.arith_sdiv
    sol.func @chk_si8(%a: si8, %b: si8) {
      %0 = sol.cadd %a, %b : si8
      %1 = sol.csub %a, %b : si8
      %2 = sol.cmul %a, %b : si8
      %3 = sol.cdiv %a, %b : si8
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @addmod : (i256, i256, i256) -> i256
    // CHECK:         %[[Z:.*]] = yul.cmp eq, %[[MOD:.*]], %{{.*}}
    // CHECK:         yul.if %[[Z]] {
    // CHECK:           yul.constant 18{{$}}
    // CHECK:         %[[R:.*]] = yul.addmod %{{.*}}, %{{.*}}, %[[MOD]]
    // CHECK:         yul.func_return %[[R]]
    sol.func @addmod(%a: ui256, %b: ui256, %m: ui256) -> ui256 {
      %0 = sol.addmod %a, %b, %m : ui256
      sol.return %0 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @mulmod : (i256, i256, i256) -> i256
    // CHECK:         yul.constant 18{{$}}
    // CHECK:         %[[R:.*]] = yul.mulmod
    // CHECK:         yul.func_return %[[R]]
    sol.func @mulmod(%a: ui256, %b: ui256, %m: ui256) -> ui256 {
      %0 = sol.mulmod %a, %b, %m : ui256
      sol.return %0 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // Checked exponentiation: special-cased bases, then a square-and-multiply
    // loop bounded by type(uint8).max.
    // CHECK-LABEL: yul.func @cexp_ui8 : (i256, i256) -> i256
    // CHECK:         yul.and
    // CHECK:         yul.and
    // CHECK:         %[[MAX:.*]] = yul.constant 255
    // CHECK:         %[[R:.*]] = yul.if %{{.*}} -> i256 {
    // CHECK:           yul.exp
    // CHECK:           yul.while
    // CHECK:             yul.div %[[MAX]], %{{.*}}
    // CHECK:         yul.func_return %[[R]]
    sol.func @cexp_ui8(%a: ui8, %b: ui8) -> ui8 {
      %0 = sol.cexp %a, %b : ui8, ui8 -> ui8
      sol.return %0 : ui8
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @cexp_si8 : (i256, i256) -> i256
    // CHECK:         %[[MAX:.*]] = yul.constant 127
    // CHECK:         %[[MIN:.*]] = yul.constant -128
    // CHECK:         %[[R:.*]] = yul.if %{{.*}} -> i256 {
    // CHECK:           yul.while
    // CHECK:             yul.div %[[MAX]], %{{.*}}
    // CHECK:           yul.sdiv %[[MIN]], %{{.*}}
    // CHECK:         yul.func_return %[[R]]
    sol.func @cexp_si8(%a: si8, %b: ui8) -> si8 {
      %0 = sol.cexp %a, %b : si8, ui8 -> si8
      sol.return %0 : si8
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
