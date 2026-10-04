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
