// RUN: mlir-opt %s --pass-pipeline='builtin.module(sol.contract(sol.func(mem2reg)))' | FileCheck %s --implicit-check-not=yul.alloca

sol.contract @C {
  // Each load of a variable reads the store before it.
  // CHECK-LABEL: sol.func @reassigned(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256
  // CHECK-NEXT:    sol.inline_asm {
  // CHECK-NEXT:      %[[A:.*]] = sol.yul_val_cast %[[X]] : ui256 -> i256
  // CHECK-NEXT:      %[[B:.*]] = sol.yul_val_cast %[[Y]] : ui256 -> i256
  // CHECK-NEXT:      yul.mstore %[[A]], %[[A]]
  // CHECK-NEXT:      yul.mstore %[[B]], %[[B]]
  // CHECK-NEXT:    }
  sol.func @reassigned(%x: ui256, %y: ui256) {
    sol.inline_asm {
      %a = sol.yul_val_cast %x : ui256 -> i256
      %b = sol.yul_val_cast %y : ui256 -> i256
      %0 = yul.alloca : !yul.ptr
      yul.store %a, %0 : i256, !yul.ptr
      %1 = yul.load %0 : !yul.ptr -> i256
      yul.mstore %1, %1
      yul.store %b, %0 : i256, !yul.ptr
      %2 = yul.load %0 : !yul.ptr -> i256
      yul.mstore %2, %2
    }
    sol.return
  }

  // A variable assigned in an if leaves it as its result, and the else the if
  // gets yields the value before it.
  // CHECK-LABEL: sol.func @ifAssigned(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256
  // CHECK-NEXT:    sol.inline_asm {
  // CHECK-NEXT:      %[[A:.*]] = sol.yul_val_cast %[[X]] : ui256 -> i256
  // CHECK-NEXT:      %[[B:.*]] = sol.yul_val_cast %[[Y]] : ui256 -> i256
  // CHECK-NEXT:      %[[R:.*]] = yul.if %[[B]] -> i256 {
  // CHECK-NEXT:        yul.yield %[[B]] : i256
  // CHECK-NEXT:      } else {
  // CHECK-NEXT:        yul.yield %[[A]] : i256
  // CHECK-NEXT:      }
  // CHECK-NEXT:      yul.mstore %[[R]], %[[R]]
  // CHECK-NEXT:    }
  sol.func @ifAssigned(%x: ui256, %y: ui256) {
    sol.inline_asm {
      %a = sol.yul_val_cast %x : ui256 -> i256
      %b = sol.yul_val_cast %y : ui256 -> i256
      %0 = yul.alloca : !yul.ptr
      yul.store %a, %0 : i256, !yul.ptr
      yul.if %b {
        yul.store %b, %0 : i256, !yul.ptr
        yul.yield
      } else {
      }
      %1 = yul.load %0 : !yul.ptr -> i256
      yul.mstore %1, %1
    }
    sol.return
  }

  // A variable assigned in a case of a switch leaves it as its result.
  // CHECK-LABEL: sol.func @switchAssigned(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256
  // CHECK-NEXT:    sol.inline_asm {
  // CHECK-NEXT:      %[[A:.*]] = sol.yul_val_cast %[[X]] : ui256 -> i256
  // CHECK-NEXT:      %[[B:.*]] = sol.yul_val_cast %[[Y]] : ui256 -> i256
  // CHECK-NEXT:      %[[R:.*]] = yul.switch %[[B]] : i256 -> i256
  // CHECK-NEXT:      case 1 {
  // CHECK-NEXT:        yul.yield %[[B]] : i256
  // CHECK-NEXT:      }
  // CHECK-NEXT:      default {
  // CHECK-NEXT:        yul.yield %[[A]] : i256
  // CHECK-NEXT:      }
  // CHECK-NEXT:      yul.mstore %[[R]], %[[R]]
  // CHECK-NEXT:    }
  sol.func @switchAssigned(%x: ui256, %y: ui256) {
    sol.inline_asm {
      %a = sol.yul_val_cast %x : ui256 -> i256
      %b = sol.yul_val_cast %y : ui256 -> i256
      %0 = yul.alloca : !yul.ptr
      yul.store %a, %0 : i256, !yul.ptr
      yul.switch %b : i256
      case 1 {
        yul.store %b, %0 : i256, !yul.ptr
        yul.yield
      }
      default {
        yul.yield
      }
      %1 = yul.load %0 : !yul.ptr -> i256
      yul.mstore %1, %1
    }
    sol.return
  }

  // A variable assigned in a loop is carried from one iteration to the next,
  // and a break or continue carries the value there.
  // CHECK-LABEL: sol.func @loop(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256
  // CHECK-NEXT:    sol.inline_asm {
  // CHECK-NEXT:      %[[A:.*]] = sol.yul_val_cast %[[X]] : ui256 -> i256
  // CHECK-NEXT:      %[[B:.*]] = sol.yul_val_cast %[[Y]] : ui256 -> i256
  // CHECK-NEXT:      %[[R:.*]] = yul.for %[[A]] : i256 -> i256 cond {
  // CHECK-NEXT:      ^bb0(%[[I:.*]]: i256):
  // CHECK-NEXT:        yul.condition %[[B]], %[[I]] : i256
  // CHECK-NEXT:      } body {
  // CHECK-NEXT:      ^bb0(%[[J:.*]]: i256):
  // CHECK-NEXT:        yul.if %[[B]] {
  // CHECK-NEXT:          yul.break %[[J]] : i256
  // CHECK-NEXT:        } else {
  // CHECK-NEXT:        }
  // CHECK-NEXT:        %[[NEXT:.*]] = yul.add %[[J]], %[[B]]
  // CHECK-NEXT:        yul.if %[[A]] {
  // CHECK-NEXT:          yul.continue %[[NEXT]] : i256
  // CHECK-NEXT:        } else {
  // CHECK-NEXT:        }
  // CHECK-NEXT:        yul.yield %[[NEXT]] : i256
  // CHECK-NEXT:      } step {
  // CHECK-NEXT:      ^bb0(%[[S:.*]]: i256):
  // CHECK-NEXT:        %[[STEP:.*]] = yul.add %[[S]], %[[A]]
  // CHECK-NEXT:        yul.yield %[[STEP]] : i256
  // CHECK-NEXT:      }
  // CHECK-NEXT:      yul.mstore %[[R]], %[[R]]
  // CHECK-NEXT:    }
  sol.func @loop(%x: ui256, %y: ui256) {
    sol.inline_asm {
      %a = sol.yul_val_cast %x : ui256 -> i256
      %b = sol.yul_val_cast %y : ui256 -> i256
      %0 = yul.alloca : !yul.ptr
      yul.store %a, %0 : i256, !yul.ptr
      yul.for cond {
        yul.condition %b
      } body {
        yul.if %b {
          yul.break
        } else {
        }
        %1 = yul.load %0 : !yul.ptr -> i256
        %2 = yul.add %1, %b
        yul.store %2, %0 : i256, !yul.ptr
        yul.if %a {
          yul.continue
        } else {
        }
        yul.yield
      } step {
        %3 = yul.load %0 : !yul.ptr -> i256
        %4 = yul.add %3, %a
        yul.store %4, %0 : i256, !yul.ptr
        yul.yield
      }
      %5 = yul.load %0 : !yul.ptr -> i256
      yul.mstore %5, %5
    }
    sol.return
  }

  // A variable only read in a loop isn't carried.
  // CHECK-LABEL: sol.func @loadOnly(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256
  // CHECK-NEXT:    sol.inline_asm {
  // CHECK-NEXT:      %[[A:.*]] = sol.yul_val_cast %[[X]] : ui256 -> i256
  // CHECK-NEXT:      %[[B:.*]] = sol.yul_val_cast %[[Y]] : ui256 -> i256
  // CHECK-NEXT:      yul.for cond {
  // CHECK-NEXT:        yul.condition %[[B]]
  // CHECK-NEXT:      } body {
  // CHECK-NEXT:        yul.mstore %[[A]], %[[A]]
  // CHECK-NEXT:        yul.yield
  // CHECK-NEXT:      } step {
  // CHECK-NEXT:        yul.yield
  // CHECK-NEXT:      }
  // CHECK-NEXT:    }
  sol.func @loadOnly(%x: ui256, %y: ui256) {
    sol.inline_asm {
      %a = sol.yul_val_cast %x : ui256 -> i256
      %b = sol.yul_val_cast %y : ui256 -> i256
      %0 = yul.alloca : !yul.ptr
      yul.store %a, %0 : i256, !yul.ptr
      yul.for cond {
        yul.condition %b
      } body {
        %1 = yul.load %0 : !yul.ptr -> i256
        yul.mstore %1, %1
        yul.yield
      } step {
        yul.yield
      }
    }
    sol.return
  }

  // A variable of a function inline assembly defines is promoted in the
  // function.
  // CHECK-LABEL: sol.func @function(
  // CHECK-NEXT:    sol.inline_asm {
  // CHECK-NEXT:      yul.func @double : (i256) -> i256 {
  // CHECK-NEXT:      ^bb0(%[[N:.*]]: i256):
  // CHECK-NEXT:        %[[D:.*]] = yul.add %[[N]], %[[N]]
  // CHECK-NEXT:        yul.func_return %[[D]] : i256
  // CHECK-NEXT:      }
  // CHECK-NEXT:    }
  sol.func @function() {
    sol.inline_asm {
      yul.func @double : (i256) -> i256 {
      ^bb0(%n: i256):
        %0 = yul.alloca : !yul.ptr
        yul.store %n, %0 : i256, !yul.ptr
        %1 = yul.load %0 : !yul.ptr -> i256
        %2 = yul.add %1, %1
        yul.func_return %2 : i256
      }
    }
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}
