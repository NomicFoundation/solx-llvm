// RUN: mlir-opt %s --pass-pipeline='builtin.module(sol.contract(sol.func(mem2reg)))' | FileCheck %s --implicit-check-not=sol.alloca

sol.contract @C {
  // Each load reads the store before it.
  // CHECK-LABEL: sol.func @reassigned(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256
  // CHECK-NEXT:    sol.return %[[X]], %[[Y]] : ui256, ui256
  sol.func @reassigned(%x: ui256, %y: ui256) -> (ui256, ui256) {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.store %y, %0 : ui256, !sol.ptr<ui256, Stack>
    %2 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %1, %2 : ui256, ui256
  }

  // A slot allocated in a region and used only there is promoted in it.
  // CHECK-LABEL: sol.func @inner(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256, %[[C:[^:]*]]: i1, %[[P:[^:]*]]: !sol.ptr<ui256, Storage>
  // CHECK-NEXT:    sol.if %[[C]] {
  // CHECK-NEXT:      sol.store %[[X]], %[[P]]
  // CHECK-NEXT:      sol.store %[[Y]], %[[P]]
  // CHECK-NEXT:      sol.yield
  sol.func @inner(%x: ui256, %y: ui256, %c: i1, %p: !sol.ptr<ui256, Storage>) {
    sol.if %c {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
      %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      sol.store %1, %p : ui256, !sol.ptr<ui256, Storage>
      sol.store %y, %0 : ui256, !sol.ptr<ui256, Stack>
      %2 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      sol.store %2, %p : ui256, !sol.ptr<ui256, Storage>
      sol.yield
    } else {
    }
    sol.return
  }

  // A load before any store reads the type's default.
  // CHECK-LABEL: sol.func @default(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256
  // CHECK-NEXT:    %[[ZERO:.*]] = sol.constant 0 : ui256
  // CHECK-NEXT:    sol.return %[[ZERO]], %[[X]] : ui256, ui256
  sol.func @default(%x: ui256) -> (ui256, ui256) {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    %2 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %1, %2 : ui256, ui256
  }

  // The unused defaults go with the slots: a constant under an address cast,
  // and a memory allocation.
  // CHECK-LABEL: sol.func @unusedDefaults(
  // CHECK-SAME:    %[[A:[^:]*]]: !sol.address, %[[S:[^:]*]]: !sol.string<Memory>
  // CHECK-NEXT:    sol.return %[[A]], %[[S]] : !sol.address, !sol.string<Memory>
  sol.func @unusedDefaults(%a: !sol.address, %s: !sol.string<Memory>) -> (!sol.address, !sol.string<Memory>) {
    %0 = sol.alloca : !sol.ptr<!sol.address, Stack>
    sol.store %a, %0 : !sol.address, !sol.ptr<!sol.address, Stack>
    %1 = sol.load %0 : !sol.ptr<!sol.address, Stack>, !sol.address
    %2 = sol.alloca : !sol.ptr<!sol.string<Memory>, Stack>
    sol.store %s, %2 : !sol.string<Memory>, !sol.ptr<!sol.string<Memory>, Stack>
    %3 = sol.load %2 : !sol.ptr<!sol.string<Memory>, Stack>, !sol.string<Memory>
    sol.return %1, %3 : !sol.address, !sol.string<Memory>
  }
  // A value stored in both branches leaves the if as its result.
  // CHECK-LABEL: sol.func @branches(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256, %[[Z:[^:]*]]: ui256, %[[C:[^:]*]]: i1
  // CHECK-NEXT:    %[[R:.*]] = sol.if %[[C]] -> ui256 {
  // CHECK-NEXT:      sol.yield %[[Y]] : ui256
  // CHECK-NEXT:    } else {
  // CHECK-NEXT:      sol.yield %[[Z]] : ui256
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[R]] : ui256
  sol.func @branches(%x: ui256, %y: ui256, %z: ui256, %c: i1) -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    sol.if %c {
      sol.store %y, %0 : ui256, !sol.ptr<ui256, Stack>
      sol.yield
    } else {
      sol.store %z, %0 : ui256, !sol.ptr<ui256, Stack>
      sol.yield
    }
    %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %1 : ui256
  }

  // An if without an else gets one that yields the value before the if.
  // CHECK-LABEL: sol.func @thenOnly(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256, %[[C:[^:]*]]: i1
  // CHECK-NEXT:    %[[R:.*]] = sol.if %[[C]] -> ui256 {
  // CHECK-NEXT:      sol.yield %[[Y]] : ui256
  // CHECK-NEXT:    } else {
  // CHECK-NEXT:      sol.yield %[[X]] : ui256
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[R]] : ui256
  sol.func @thenOnly(%x: ui256, %y: ui256, %c: i1) -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    sol.if %c {
      sol.store %y, %0 : ui256, !sol.ptr<ui256, Stack>
      sol.yield
    } else {
    }
    %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %1 : ui256
  }

  // A branch that returns yields nothing.
  // CHECK-LABEL: sol.func @earlyReturn(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256, %[[C:[^:]*]]: i1
  // CHECK-NEXT:    %[[R:.*]] = sol.if %[[C]] -> ui256 {
  // CHECK-NEXT:      sol.return %[[Y]] : ui256
  // CHECK-NEXT:    } else {
  // CHECK-NEXT:      sol.yield %[[X]] : ui256
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[R]] : ui256
  sol.func @earlyReturn(%x: ui256, %y: ui256, %c: i1) -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    sol.if %c {
      sol.store %y, %0 : ui256, !sol.ptr<ui256, Stack>
      %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      sol.return %1 : ui256
    } else {
    }
    %2 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %2 : ui256
  }

  // A value stored in a scope leaves it as its result.
  // CHECK-LABEL: sol.func @scope(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256
  // CHECK-NEXT:    %[[R:.*]] = sol.scope -> ui256 {
  // CHECK-NEXT:      sol.yield %[[Y]] : ui256
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[R]] : ui256
  sol.func @scope(%x: ui256, %y: ui256) -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    sol.scope {
      sol.store %y, %0 : ui256, !sol.ptr<ui256, Stack>
      sol.yield
    }
    %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %1 : ui256
  }
} {kind = #sol<ContractKind Contract>, runtime}
