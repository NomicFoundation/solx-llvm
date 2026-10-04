// RUN: mlir-opt %s --sol-inline-modifiers --convert-sol-to-yul | FileCheck %s

// Each inlined modifier is a scope with its argument substituted for its
// parameter; the innermost scope is the function body, and code after `_`
// follows the inner scope.

// CHECK-LABEL: yul.func @f : (i256) -> ()
// CHECK:         yul.scope {
// CHECK:           %[[NA:.*]] = yul.add %arg0,
// CHECK:           yul.scope {
// CHECK-NEXT:        yul.scope {
// CHECK-NEXT:          yul.leave_scope
// CHECK-NEXT:        }
// CHECK-NEXT:        yul.func_call @inner(%[[NA]]) : (i256) -> ()
// CHECK-NEXT:        yul.leave_scope
// CHECK-NEXT:      }
// CHECK-NEXT:      yul.func_call @outer(%arg0) : (i256) -> ()
// CHECK-NEXT:      yul.leave_scope
// CHECK:         yul.func_return

// The inlined body's return values land in the result slots and leave the
// body scope, so the modifier's tail still runs before the function returns.
// CHECK-LABEL: yul.func @test : () -> (i256, i256)
// CHECK:         %[[R0:.*]] = llvm.alloca
// CHECK:         %[[R1:.*]] = llvm.alloca
// CHECK:         yul.scope {
// CHECK:           yul.sstore
// CHECK:           yul.scope {
// CHECK:             %[[X:.*]] = yul.arith_shr
// CHECK:             %[[Y:.*]] = yul.arith_shr
// CHECK:             llvm.store %[[X]], %[[R0]] {
// CHECK:             llvm.store %[[Y]], %[[R1]] {
// CHECK-NEXT:        yul.leave_scope
// CHECK:           yul.sstore
// CHECK:           yul.leave_scope
// CHECK:         %[[V0:.*]] = llvm.load %[[R0]] {
// CHECK:         %[[V1:.*]] = llvm.load %[[R1]] {
// CHECK:         yul.func_return %[[V0]], %[[V1]] : i256, i256

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @x slot 0 offset 0 : ui256
    sol.state_var @y slot 1 offset 0 : ui256
    sol.func @outer(%arg0: ui256) {
      sol.return
    }
    sol.func @inner(%arg0: ui256) {
      sol.return
    }
    sol.func @test() -> (ui256, ui256) {
      sol.modifier_invocation @m {
        sol.yield
      }
      %0 = sol.addr_of @x : !sol.ptr<ui256, Storage>
      %1 = sol.addr_of @y : !sol.ptr<ui256, Storage>
      %2 = sol.load %0 : !sol.ptr<ui256, Storage>, ui256
      %3 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
      sol.return %2, %3 : ui256, ui256
    }
    sol.func @f(%arg0: ui256) {
      sol.modifier_invocation @o {
        sol.yield %arg0 : ui256
      }
      sol.modifier_invocation @n {
        %c1_ui256 = sol.constant 1 : ui256
        %0 = sol.cadd %arg0, %c1_ui256 : ui256
        sol.yield %0 : ui256
      }
      sol.return
    }
    sol.modifier @o(%arg0: ui256) {
      sol.placeholder
      sol.call @outer(%arg0) : (ui256) -> ()
      sol.return
    }
    sol.modifier @n(%arg0: ui256) {
      sol.placeholder
      sol.call @inner(%arg0) : (ui256) -> ()
      sol.return
    }
    sol.modifier @m() {
      %c1_ui256 = sol.constant 1 : ui256
      %0 = sol.addr_of @x : !sol.ptr<ui256, Storage>
      sol.store %c1_ui256, %0 : ui256, !sol.ptr<ui256, Storage>
      sol.placeholder
      %c2_ui256 = sol.constant 2 : ui256
      %1 = sol.addr_of @y : !sol.ptr<ui256, Storage>
      sol.store %c2_ui256, %1 : ui256, !sol.ptr<ui256, Storage>
      sol.return
    }
  } {kind = #Contract}
}
