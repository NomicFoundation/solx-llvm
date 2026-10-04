// RUN: mlir-opt %s | mlir-opt | FileCheck %s

sol.contract @C {
  // CHECK: sol.func private @decl(ui256, !sol.string<Memory>) -> (ui256, i1)
  sol.func private @decl(ui256, !sol.string<Memory>) -> (ui256, i1)

  // CHECK:      sol.func @empty() {
  // CHECK-NEXT:   sol.return{{$}}
  sol.func @empty() {
    sol.return
  }

  // CHECK:      sol.func @arg_res_attrs(%{{.*}}: ui256 {sol.foo}) -> (ui256 {sol.bar}) {
  // CHECK-NEXT:   sol.return {foo} %{{.*}} : ui256{{$}}
  sol.func @arg_res_attrs(%a: ui256 {sol.foo}) -> (ui256 {sol.bar}) {
    sol.return {foo} %a : ui256
  }

  // CHECK: sol.func @attrs() attributes {id = 7 : i64, orig_fn_type = () -> (), selector = 305419896 : i32, state_mutability = #{{.*}}}
  sol.func @attrs() attributes {id = 7 : i64, orig_fn_type = () -> (), selector = 305419896 : i32, state_mutability = #sol<StateMutability Payable>} {
    sol.return
  }

  // CHECK:      sol.modifier @m() {
  // CHECK-NEXT:   sol.placeholder
  sol.modifier @m() {
    sol.placeholder
    sol.return
  }

  // CHECK: sol.modifier @n(%{{.*}}: ui256 {sol.foo}, %{{.*}}: i1)
  sol.modifier @n(%a: ui256 {sol.foo}, %b: i1) {
    sol.placeholder
    sol.return
  }

  // CHECK-LABEL: sol.func @calls
  sol.func @calls(%a: ui256, %b: i1) -> (ui256, i1) {
    // CHECK:      sol.modifier_invocation @m {
    // CHECK-NEXT:   sol.yield{{$}}
    // CHECK:      sol.modifier_invocation @n {
    // CHECK-NEXT:   sol.yield %{{.*}}, %{{.*}} : ui256, i1 {foo}{{$}}
    sol.modifier_invocation @m {
      sol.yield
    }
    sol.modifier_invocation @n {
      sol.yield %a, %b : ui256, i1 {foo}
    }
    // CHECK: sol.call @empty() : () -> ()
    // CHECK: sol.call @arg_res_attrs(%{{.*}}) : (ui256) -> ui256
    // CHECK: sol.call @calls(%{{.*}}, %{{.*}}) {foo} : (ui256, i1) -> (ui256, i1)
    sol.call @empty() : () -> ()
    %0 = sol.call @arg_res_attrs(%a) : (ui256) -> ui256
    %1:2 = sol.call @calls(%a, %b) {foo} : (ui256, i1) -> (ui256, i1)
    // CHECK: sol.return %{{.*}}#0, %{{.*}}#1 : ui256, i1{{$}}
    sol.return %1#0, %1#1 : ui256, i1
  }
} {kind = #sol<ContractKind Contract>, runtime}
