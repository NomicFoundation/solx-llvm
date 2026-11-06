// RUN: mlir-opt %s --pass-pipeline='builtin.module(sol.contract(sol.func(mem2reg)))' | FileCheck %s

sol.contract @C {
  // Inline assembly writes the slot through a Yul pointer.
  // CHECK-LABEL: sol.func @assembly(
  // CHECK-NEXT:    %[[SLOT:.*]] = sol.alloca : !sol.ptr<ui256, Stack>
  // CHECK-NEXT:    sol.store %{{.*}}, %[[SLOT]]
  // CHECK-NEXT:    sol.inline_asm {
  // CHECK:           sol.yul_ptr_cast %[[SLOT]]
  // CHECK:         %[[V:.*]] = sol.load %[[SLOT]]
  // CHECK-NEXT:    sol.return %[[V]]
  sol.func @assembly(%x: ui256) -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    sol.inline_asm {
      %c1 = yul.constant 1
      %1 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
      yul.store %c1, %1 : i256, !yul.ptr
    }
    %2 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %2 : ui256
  }

  // A sol.leave exits the scope early, and it carries no value.
  // CHECK-LABEL: sol.func @nestedLeave(
  // CHECK-NEXT:    %[[SLOT:.*]] = sol.alloca : !sol.ptr<ui256, Stack>
  // CHECK-NEXT:    sol.store %{{.*}}, %[[SLOT]]
  // CHECK-NEXT:    sol.scope {
  // CHECK:           sol.leave
  // CHECK:           sol.store %{{.*}}, %[[SLOT]]
  // CHECK:         %[[V:.*]] = sol.load %[[SLOT]]
  // CHECK-NEXT:    sol.return %[[V]]
  sol.func @nestedLeave(%x: ui256, %y: ui256, %c: i1) -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    sol.scope {
      sol.if %c {
        sol.leave
      } else {
      }
      sol.store %y, %0 : ui256, !sol.ptr<ui256, Stack>
      sol.yield
    }
    %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %1 : ui256
  }
} {kind = #sol<ContractKind Contract>, runtime}
