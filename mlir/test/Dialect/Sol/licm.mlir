// RUN: mlir-opt %s --pass-pipeline='builtin.module(sol.contract(sol.func(sol-licm)))' | FileCheck %s

sol.contract @C {
  sol.state_var @total slot 0 offset 0 : ui256
  sol.state_var @t transient slot 0 offset 0 : ui256
  sol.state_var @b slot 1 offset 0 : !sol.mapping<!sol.address, ui256>
  sol.state_var @p slot 2 offset 0 : !sol.struct<(ui256, ui256), Storage>
  sol.state_var @e slot 4 offset 0 : !sol.enum<2>

  // A slot the loop reads and writes is loaded before the loop, carried with a
  // written flag, and stored after the loop if the flag is set. An invariant op
  // that computes no storage address stays in the loop.
  // CHECK-LABEL: sol.func @accumulate(
  // CHECK:         %[[ADDR:.*]] = sol.addr_of @total
  // CHECK-NEXT:    %[[INIT:.*]] = sol.load %[[ADDR]]
  // CHECK-NEXT:    %[[FALSE:.*]] = sol.constant false
  // CHECK-NEXT:    %[[LOOP:.*]]:3 = sol.for %{{.*}}, %[[INIT]], %[[FALSE]] :
  // CHECK-NEXT:    ^bb0
  // CHECK-NEXT:      sol.length
  // CHECK:         } body {
  // CHECK-NEXT:    ^bb0(%{{.*}}: ui256, %[[SUM:.*]]: ui256, %{{.*}}: i1):
  // CHECK:           %[[NEW:.*]] = sol.cadd %[[SUM]]
  // CHECK-NEXT:      %[[TRUE:.*]] = sol.constant true
  // CHECK-NEXT:      sol.yield %{{.*}}, %[[NEW]], %[[TRUE]]
  // CHECK:         sol.if %[[LOOP]]#2 {
  // CHECK-NEXT:      sol.store %[[LOOP]]#1, %[[ADDR]]
  sol.func @accumulate(%a: !sol.array<? x ui256, CallData>) {
    %c1 = sol.constant 1 : ui256
    %c0 = sol.constant 0 : ui256
    %0 = sol.for %c0 : ui256 -> ui256 cond {
    ^bb0(%i: ui256):
      %1 = sol.length %a : !sol.array<? x ui256, CallData>
      %2 = sol.cmp lt, %i, %1 : ui256
      sol.condition %2, %i : ui256
    } body {
    ^bb0(%i: ui256):
      %1 = sol.gep %a, %i : !sol.array<? x ui256, CallData>, ui256, !sol.ptr<ui256, CallData>
      %2 = sol.load %1 : !sol.ptr<ui256, CallData>, ui256
      %3 = sol.addr_of @total : !sol.ptr<ui256, Storage>
      %4 = sol.load %3 : !sol.ptr<ui256, Storage>, ui256
      %5 = sol.cadd %4, %2 : ui256
      sol.store %5, %3 : ui256, !sol.ptr<ui256, Storage>
      sol.yield %i : ui256
    } step {
    ^bb0(%i: ui256):
      %1 = sol.cadd %i, %c1 : ui256
      sol.yield %1 : ui256
    }
    sol.return
  }

  // CHECK-LABEL: sol.func @transient(
  // CHECK:         %[[ADDR:.*]] = sol.addr_of @t
  // CHECK-NEXT:    %[[INIT:.*]] = sol.load %[[ADDR]]
  // CHECK:         %[[LOOP:.*]]:3 = sol.while %{{.*}}, %[[INIT]], %{{.*}} :
  // CHECK:         sol.if %[[LOOP]]#2 {
  // CHECK-NEXT:      sol.store %[[LOOP]]#1, %[[ADDR]] : ui256, !sol.ptr<ui256, Transient>
  sol.func @transient(%n: ui256) {
    %c1 = sol.constant 1 : ui256
    %c0 = sol.constant 0 : ui256
    %0 = sol.while %c0 : ui256 -> ui256 {
    ^bb0(%i: ui256):
      %1 = sol.cmp lt, %i, %n : ui256
      sol.condition %1, %i : ui256
    } do {
    ^bb0(%i: ui256):
      %1 = sol.addr_of @t : !sol.ptr<ui256, Transient>
      %2 = sol.load %1 : !sol.ptr<ui256, Transient>, ui256
      %3 = sol.cadd %2, %i : ui256
      sol.store %3, %1 : ui256, !sol.ptr<ui256, Transient>
      %4 = sol.cadd %i, %c1 : ui256
      sol.yield %4 : ui256
    }
    sol.return
  }

  // The slot address leaves the if and the loop, the flag is set only where the
  // loop stores, and a return out of the loop stores first.
  // CHECK-LABEL: sol.func @conditional(
  // CHECK:         %[[MAP:.*]] = sol.map
  // CHECK-NEXT:    %[[INIT:.*]] = sol.load %[[MAP]]
  // CHECK:         %[[LOOP:.*]]:3 = sol.for %{{.*}}, %[[INIT]], %{{.*}} :
  // CHECK:         } body {
  // CHECK-NEXT:    ^bb0(%{{.*}}: ui256, %[[SUM:.*]]: ui256, %[[FLAG:.*]]: i1):
  // CHECK:           %[[IF:.*]]:2 = sol.if
  // CHECK:             sol.yield %{{.*}}, %{{.*}} : ui256, i1
  // CHECK-NEXT:      } else {
  // CHECK-NEXT:        sol.yield %[[SUM]], %[[FLAG]]
  // CHECK:           sol.if %{{.*}} {
  // CHECK-NEXT:        sol.if %[[IF]]#1 {
  // CHECK-NEXT:          sol.store %[[IF]]#0, %[[MAP]]
  // CHECK:             sol.return
  // CHECK:         sol.if %[[LOOP]]#2 {
  // CHECK-NEXT:      sol.store %[[LOOP]]#1, %[[MAP]]
  sol.func @conditional(%n: ui256) {
    %c7 = sol.constant 7 : ui256
    %c2 = sol.constant 2 : ui256
    %c1 = sol.constant 1 : ui256
    %c0 = sol.constant 0 : ui256
    %0 = sol.for %c0 : ui256 -> ui256 cond {
    ^bb0(%i: ui256):
      %1 = sol.cmp lt, %i, %n : ui256
      sol.condition %1, %i : ui256
    } body {
    ^bb0(%i: ui256):
      %1 = sol.mod %i, %c2 : ui256
      %2 = sol.cmp eq, %1, %c0 : ui256
      sol.if %2 {
        %4 = sol.addr_of @b : !sol.mapping<!sol.address, ui256>
        %5 = sol.caller : !sol.address
        %6 = sol.map %4, %5 : !sol.mapping<!sol.address, ui256>, !sol.address, !sol.ptr<ui256, Storage>
        %7 = sol.load %6 : !sol.ptr<ui256, Storage>, ui256
        %8 = sol.cadd %7, %i : ui256
        sol.store %8, %6 : ui256, !sol.ptr<ui256, Storage>
        sol.yield
      } else {
      }
      %3 = sol.cmp eq, %i, %c7 : ui256
      sol.if %3 {
        sol.return
      } else {
      }
      sol.yield %i : ui256
    } step {
    ^bb0(%i: ui256):
      %1 = sol.cadd %i, %c1 : ui256
      sol.yield %1 : ui256
    }
    sol.return
  }

  // A slot the loop only reads is loaded once, with no flag and no store.
  // CHECK-LABEL: sol.func @read_only(
  // CHECK:         %[[VALUE:.*]] = sol.load
  // CHECK-NEXT:    sol.for
  // CHECK:           sol.cadd %{{.*}}, %[[VALUE]]
  // CHECK-NOT:     sol.store
  // CHECK:         sol.return
  sol.func @read_only(%n: ui256) -> ui256 {
    %c1 = sol.constant 1 : ui256
    %c0 = sol.constant 0 : ui256
    %0:2 = sol.for %c0, %c0 : ui256, ui256 -> ui256, ui256 cond {
    ^bb0(%i: ui256, %x: ui256):
      %1 = sol.cmp lt, %i, %n : ui256
      sol.condition %1, %i, %x : ui256, ui256
    } body {
    ^bb0(%i: ui256, %x: ui256):
      %1 = sol.addr_of @total : !sol.ptr<ui256, Storage>
      %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
      %3 = sol.cadd %x, %2 : ui256
      sol.yield %i, %3 : ui256, ui256
    } step {
    ^bb0(%i: ui256, %x: ui256):
      %1 = sol.cadd %i, %c1 : ui256
      sol.yield %1, %x : ui256, ui256
    }
    sol.return %0#1 : ui256
  }

  // Distinct members are disjoint, and a slot the loop only writes needs no
  // load.
  // CHECK-LABEL: sol.func @members(
  // CHECK:         %[[M0:.*]] = sol.gep %{{.*}}, %c0_ui64
  // CHECK-NEXT:    %[[M1:.*]] = sol.gep %{{.*}}, %c1_ui64
  // CHECK-NEXT:    %[[INIT:.*]] = sol.load %[[M0]]
  // CHECK-NOT:     sol.load
  // CHECK:         %[[LOOP:.*]]:5 = sol.for
  // CHECK:         sol.store %[[LOOP]]#3, %[[M1]]
  // CHECK:         sol.store %[[LOOP]]#1, %[[M0]]
  sol.func @members(%n: ui256) {
    %c1 = sol.constant 1 : ui256
    %c0 = sol.constant 0 : ui256
    %m0 = sol.constant 0 : ui64
    %m1 = sol.constant 1 : ui64
    %0 = sol.for %c0 : ui256 -> ui256 cond {
    ^bb0(%i: ui256):
      %1 = sol.cmp lt, %i, %n : ui256
      sol.condition %1, %i : ui256
    } body {
    ^bb0(%i: ui256):
      %1 = sol.addr_of @p : !sol.struct<(ui256, ui256), Storage>
      %2 = sol.gep %1, %m0 : !sol.struct<(ui256, ui256), Storage>, ui64, !sol.ptr<ui256, Storage>
      %3 = sol.gep %1, %m1 : !sol.struct<(ui256, ui256), Storage>, ui64, !sol.ptr<ui256, Storage>
      %4 = sol.load %2 : !sol.ptr<ui256, Storage>, ui256
      sol.store %4, %3 : ui256, !sol.ptr<ui256, Storage>
      sol.store %i, %2 : ui256, !sol.ptr<ui256, Storage>
      sol.yield %i : ui256
    } step {
    ^bb0(%i: ui256):
      %1 = sol.cadd %i, %c1 : ui256
      sol.yield %1 : ui256
    }
    sol.return
  }

  sol.func @g() {
    sol.return
  }

  // A call may access storage.
  // CHECK-LABEL: sol.func @call(
  // CHECK:         body {
  // CHECK-NEXT:    ^bb0
  // CHECK-NEXT:      sol.store
  sol.func @call(%n: ui256) {
    %c1 = sol.constant 1 : ui256
    %c0 = sol.constant 0 : ui256
    %0 = sol.for %c0 : ui256 -> ui256 cond {
    ^bb0(%i: ui256):
      %1 = sol.cmp lt, %i, %n : ui256
      sol.condition %1, %i : ui256
    } body {
    ^bb0(%i: ui256):
      %1 = sol.addr_of @total : !sol.ptr<ui256, Storage>
      sol.store %i, %1 : ui256, !sol.ptr<ui256, Storage>
      sol.call @g() : () -> ()
      sol.yield %i : ui256
    } step {
    ^bb0(%i: ui256):
      %1 = sol.cadd %i, %c1 : ui256
      sol.yield %1 : ui256
    }
    sol.return
  }

  // An address from an argument may alias any slot.
  // CHECK-LABEL: sol.func @argument(
  // CHECK:         body {
  // CHECK-NEXT:    ^bb0
  // CHECK-NEXT:      sol.store
  sol.func @argument(%q: !sol.ptr<ui256, Storage>, %n: ui256) {
    %c1 = sol.constant 1 : ui256
    %c0 = sol.constant 0 : ui256
    %0 = sol.for %c0 : ui256 -> ui256 cond {
    ^bb0(%i: ui256):
      %1 = sol.cmp lt, %i, %n : ui256
      sol.condition %1, %i : ui256
    } body {
    ^bb0(%i: ui256):
      %1 = sol.addr_of @total : !sol.ptr<ui256, Storage>
      sol.store %i, %1 : ui256, !sol.ptr<ui256, Storage>
      sol.store %c0, %q : ui256, !sol.ptr<ui256, Storage>
      sol.yield %i : ui256
    } step {
    ^bb0(%i: ui256):
      %1 = sol.cadd %i, %c1 : ui256
      sol.yield %1 : ui256
    }
    sol.return
  }

  // Storing an out-of-range enum panics, so every store stays.
  // CHECK-LABEL: sol.func @enum(
  // CHECK:         body {
  // CHECK-NEXT:    ^bb0
  // CHECK-NEXT:      sol.store
  sol.func @enum(%v: !sol.enum<2>, %n: ui256) {
    %c1 = sol.constant 1 : ui256
    %c0 = sol.constant 0 : ui256
    %0 = sol.for %c0 : ui256 -> ui256 cond {
    ^bb0(%i: ui256):
      %1 = sol.cmp lt, %i, %n : ui256
      sol.condition %1, %i : ui256
    } body {
    ^bb0(%i: ui256):
      %1 = sol.addr_of @e : !sol.ptr<!sol.enum<2>, Storage>
      sol.store %v, %1 : !sol.enum<2>, !sol.ptr<!sol.enum<2>, Storage>
      sol.yield %i : ui256
    } step {
    ^bb0(%i: ui256):
      %1 = sol.cadd %i, %c1 : ui256
      sol.yield %1 : ui256
    }
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}
