// RUN: mlir-opt %s -sol-inline-modifiers -mlir-print-debuginfo \
// RUN:   -mlir-print-local-scope | FileCheck %s

// The code the pass generates - the result slot, its default value
// and store, the scope wrapping the original body, the closing loads and the
// return - is at line 0. Everything cloned from the source keeps its own
// location. A layer's scope uses its invocation's location, and a `return`
// gives its location to both the store of its operands and the sol.leave that
// exits the layer.

module {
  sol.contract @Modified {
    sol.modifier @m(%a: ui256) {
      %0 = sol.alloca : !sol.ptr<ui256, Stack> loc(#loc_guard)
      sol.store %a, %0 : ui256, !sol.ptr<ui256, Stack> loc(#loc_guard)
      sol.placeholder loc(#loc_placeholder)
      sol.return loc(#loc_modifier_return)
    } loc(#loc_modifier)
    sol.func @f(%x: ui256) -> ui256 {
      sol.modifier_invocation @m {
        sol.yield %x : ui256 loc(#loc_invocation)
      } loc(#loc_invocation)
      %c42 = sol.constant 42 : ui256 loc(#loc_return)
      sol.return %c42 : ui256 loc(#loc_return)
    } loc(#loc_function)
  } {kind = #sol<ContractKind Contract>} loc(#loc_contract)
} loc(#loc_contract)

#loc_contract = loc("Modified.sol":2:1)
#loc_modifier = loc("Modified.sol":3:5)
#loc_guard = loc("Modified.sol":4:7)
#loc_placeholder = loc("Modified.sol":5:7)
#loc_modifier_return = loc("Modified.sol":6:7)
#loc_function = loc("Modified.sol":8:5)
#loc_invocation = loc("Modified.sol":8:30)
#loc_return = loc("Modified.sol":9:9)

// CHECK-LABEL: sol.func @f
// CHECK:         sol.alloca {{.*}} loc("Modified.sol":0:0)
// CHECK:         sol.constant 0 {{.*}} loc("Modified.sol":0:0)
// CHECK:         sol.store {{.*}} loc("Modified.sol":0:0)
// CHECK:         sol.scope {
// CHECK:           sol.alloca {{.*}} loc("Modified.sol":4:7)
// CHECK:           sol.store {{.*}} loc("Modified.sol":4:7)
// CHECK:           sol.scope {
// CHECK:             sol.constant 42 {{.*}} loc("Modified.sol":9:9)
// CHECK:             sol.store {{.*}} loc("Modified.sol":9:9)
// CHECK-NEXT:        sol.leave loc("Modified.sol":9:9)
// The scope wrapping the original body, which has no invocation.
// CHECK:           } loc("Modified.sol":0:0)
// CHECK:           sol.leave loc("Modified.sol":6:7)
// The modifier's layer, at its invocation.
// CHECK:         } loc("Modified.sol":8:30)
// CHECK:         sol.load {{.*}} loc("Modified.sol":0:0)
// CHECK-NEXT:    sol.return {{.*}} loc("Modified.sol":0:0)
