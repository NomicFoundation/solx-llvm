// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A pointer the creation code stored can reach a function the runtime code
// takes no pointer to. The runtime contract lists such a function in its
// creation func refs, which adds it to the dispatch cases of the calls of its
// type, next to the functions the runtime code takes a pointer to. The calls
// through a pointer type share one dispatch function, which follows its first
// caller, and a pointer type with no target dispatches to the panic alone. The
// functions follow the code, the last one first.

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         yul.func @e
// CHECK:           yul.func_call @[[TWOARG:__sol\.internal_dispatch\.2]](
// CHECK:         yul.func @f
// CHECK:           yul.func_call @[[NOARG:__sol\.internal_dispatch\.0]](
// CHECK:           yul.func_call @[[ONEARG:__sol\.internal_dispatch\.1]](
// CHECK:           yul.func_call @[[TWOARG]](
// CHECK:           yul.func_return
// CHECK-NEXT:    }
// CHECK-NEXT:    yul.func @[[TWOARG]] : (i256, i256, i256) -> ()
// CHECK-NEXT:    ^bb0(%[[POINTER:.*]]: i256, %{{.*}}: i256, %{{.*}}: i256):
// CHECK-NEXT:      yul.switch %[[POINTER]] : i256
// CHECK-NEXT:      default {
// CHECK:             yul.revert
// CHECK:         yul.func @[[ONEARG]]
// CHECK:           case 10 {
// CHECK-NEXT:        yul.func_call @k(
// CHECK:           default {
// CHECK:         yul.func @[[NOARG]]
// CHECK:           case 8 {
// CHECK-NEXT:        yul.func_call @h()
// CHECK:           case 7 {
// CHECK-NEXT:        yul.func_call @g()
// CHECK:           default {
// CHECK:         yul.func @k
// CHECK:         yul.func @h
// CHECK:         yul.func @g
// CHECK-NOT:     yul.func @

module {
  sol.contract @C {
    sol.func @g() attributes {id = 7 : i64, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @h() attributes {id = 8 : i64, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @k(%arg0: ui256) attributes {id = 10 : i64, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.default_func_constant : !sol.func_ref<() -> ()>
      sol.icall %0() : !sol.func_ref<() -> ()>, () -> ()
      %1 = sol.func_constant @h : !sol.func_ref<() -> ()>
      %2 = sol.default_func_constant : !sol.func_ref<(ui256) -> ()>
      %3 = sol.constant 1 : ui256
      sol.icall %2(%3) : !sol.func_ref<(ui256) -> ()>, (ui256) -> ()
      %4 = sol.default_func_constant : !sol.func_ref<(ui256, ui256) -> ()>
      sol.icall %4(%3, %3) : !sol.func_ref<(ui256, ui256) -> ()>, (ui256, ui256) -> ()
      sol.return
    }
    sol.func @e() attributes {orig_fn_type = () -> (), selector = 2 : i32, state_mutability = #NonPayable} {
      %0 = sol.default_func_constant : !sol.func_ref<(ui256, ui256) -> ()>
      %1 = sol.constant 1 : ui256
      sol.icall %0(%1, %1) : !sol.func_ref<(ui256, ui256) -> ()>, (ui256, ui256) -> ()
      sol.return
    }
  } {creation_func_refs = [@g, @k], kind = #Contract, runtime}
}
