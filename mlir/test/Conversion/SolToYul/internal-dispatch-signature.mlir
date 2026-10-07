// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Inline assembly can reinterpret an internal function pointer as one of
// another type, so a call dispatches to every function whose signature lowers
// to the call's: @lt and @ltBytes32 through a (ui256, ui256) -> i1 pointer,
// but not @neg.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
#Pure = #sol<StateMutability Pure>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:       yul.func @f :
// CHECK-NOT:     yul.revert
// CHECK:         yul.func_call @[[DISPATCH:__sol\.internal_dispatch[^(]*]](%{{.*}}, %{{.*}}, %{{.*}}) : (i256, i256, i256) -> i256
// CHECK:         yul.func @[[DISPATCH]] : (i256, i256, i256) -> i256 {
// CHECK:           yul.switch %{{.*}} : i256
// CHECK-NOT:         @neg
// CHECK-DAG:         yul.func_call @lt(
// CHECK-DAG:         yul.func_call @ltBytes32(
// CHECK-NOT:         @neg
// CHECK:           default {
// CHECK-NOT:         yul.func_call
// CHECK:           yul.func_return

module {
  sol.contract @C {
    sol.func @ctor() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func private @lt(%a: !sol.address, %b: !sol.address) -> i1 attributes {id = 1 : i64, state_mutability = #Pure} {
      %0 = sol.cmp lt, %a, %b : !sol.address
      sol.return %0 : i1
    }
    sol.func private @ltBytes32(%a: !sol.fixedbytes<32>, %b: !sol.fixedbytes<32>) -> i1 attributes {id = 2 : i64, state_mutability = #Pure} {
      %0 = sol.cmp lt, %a, %b : !sol.fixedbytes<32>
      sol.return %0 : i1
    }
    sol.func private @neg(%a: ui256) -> i1 attributes {id = 3 : i64, state_mutability = #Pure} {
      %false = sol.constant false
      sol.return %false : i1
    }
    sol.func private @f(%comp: !sol.func_ref<(ui256, ui256) -> i1>, %a: ui256, %b: ui256) -> i1 attributes {id = 4 : i64, state_mutability = #Pure} {
      %0 = sol.func_constant @lt : !sol.func_ref<(!sol.address, !sol.address) -> i1>
      %1 = sol.func_constant @ltBytes32 : !sol.func_ref<(!sol.fixedbytes<32>, !sol.fixedbytes<32>) -> i1>
      %2 = sol.func_constant @neg : !sol.func_ref<(ui256) -> i1>
      %3 = sol.icall %comp(%a, %b) : !sol.func_ref<(ui256, ui256) -> i1>, (ui256, ui256) -> i1
      sol.return %3 : i1
    }
  } {kind = #Contract}
}
