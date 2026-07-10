// RUN: mlir-opt %s -sol-inline-modifiers -split-input-file | FileCheck %s

// Single modifier: the invocation's argument evaluation is cloned into the
// function, the modifier body wraps the function body, and the result flows
// through the shared slot. All modifier ops are erased.

module {
  sol.contract @Basic {
    sol.modifier @m(%a: ui256) {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %a, %0 : ui256, !sol.ptr<ui256, Stack>
      sol.placeholder
      %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      sol.return
    }
    sol.func @f(%x: ui256) -> ui256 {
      sol.modifier_invocation @m {
        %c1 = sol.constant 1 : ui256
        %0 = sol.cadd %x, %c1 : ui256
        sol.yield %0 : ui256
      }
      %c42 = sol.constant 42 : ui256
      sol.return %c42 : ui256
    }
  } {kind = #sol<ContractKind Contract>}
}

// CHECK-LABEL: sol.contract @Basic
// CHECK:       sol.func @f(%[[X:.*]]: ui256) -> ui256
// CHECK:         %[[SLOT:.*]] = sol.alloca : !sol.ptr<ui256, Stack>
// CHECK:         %[[ZERO:.*]] = sol.constant 0 : ui256
// CHECK:         sol.store %[[ZERO]], %[[SLOT]]
// CHECK:         %[[C1:.*]] = sol.constant 1 : ui256
// CHECK:         %[[ARG:.*]] = sol.cadd %[[X]], %[[C1]]
// CHECK:         sol.scope {
// CHECK:           %[[PARAM:.*]] = sol.alloca : !sol.ptr<ui256, Stack>
// CHECK:           sol.store %[[ARG]], %[[PARAM]]
// CHECK:           sol.scope {
// CHECK:             %[[C42:.*]] = sol.constant 42 : ui256
// CHECK:             sol.store %[[C42]], %[[SLOT]]
// CHECK-NEXT:        sol.leave
// CHECK:           }
// CHECK:           sol.load %[[PARAM]]
// CHECK:           sol.leave
// CHECK:         }
// CHECK:         %[[RES:.*]] = sol.load %[[SLOT]]
// CHECK-NEXT:    sol.return %[[RES]]
// CHECK-NOT:   sol.modifier
// CHECK-NOT:   sol.placeholder

// -----

// Two modifiers: layer nesting follows the invocation order, the function
// body innermost.

module {
  sol.contract @TwoModifiers {
    sol.modifier @m1() {
      %c1 = sol.constant 111 : ui256
      sol.placeholder
      sol.return
    }
    sol.modifier @m2() {
      %c2 = sol.constant 222 : ui256
      sol.placeholder
      sol.return
    }
    sol.func @f() {
      sol.modifier_invocation @m1 {
        sol.yield
      }
      sol.modifier_invocation @m2 {
        sol.yield
      }
      %c3 = sol.constant 333 : ui256
      sol.return
    }
  } {kind = #sol<ContractKind Contract>}
}

// CHECK-LABEL: sol.contract @TwoModifiers
// CHECK:       sol.func @f()
// CHECK:         sol.scope {
// CHECK:           sol.constant 111
// CHECK:           sol.scope {
// CHECK:             sol.constant 222
// CHECK:             sol.scope {
// CHECK:               sol.constant 333
// CHECK:               sol.leave
// CHECK:             }
// CHECK:             sol.leave
// CHECK:           }
// CHECK:           sol.leave
// CHECK:         }
// CHECK-NEXT:    sol.return

// -----

// A modifier with two placeholders duplicates everything inner per
// placeholder: the inner modifier's argument evaluation and body, and the
// function body, are each emitted twice.

module {
  sol.contract @Multiplicative {
    sol.modifier @twice() {
      sol.placeholder
      sol.placeholder
      sol.return
    }
    sol.modifier @once(%a: ui256) {
      sol.placeholder
      sol.return
    }
    sol.func @f() {
      sol.modifier_invocation @twice {
        sol.yield
      }
      sol.modifier_invocation @once {
        %c7 = sol.constant 7 : ui256
        sol.yield %c7 : ui256
      }
      %c9 = sol.constant 9 : ui256
      sol.return
    }
  } {kind = #sol<ContractKind Contract>}
}

// CHECK-LABEL: sol.contract @Multiplicative
// CHECK:       sol.func @f()
// CHECK:         sol.scope {
// CHECK:           sol.constant 7
// CHECK:           sol.scope {
// CHECK:             sol.scope {
// CHECK:               sol.constant 9
// CHECK:             }
// CHECK:           }
// CHECK:           sol.constant 7
// CHECK:           sol.scope {
// CHECK:             sol.scope {
// CHECK:               sol.constant 9
// CHECK:             }
// CHECK:           }
// CHECK:           sol.leave
// CHECK:         }

// -----

// A modifier with no placeholder: the function body is never emitted and the
// zero-initialized slot defaults are returned.

module {
  sol.contract @NoPlaceholder {
    sol.modifier @gate() {
      %c5 = sol.constant 5 : ui256
      sol.return
    }
    sol.func @f() -> ui256 {
      sol.modifier_invocation @gate {
        sol.yield
      }
      %c42 = sol.constant 42 : ui256
      sol.return %c42 : ui256
    }
  } {kind = #sol<ContractKind Contract>}
}

// CHECK-LABEL: sol.contract @NoPlaceholder
// CHECK:       sol.func @f() -> ui256
// CHECK:         %[[SLOT:.*]] = sol.alloca : !sol.ptr<ui256, Stack>
// CHECK:         %[[ZERO:.*]] = sol.constant 0 : ui256
// CHECK:         sol.store %[[ZERO]], %[[SLOT]]
// CHECK:         sol.scope {
// CHECK-NEXT:      sol.constant 5
// CHECK-NEXT:      sol.leave
// CHECK-NEXT:    }
// CHECK-NEXT:    %[[RES:.*]] = sol.load %[[SLOT]]
// CHECK-NEXT:    sol.return %[[RES]]

// -----

// A return in the modifier's own layer carries no operands: it exits the
// layer without touching the result slots.

module {
  sol.contract @ModifierReturn {
    sol.modifier @m() {
      %c5 = sol.constant 5 : ui256
      sol.return
    ^bb1:
      sol.placeholder
      sol.return
    }
    sol.func @f() -> ui256 {
      sol.modifier_invocation @m {
        sol.yield
      }
      %c42 = sol.constant 42 : ui256
      sol.return %c42 : ui256
    }
  } {kind = #sol<ContractKind Contract>}
}

// CHECK-LABEL: sol.contract @ModifierReturn
// CHECK:       sol.func @f() -> ui256
// CHECK:         sol.scope {
// CHECK:           sol.constant 5
// CHECK-NEXT:      sol.leave
// CHECK:         }

// -----

// Unreachable post-return blocks are cloned along with the body; each return
// is rewritten to stores to the shared slots followed by a leave.

module {
  sol.contract @PostReturnBlocks {
    sol.modifier @m() {
      sol.placeholder
      sol.return
    }
    sol.func @f() -> ui256 {
      sol.modifier_invocation @m {
        sol.yield
      }
      %c1 = sol.constant 1 : ui256
      sol.return %c1 : ui256
    ^bb1:
      %c2 = sol.constant 2 : ui256
      sol.return %c2 : ui256
    }
  } {kind = #sol<ContractKind Contract>}
}

// CHECK-LABEL: sol.contract @PostReturnBlocks
// CHECK:       sol.func @f() -> ui256
// CHECK:         %[[SLOT:.*]] = sol.alloca : !sol.ptr<ui256, Stack>
// CHECK:         sol.scope {
// CHECK:           sol.scope {
// CHECK:             %[[C1:.*]] = sol.constant 1 : ui256
// CHECK:             sol.store %[[C1]], %[[SLOT]]
// CHECK-NEXT:        sol.leave
// CHECK:           ^bb1:
// CHECK:             %[[C2:.*]] = sol.constant 2 : ui256
// CHECK:             sol.store %[[C2]], %[[SLOT]]
// CHECK-NEXT:        sol.leave
// CHECK:           }
// CHECK:         }

// -----

// Multiple results: one default-initialized slot per result, each return
// operand stored to its slot, and the final return loads all slots.

module {
  sol.contract @MultiResult {
    sol.modifier @m() {
      sol.placeholder
      sol.return
    }
    sol.func @f() -> (ui256, ui8) {
      sol.modifier_invocation @m {
        sol.yield
      }
      %c1 = sol.constant 1 : ui256
      %c2 = sol.constant 2 : ui8
      sol.return %c1, %c2 : ui256, ui8
    }
  } {kind = #sol<ContractKind Contract>}
}

// CHECK-LABEL: sol.contract @MultiResult
// CHECK:       sol.func @f() -> (ui256, ui8)
// CHECK:         %[[SLOT0:.*]] = sol.alloca : !sol.ptr<ui256, Stack>
// CHECK:         %[[ZERO0:.*]] = sol.constant 0 : ui256
// CHECK:         sol.store %[[ZERO0]], %[[SLOT0]]
// CHECK:         %[[SLOT1:.*]] = sol.alloca : !sol.ptr<ui8, Stack>
// CHECK:         %[[ZERO1:.*]] = sol.constant 0 : ui8
// CHECK:         sol.store %[[ZERO1]], %[[SLOT1]]
// CHECK:         sol.scope {
// CHECK:           sol.scope {
// CHECK:             %[[C1:.*]] = sol.constant 1 : ui256
// CHECK:             %[[C2:.*]] = sol.constant 2 : ui8
// CHECK:             sol.store %[[C1]], %[[SLOT0]]
// CHECK:             sol.store %[[C2]], %[[SLOT1]]
// CHECK-NEXT:        sol.leave
// CHECK:           }
// CHECK:         }
// CHECK:         %[[RES0:.*]] = sol.load %[[SLOT0]]
// CHECK:         %[[RES1:.*]] = sol.load %[[SLOT1]]
// CHECK-NEXT:    sol.return %[[RES0]], %[[RES1]]

// -----

// Placeholders and returns nested inside regions: the inner layer is emitted
// at the placeholder's position inside the modifier's sol.if, and a return
// nested in the body's sol.if exits the layer from that nesting depth.

module {
  sol.contract @NestedControlFlow {
    sol.modifier @m(%c: i1) {
      sol.if %c {
        sol.placeholder
        sol.yield
      } else {
      }
      sol.return
    }
    sol.func @f(%c: i1, %d: i1) -> ui256 {
      sol.modifier_invocation @m {
        sol.yield %c : i1
      }
      sol.if %d {
        %c2 = sol.constant 2 : ui256
        sol.return %c2 : ui256
      ^bb1:
        sol.yield
      } else {
      }
      %c3 = sol.constant 3 : ui256
      sol.return %c3 : ui256
    }
  } {kind = #sol<ContractKind Contract>}
}

// CHECK-LABEL: sol.contract @NestedControlFlow
// CHECK:       sol.func @f(%[[C:.*]]: i1, %[[D:.*]]: i1) -> ui256
// CHECK:         %[[SLOT:.*]] = sol.alloca : !sol.ptr<ui256, Stack>
// CHECK:         sol.scope {
// CHECK:           sol.if %[[C]] {
// CHECK:             sol.scope {
// CHECK:               sol.if %[[D]] {
// CHECK:                 %[[C2:.*]] = sol.constant 2 : ui256
// CHECK-NEXT:            sol.store %[[C2]], %[[SLOT]]
// CHECK-NEXT:            sol.leave
// CHECK:               ^bb1:
// CHECK-NEXT:            sol.yield
// CHECK:               }
// CHECK:               %[[C3:.*]] = sol.constant 3 : ui256
// CHECK-NEXT:          sol.store %[[C3]], %[[SLOT]]
// CHECK-NEXT:          sol.leave
// CHECK:             }
// CHECK:             sol.yield
// CHECK:           }
// CHECK:           sol.leave
// CHECK:         }
// CHECK:         %[[RES:.*]] = sol.load %[[SLOT]]
// CHECK-NEXT:    sol.return %[[RES]]

// -----

// Both body copies of a two-placeholder expansion write the single shared
// result slot.

module {
  sol.contract @MultiplicativeSharedSlot {
    sol.modifier @twice() {
      sol.placeholder
      sol.placeholder
      sol.return
    }
    sol.func @f() -> ui256 {
      sol.modifier_invocation @twice {
        sol.yield
      }
      %c9 = sol.constant 9 : ui256
      sol.return %c9 : ui256
    }
  } {kind = #sol<ContractKind Contract>}
}

// CHECK-LABEL: sol.contract @MultiplicativeSharedSlot
// CHECK:       sol.func @f() -> ui256
// CHECK:         %[[SLOT:.*]] = sol.alloca : !sol.ptr<ui256, Stack>
// CHECK:         sol.scope {
// CHECK:           sol.scope {
// CHECK:             %[[A:.*]] = sol.constant 9 : ui256
// CHECK-NEXT:        sol.store %[[A]], %[[SLOT]]
// CHECK-NEXT:        sol.leave
// CHECK:           }
// CHECK:           sol.scope {
// CHECK:             %[[B:.*]] = sol.constant 9 : ui256
// CHECK-NEXT:        sol.store %[[B]], %[[SLOT]]
// CHECK-NEXT:        sol.leave
// CHECK:           }
// CHECK:           sol.leave
// CHECK:         }
// CHECK:         %[[RES:.*]] = sol.load %[[SLOT]]
// CHECK-NEXT:    sol.return %[[RES]]

// -----

// The invocation region is not isolated: argument evaluation references (and
// here mutates) an alloca of the enclosing function, and its clone lands in
// the function entry ahead of the layers - the `m(r = 2)` shape.

module {
  sol.contract @ArgWritesFuncSlot {
    sol.modifier @m(%a: ui256) {
      sol.placeholder
      sol.return
    }
    sol.func @f() -> ui256 {
      %r = sol.alloca : !sol.ptr<ui256, Stack>
      %c0 = sol.constant 0 : ui256
      sol.store %c0, %r : ui256, !sol.ptr<ui256, Stack>
      sol.modifier_invocation @m {
        %c2 = sol.constant 2 : ui256
        sol.store %c2, %r : ui256, !sol.ptr<ui256, Stack>
        sol.yield %c2 : ui256
      }
      %v = sol.load %r : !sol.ptr<ui256, Stack>, ui256
      sol.return %v : ui256
    }
  } {kind = #sol<ContractKind Contract>}
}

// CHECK-LABEL: sol.contract @ArgWritesFuncSlot
// CHECK:       sol.func @f() -> ui256
// CHECK:         %[[R:.*]] = sol.alloca : !sol.ptr<ui256, Stack>
// CHECK:         %[[Z:.*]] = sol.constant 0 : ui256
// CHECK-NEXT:    sol.store %[[Z]], %[[R]]
// CHECK:         %[[SLOT:.*]] = sol.alloca : !sol.ptr<ui256, Stack>
// CHECK:         %[[C2:.*]] = sol.constant 2 : ui256
// CHECK-NEXT:    sol.store %[[C2]], %[[R]]
// CHECK-NEXT:    sol.scope {
// CHECK:           sol.scope {
// CHECK:             %[[V:.*]] = sol.load %[[R]]
// CHECK-NEXT:        sol.store %[[V]], %[[SLOT]]
// CHECK-NEXT:        sol.leave
// CHECK:           }
// CHECK:           sol.leave
// CHECK:         }
// CHECK:         %[[RES:.*]] = sol.load %[[SLOT]]
// CHECK-NEXT:    sol.return %[[RES]]
