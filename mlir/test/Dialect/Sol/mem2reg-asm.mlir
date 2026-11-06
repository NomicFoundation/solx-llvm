// RUN: mlir-opt %s --pass-pipeline='builtin.module(sol.contract(sol.func(mem2reg,cse)))' | FileCheck %s --implicit-check-not=sol.alloca

sol.contract @C {
  // Inline assembly reads a variable as its Yul word and writes it back, and
  // the body yields what it writes.
  // CHECK-LABEL: sol.func @assembly(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256
  // CHECK-NEXT:    %[[R:.*]] = sol.inline_asm -> ui256 {
  // CHECK-NEXT:      %[[ONE:.*]] = yul.constant 1
  // CHECK-NEXT:      %[[W:.*]] = sol.yul_val_cast %[[X]] : ui256 -> i256
  // CHECK-NEXT:      %[[SUM:.*]] = yul.add %[[W]], %[[ONE]]
  // CHECK-NEXT:      %[[V:.*]] = sol.yul_val_cast %[[SUM]] : i256 -> ui256
  // CHECK-NEXT:      sol.yield %[[V]] : ui256
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[R]] : ui256
  sol.func @assembly(%x: ui256) -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    sol.inline_asm {
      %c1 = yul.constant 1
      %1 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
      %2 = yul.load %1 : !yul.ptr -> i256
      %3 = yul.add %2, %c1
      yul.store %3, %1 : i256, !yul.ptr
    }
    %4 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %4 : ui256
  }

  // A variable inline assembly only reads leaves no result.
  // CHECK-LABEL: sol.func @assemblyRead(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256
  // CHECK-NEXT:    sol.inline_asm {
  // CHECK-NEXT:      %[[W:.*]] = sol.yul_val_cast %[[X]] : ui256 -> i256
  // CHECK-NEXT:      yul.mstore %[[W]], %[[W]]
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[X]] : ui256
  sol.func @assemblyRead(%x: ui256) -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    sol.inline_asm {
      %1 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
      %2 = yul.load %1 : !yul.ptr -> i256
      yul.mstore %2, %2
    }
    %3 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %3 : ui256
  }

  // A variable assigned in a Yul if crosses it as its Yul word.
  // CHECK-LABEL: sol.func @assemblyIf(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256
  // CHECK-NEXT:    %[[R:.*]] = sol.inline_asm -> ui256 {
  // CHECK-NEXT:      %[[B:.*]] = sol.yul_val_cast %[[Y]] : ui256 -> i256
  // CHECK-NEXT:      %[[XW:.*]] = sol.yul_val_cast %[[X]] : ui256 -> i256
  // CHECK-NEXT:      %[[IF:.*]] = yul.if %[[B]] -> i256 {
  // CHECK-NEXT:        %[[BV:.*]] = sol.yul_val_cast %[[B]] : i256 -> ui256
  // CHECK-NEXT:        %[[BW:.*]] = sol.yul_val_cast %[[BV]] : ui256 -> i256
  // CHECK-NEXT:        yul.yield %[[BW]] : i256
  // CHECK-NEXT:      } else {
  // CHECK-NEXT:        yul.yield %[[XW]] : i256
  // CHECK-NEXT:      }
  // CHECK-NEXT:      %[[V:.*]] = sol.yul_val_cast %[[IF]] : i256 -> ui256
  // CHECK-NEXT:      sol.yield %[[V]] : ui256
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[R]] : ui256
  sol.func @assemblyIf(%x: ui256, %y: ui256) -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    sol.inline_asm {
      %b = sol.yul_val_cast %y : ui256 -> i256
      yul.if %b {
        %1 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
        yul.store %b, %1 : i256, !yul.ptr
        yul.yield
      } else {
      }
    }
    %2 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %2 : ui256
  }

  // A variable assigned in a Yul loop is carried from one iteration to the
  // next as its Yul word.
  // CHECK-LABEL: sol.func @assemblyLoop(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256
  // CHECK-NEXT:    %[[R:.*]] = sol.inline_asm -> ui256 {
  // CHECK-NEXT:      %[[B:.*]] = sol.yul_val_cast %[[Y]] : ui256 -> i256
  // CHECK-NEXT:      %[[XW:.*]] = sol.yul_val_cast %[[X]] : ui256 -> i256
  // CHECK-NEXT:      %[[FOR:.*]] = yul.for %[[XW]] : i256 -> i256 cond {
  // CHECK-NEXT:      ^bb0(%[[I:.*]]: i256):
  // CHECK-NEXT:        yul.condition %[[B]], %[[I]] : i256
  // CHECK-NEXT:      } body {
  // CHECK-NEXT:      ^bb0(%[[J:.*]]: i256):
  // CHECK-NEXT:        %[[JV:.*]] = sol.yul_val_cast %[[J]] : i256 -> ui256
  // CHECK-NEXT:        %[[JW:.*]] = sol.yul_val_cast %[[JV]] : ui256 -> i256
  // CHECK-NEXT:        %[[SUM:.*]] = yul.add %[[JW]], %[[B]]
  // CHECK-NEXT:        %[[SV:.*]] = sol.yul_val_cast %[[SUM]] : i256 -> ui256
  // CHECK-NEXT:        %[[SW:.*]] = sol.yul_val_cast %[[SV]] : ui256 -> i256
  // CHECK-NEXT:        yul.yield %[[SW]] : i256
  // CHECK-NEXT:      } step {
  // CHECK-NEXT:      ^bb0(%[[S:.*]]: i256):
  // CHECK-NEXT:        yul.yield %[[S]] : i256
  // CHECK-NEXT:      }
  // CHECK-NEXT:      %[[V:.*]] = sol.yul_val_cast %[[FOR]] : i256 -> ui256
  // CHECK-NEXT:      sol.yield %[[V]] : ui256
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[R]] : ui256
  sol.func @assemblyLoop(%x: ui256, %y: ui256) -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    sol.inline_asm {
      %b = sol.yul_val_cast %y : ui256 -> i256
      yul.for cond {
        yul.condition %b
      } body {
        %1 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
        %2 = yul.load %1 : !yul.ptr -> i256
        %3 = yul.add %2, %b
        yul.store %3, %1 : i256, !yul.ptr
        yul.yield
      } step {
        yul.yield
      }
    }
    %4 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %4 : ui256
  }

  // A storage reference's slot is the whole reference.
  // CHECK-LABEL: sol.func @slot(
  // CHECK-SAME:    %[[P:[^:]*]]: !sol.array<? x ui256, Storage>, %[[Q:[^:]*]]: !sol.array<? x ui256, Storage>
  // CHECK-NEXT:    %[[R:.*]] = sol.inline_asm -> !sol.array<? x ui256, Storage> {
  // CHECK-NEXT:      %[[W:.*]] = sol.yul_val_cast %[[Q]] : !sol.array<? x ui256, Storage> -> i256
  // CHECK-NEXT:      %[[V:.*]] = sol.yul_val_cast %[[W]] : i256 -> !sol.array<? x ui256, Storage>
  // CHECK-NEXT:      sol.yield %[[V]] : !sol.array<? x ui256, Storage>
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[R]] : !sol.array<? x ui256, Storage>
  sol.func @slot(%p: !sol.array<? x ui256, Storage>, %q: !sol.array<? x ui256, Storage>) -> !sol.array<? x ui256, Storage> {
    %0 = sol.alloca : !sol.ptr<!sol.array<? x ui256, Storage>, Stack>
    sol.store %p, %0 : !sol.array<? x ui256, Storage>, !sol.ptr<!sol.array<? x ui256, Storage>, Stack>
    sol.inline_asm {
      %w = sol.yul_val_cast %q : !sol.array<? x ui256, Storage> -> i256
      %1 = sol.yul_storage_slot %0 : !sol.ptr<!sol.array<? x ui256, Storage>, Stack> -> !yul.ptr
      yul.store %w, %1 : i256, !yul.ptr
    }
    %2 = sol.load %0 : !sol.ptr<!sol.array<? x ui256, Storage>, Stack>, !sol.array<? x ui256, Storage>
    sol.return %2 : !sol.array<? x ui256, Storage>
  }

  // A body that halts yields nothing.
  // CHECK-LABEL: sol.func @halt(
  // CHECK-NEXT:    %[[R:.*]] = sol.inline_asm -> ui256 {
  // CHECK-NEXT:      %[[ZERO:.*]] = yul.constant 0
  // CHECK-NEXT:      yul.revert %[[ZERO]], %[[ZERO]]
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[R]] : ui256
  sol.func @halt(%x: ui256) -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.store %x, %0 : ui256, !sol.ptr<ui256, Stack>
    sol.inline_asm {
      %c0 = yul.constant 0
      %1 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
      yul.store %c0, %1 : i256, !yul.ptr
      yul.revert %c0, %c0
    }
    %2 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %2 : ui256
  }

  // Inline assembly reads and writes one word of a calldata reference's
  // {offset, length}.
  // CHECK-LABEL: sol.func @calldataFields(
  // CHECK-SAME:    %[[S:[^:]*]]: !sol.string<CallData>, %[[N:[^:]*]]: ui256
  // CHECK-NEXT:    %[[R:.*]] = sol.inline_asm -> !sol.string<CallData> {
  // CHECK-NEXT:      %[[NW:.*]] = sol.yul_val_cast %[[N]] : ui256 -> i256
  // CHECK-NEXT:      %[[W:.*]]:2 = sol.yul_val_cast %[[S]] : !sol.string<CallData> -> i256, i256
  // CHECK-NEXT:      yul.mstore %[[W]]#0, %[[W]]#0
  // CHECK-NEXT:      %[[V:.*]] = sol.yul_val_cast %[[W]]#0, %[[NW]] : i256, i256 -> !sol.string<CallData>
  // CHECK-NEXT:      sol.yield %[[V]] : !sol.string<CallData>
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[R]] : !sol.string<CallData>
  sol.func @calldataFields(%s: !sol.string<CallData>, %n: ui256) -> !sol.string<CallData> {
    %0 = sol.alloca : !sol.ptr<!sol.string<CallData>, Stack>
    sol.store %s, %0 : !sol.string<CallData>, !sol.ptr<!sol.string<CallData>, Stack>
    sol.inline_asm {
      %w = sol.yul_val_cast %n : ui256 -> i256
      %1 = sol.yul_calldata_offset %0 : !sol.ptr<!sol.string<CallData>, Stack> -> !yul.ptr
      %2 = yul.load %1 : !yul.ptr -> i256
      yul.mstore %2, %2
      %3 = sol.yul_calldata_length %0 : !sol.ptr<!sol.string<CallData>, Stack> -> !yul.ptr
      yul.store %w, %3 : i256, !yul.ptr
    }
    %4 = sol.load %0 : !sol.ptr<!sol.string<CallData>, Stack>, !sol.string<CallData>
    sol.return %4 : !sol.string<CallData>
  }

  // An external function reference whose selector is assigned in a Yul if
  // crosses it as its {address, selector} words.
  // CHECK-LABEL: sol.func @selectorInIf(
  // CHECK-SAME:    %[[F:[^:]*]]: !sol.ext_func_ref<() -> ()>, %[[C:[^:]*]]: ui256
  // CHECK-NEXT:    %[[R:.*]] = sol.inline_asm -> !sol.ext_func_ref<() -> ()> {
  // CHECK-NEXT:      %[[B:.*]] = sol.yul_val_cast %[[C]] : ui256 -> i256
  // CHECK-NEXT:      %[[W:.*]]:2 = sol.yul_val_cast %[[F]] : !sol.ext_func_ref<() -> ()> -> i256, i256
  // CHECK-NEXT:      %[[IF:.*]]:2 = yul.if %[[B]] -> i256, i256 {
  // CHECK-NEXT:        %[[G:.*]] = sol.yul_val_cast %[[W]]#0, %[[B]] : i256, i256 -> !sol.ext_func_ref<() -> ()>
  // CHECK-NEXT:        %[[GW:.*]]:2 = sol.yul_val_cast %[[G]] : !sol.ext_func_ref<() -> ()> -> i256, i256
  // CHECK-NEXT:        yul.yield %[[GW]]#0, %[[GW]]#1 : i256, i256
  // CHECK-NEXT:      } else {
  // CHECK-NEXT:        yul.yield %[[W]]#0, %[[W]]#1 : i256, i256
  // CHECK-NEXT:      }
  // CHECK-NEXT:      %[[V:.*]] = sol.yul_val_cast %[[IF]]#0, %[[IF]]#1 : i256, i256 -> !sol.ext_func_ref<() -> ()>
  // CHECK-NEXT:      %[[VW:.*]]:2 = sol.yul_val_cast %[[V]] : !sol.ext_func_ref<() -> ()> -> i256, i256
  // CHECK-NEXT:      yul.mstore %[[VW]]#0, %[[VW]]#0
  // CHECK-NEXT:      sol.yield %[[V]] : !sol.ext_func_ref<() -> ()>
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[R]] : !sol.ext_func_ref<() -> ()>
  sol.func @selectorInIf(%f: !sol.ext_func_ref<() -> ()>, %c: ui256) -> !sol.ext_func_ref<() -> ()> {
    %0 = sol.alloca : !sol.ptr<!sol.ext_func_ref<() -> ()>, Stack>
    sol.store %f, %0 : !sol.ext_func_ref<() -> ()>, !sol.ptr<!sol.ext_func_ref<() -> ()>, Stack>
    sol.inline_asm {
      %b = sol.yul_val_cast %c : ui256 -> i256
      yul.if %b {
        %1 = sol.yul_selector %0 : !sol.ptr<!sol.ext_func_ref<() -> ()>, Stack> -> !yul.ptr
        yul.store %b, %1 : i256, !yul.ptr
        yul.yield
      } else {
      }
      %2 = sol.yul_address_of %0 : !sol.ptr<!sol.ext_func_ref<() -> ()>, Stack> -> !yul.ptr
      %3 = yul.load %2 : !yul.ptr -> i256
      yul.mstore %3, %3
    }
    %4 = sol.load %0 : !sol.ptr<!sol.ext_func_ref<() -> ()>, Stack>, !sol.ext_func_ref<() -> ()>
    sol.return %4 : !sol.ext_func_ref<() -> ()>
  }

  // A calldata reference whose length is assigned in a Yul loop carries both
  // its words from one iteration to the next.
  // CHECK-LABEL: sol.func @lengthInLoop(
  // CHECK-SAME:    %[[S:[^:]*]]: !sol.string<CallData>, %[[C:[^:]*]]: ui256
  // CHECK-NEXT:    %[[R:.*]] = sol.inline_asm -> !sol.string<CallData> {
  // CHECK-NEXT:      %[[B:.*]] = sol.yul_val_cast %[[C]] : ui256 -> i256
  // CHECK-NEXT:      %[[W:.*]]:2 = sol.yul_val_cast %[[S]] : !sol.string<CallData> -> i256, i256
  // CHECK-NEXT:      %[[FOR:.*]]:2 = yul.for %[[W]]#0, %[[W]]#1 : i256, i256 -> i256, i256 cond {
  // CHECK-NEXT:      ^bb0(%[[O:.*]]: i256, %[[L:.*]]: i256):
  // CHECK-NEXT:        yul.condition %[[B]], %[[O]], %[[L]] : i256, i256
  // CHECK-NEXT:      } body {
  // CHECK-NEXT:      ^bb0(%[[BO:.*]]: i256, %[[BL:.*]]: i256):
  // CHECK-NEXT:        %[[BV:.*]] = sol.yul_val_cast %[[BO]], %[[BL]] : i256, i256 -> !sol.string<CallData>
  // CHECK-NEXT:        %[[BW:.*]]:2 = sol.yul_val_cast %[[BV]] : !sol.string<CallData> -> i256, i256
  // CHECK-NEXT:        %[[SUM:.*]] = yul.add %[[BW]]#1, %[[B]]
  // CHECK-NEXT:        %[[NV:.*]] = sol.yul_val_cast %[[BW]]#0, %[[SUM]] : i256, i256 -> !sol.string<CallData>
  // CHECK-NEXT:        %[[NW:.*]]:2 = sol.yul_val_cast %[[NV]] : !sol.string<CallData> -> i256, i256
  // CHECK-NEXT:        yul.yield %[[NW]]#0, %[[NW]]#1 : i256, i256
  // CHECK-NEXT:      } step {
  // CHECK-NEXT:      ^bb0(%[[SO:.*]]: i256, %[[SL:.*]]: i256):
  // CHECK-NEXT:        yul.yield %[[SO]], %[[SL]] : i256, i256
  // CHECK-NEXT:      }
  // CHECK-NEXT:      %[[V:.*]] = sol.yul_val_cast %[[FOR]]#0, %[[FOR]]#1 : i256, i256 -> !sol.string<CallData>
  // CHECK-NEXT:      sol.yield %[[V]] : !sol.string<CallData>
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[R]] : !sol.string<CallData>
  sol.func @lengthInLoop(%s: !sol.string<CallData>, %c: ui256) -> !sol.string<CallData> {
    %0 = sol.alloca : !sol.ptr<!sol.string<CallData>, Stack>
    sol.store %s, %0 : !sol.string<CallData>, !sol.ptr<!sol.string<CallData>, Stack>
    sol.inline_asm {
      %b = sol.yul_val_cast %c : ui256 -> i256
      yul.for cond {
        yul.condition %b
      } body {
        %1 = sol.yul_calldata_length %0 : !sol.ptr<!sol.string<CallData>, Stack> -> !yul.ptr
        %2 = yul.load %1 : !yul.ptr -> i256
        %3 = yul.add %2, %b
        yul.store %3, %1 : i256, !yul.ptr
        yul.yield
      } step {
        yul.yield
      }
    }
    %4 = sol.load %0 : !sol.ptr<!sol.string<CallData>, Stack>, !sol.string<CallData>
    sol.return %4 : !sol.string<CallData>
  }

  // A storage reference's offset is 0, whatever the variable holds.
  // CHECK-LABEL: sol.func @storageOffset(
  // CHECK-SAME:    %[[P:[^:]*]]: !sol.array<? x ui256, Storage>
  // CHECK-NEXT:    sol.inline_asm {
  // CHECK-NEXT:      %[[ZERO:.*]] = yul.constant 0
  // CHECK-NEXT:      yul.mstore %[[ZERO]], %[[ZERO]]
  // CHECK-NEXT:    }
  // CHECK-NEXT:    sol.return %[[P]] : !sol.array<? x ui256, Storage>
  sol.func @storageOffset(%p: !sol.array<? x ui256, Storage>) -> !sol.array<? x ui256, Storage> {
    %0 = sol.alloca : !sol.ptr<!sol.array<? x ui256, Storage>, Stack>
    sol.store %p, %0 : !sol.array<? x ui256, Storage>, !sol.ptr<!sol.array<? x ui256, Storage>, Stack>
    sol.inline_asm {
      %1 = sol.yul_storage_offset %0 : !sol.ptr<!sol.array<? x ui256, Storage>, Stack>
      yul.mstore %1, %1
    }
    %2 = sol.load %0 : !sol.ptr<!sol.array<? x ui256, Storage>, Stack>, !sol.array<? x ui256, Storage>
    sol.return %2 : !sol.array<? x ui256, Storage>
  }
} {kind = #sol<ContractKind Contract>, runtime}
