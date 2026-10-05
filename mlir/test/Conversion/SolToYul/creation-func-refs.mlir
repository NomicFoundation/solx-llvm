// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A pointer the creation code stored can reach a function the runtime code
// takes no pointer to. The runtime contract lists such a function in its
// creation func refs, which adds it to the dispatch cases of the calls of its
// type, next to the functions the runtime code takes a pointer to.

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         yul.func_call @__sol.internal_dispatch.7.8
// CHECK:         yul.func_call @__sol.internal_dispatch.10
// CHECK-DAG:     yul.func @__sol.internal_dispatch.7.8
// CHECK-DAG:     yul.func @__sol.internal_dispatch.10
// CHECK-DAG:       yul.func_call @g()
// CHECK-DAG:       yul.func_call @h()
// CHECK-DAG:       yul.func_call @k(
sol.contract @C {
  sol.func private @g() attributes {id = 7 : i64, state_mutability = #NonPayable} {
    sol.return
  }
  sol.func private @h() attributes {id = 8 : i64, state_mutability = #NonPayable} {
    sol.return
  }
  sol.func private @k(%arg0: ui256) attributes {id = 10 : i64, state_mutability = #NonPayable} {
    sol.return
  }
  sol.func @f() attributes {id = 9 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
    %0 = sol.default_func_constant : !sol.func_ref<() -> ()>
    sol.icall %0() : !sol.func_ref<() -> ()>, () -> ()
    %1 = sol.func_constant @h : !sol.func_ref<() -> ()>
    %2 = sol.default_func_constant : !sol.func_ref<(ui256) -> ()>
    %3 = sol.constant 1 : ui256
    sol.icall %2(%3) : !sol.func_ref<(ui256) -> ()>, (ui256) -> ()
    sol.return
  }
} {creation_func_refs = [@g, @k], kind = #Contract, runtime}
