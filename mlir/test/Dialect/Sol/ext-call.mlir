// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK-LABEL: func @ext_call
func.func @ext_call(%addr: !sol.address, %gas: ui256, %val: ui256, %sel: ui256, %a: ui256) {
  // CHECK: sol.ext_call "f"() at %{{.*}} gas %{{.*}} value %{{.*}} selector %{{.*}} {callee_type = () -> ()} : !sol.address, () -> i1
  %0 = sol.ext_call "f"() at %addr gas %gas value %val selector %sel {callee_type = () -> ()} : !sol.address, () -> i1
  // CHECK: sol.ext_call "g"(%{{.*}}, %{{.*}}) at %{{.*}} gas %{{.*}} value %{{.*}} selector %{{.*}} {callee_type = (ui256, ui256) -> (ui256, ui256), delegate_call, library_call, static_call, try_call} : !sol.address, (ui256, ui256) -> (i1, ui256, ui256)
  %1:3 = sol.ext_call "g"(%a, %a) at %addr gas %gas value %val selector %sel {callee_type = (ui256, ui256) -> (ui256, ui256), delegate_call, library_call, static_call, try_call} : !sol.address, (ui256, ui256) -> (i1, ui256, ui256)
  // CHECK: sol.ext_call "h"() at %{{.*}} gas %{{.*}} value %{{.*}} selector %{{.*}} {callee_type = () -> ()} : ui256, () -> i1
  %2 = sol.ext_call "h"() at %a gas %gas value %val selector %sel {callee_type = () -> ()} : ui256, () -> i1
  return
}

// CHECK-LABEL: func @new
func.func @new(%v: ui256, %salt: ui256, %a: ui256, %b: !sol.string<Memory>) {
  // CHECK: sol.new "D" value = %{{.*}} ctor() : !sol.contract<"D">
  %0 = sol.new "D" value = %v ctor() : !sol.contract<"D">
  // CHECK: sol.new "D" value = %{{.*}} salt = %{{.*}} ctor() : !sol.contract<"D">
  %1 = sol.new "D" value = %v salt = %salt ctor() : !sol.contract<"D">
  // CHECK: sol.new "D" value = %{{.*}} ctor(%{{.*}}, %{{.*}} : ui256, !sol.string<Memory>) : !sol.contract<"D">
  %2 = sol.new "D" value = %v ctor(%a, %b : ui256, !sol.string<Memory>) : !sol.contract<"D">
  // CHECK: sol.new "D" value = %{{.*}} salt = %{{.*}} ctor(%{{.*}} : ui256) try {foo} : !sol.contract<"D", payable>
  %3 = sol.new "D" value = %v salt = %salt ctor(%a : ui256) try {foo} : !sol.contract<"D", payable>
  return
}

// CHECK-LABEL: func @gas
// CHECK-SAME:    (%[[ADDR:[^:]*]]: !sol.address, %[[GAS:[^:]*]]: ui256, %[[VAL:[^:]*]]: ui256, %[[SEL:[^:]*]]: ui256, %[[A:[^:]*]]: ui256, %[[F:[^:]*]]: !sol.ext_func_ref<(ui256) -> ui256>, %[[INP:[^:]*]]: !sol.string<Memory>)
func.func @gas(%addr: !sol.address, %gas: ui256, %val: ui256, %sel: ui256, %a: ui256, %f: !sol.ext_func_ref<(ui256) -> ui256>, %inp: !sol.string<Memory>) {
  // CHECK: sol.ext_call "f"(%[[A]]) at %[[ADDR]] value %[[VAL]] selector %[[SEL]] {callee_type = (ui256) -> ui256} : !sol.address, (ui256) -> (i1, ui256)
  %0:2 = sol.ext_call "f"(%a) at %addr value %val selector %sel {callee_type = (ui256) -> ui256} : !sol.address, (ui256) -> (i1, ui256)
  // CHECK: sol.ext_icall %[[F]](%[[A]]) value %[[VAL]] : <(ui256) -> ui256>, (ui256) -> (i1, ui256)
  %1:2 = sol.ext_icall %f(%a) value %val : <(ui256) -> ui256>, (ui256) -> (i1, ui256)
  // CHECK: sol.ext_icall %[[F]](%[[A]]) gas %[[GAS]] value %[[VAL]] : <(ui256) -> ui256>, (ui256) -> (i1, ui256)
  %2:2 = sol.ext_icall %f(%a) gas %gas value %val : <(ui256) -> ui256>, (ui256) -> (i1, ui256)
  // CHECK: sol.bare_call %[[ADDR]] value %[[VAL]] input %[[INP]] : !sol.address, ui256, !sol.string<Memory> -> i1, !sol.string<Memory>
  %3:2 = sol.bare_call %addr value %val input %inp : !sol.address, ui256, !sol.string<Memory> -> i1, !sol.string<Memory>
  // CHECK: sol.bare_call %[[ADDR]] gas %[[GAS]] value %[[VAL]] input %[[INP]] : !sol.address, ui256, !sol.string<Memory> -> i1, !sol.string<Memory>
  %4:2 = sol.bare_call %addr gas %gas value %val input %inp : !sol.address, ui256, !sol.string<Memory> -> i1, !sol.string<Memory>
  // CHECK: sol.bare_delegate_call %[[ADDR]] input %[[INP]] : !sol.address, !sol.string<Memory> -> i1, !sol.string<Memory>
  %5:2 = sol.bare_delegate_call %addr input %inp : !sol.address, !sol.string<Memory> -> i1, !sol.string<Memory>
  // CHECK: sol.bare_delegate_call %[[ADDR]] gas %[[GAS]] input %[[INP]] : !sol.address, !sol.string<Memory> -> i1, !sol.string<Memory>
  %6:2 = sol.bare_delegate_call %addr gas %gas input %inp : !sol.address, !sol.string<Memory> -> i1, !sol.string<Memory>
  // CHECK: sol.bare_static_call %[[ADDR]] input %[[INP]] : !sol.address, !sol.string<Memory> -> i1, !sol.string<Memory>
  %7:2 = sol.bare_static_call %addr input %inp : !sol.address, !sol.string<Memory> -> i1, !sol.string<Memory>
  // CHECK: sol.bare_static_call %[[ADDR]] gas %[[GAS]] input %[[INP]] : !sol.address, !sol.string<Memory> -> i1, !sol.string<Memory>
  %8:2 = sol.bare_static_call %addr gas %gas input %inp : !sol.address, !sol.string<Memory> -> i1, !sol.string<Memory>
  return
}
