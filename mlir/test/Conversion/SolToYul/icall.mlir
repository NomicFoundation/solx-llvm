// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Nothing in L takes a function's address, so its icall has no dispatch
// targets and lowers to the invalid-function panic (0x51).
// CHECK-LABEL: yul.object @L {
// CHECK-LABEL: yul.object @L_deployed {
// CHECK-LABEL: yul.func @exec : (i256) -> ()
// CHECK-NOT:     yul.func_call
// CHECK:         %[[C81:.*]] = yul.constant 81
// CHECK:         yul.mstore %{{.*}}, %[[C81]]
// CHECK:         yul.revert

// An internal function pointer is the callee's id, called through a
// per-object dispatch switch. The creation object's switch only has the
// targets reachable from the constructor; the runtime one also has those
// whose address only the constructor takes.
// CHECK-LABEL: yul.object @C {
// CHECK:         yul.func_call @C() : () -> ()
// CHECK-LABEL:   yul.func @C : () -> ()
// CHECK:           %[[ID:.*]] = yul.constant 24{{$}}
// CHECK:           %[[ARG:.*]] = yul.constant 21{{$}}
// CHECK:           yul.func_call @__sol.internal_dispatch.cr.12.24(%[[ID]], %[[ARG]]) : (i256, i256) -> i256
// CHECK-LABEL:   yul.func @__sol.internal_dispatch.cr.12.24 : (i256, i256) -> i256
// CHECK:           ^bb0(%[[FN:.*]]: i256, %[[X:.*]]: i256):
// CHECK:           yul.switch %[[FN]] : i256 -> i256
// CHECK-NEXT:      case 24 {
// CHECK-NEXT:        %[[D:.*]] = yul.func_call @dec(%[[X]]) : (i256) -> i256
// CHECK-NEXT:        yul.yield %[[D]] : i256
// CHECK-NEXT:      }
// CHECK-NEXT:      default {
// CHECK:             %[[PANIC:.*]] = yul.constant 81{{$}}
// CHECK:             yul.mstore %{{.*}}, %[[PANIC]]
// CHECK:             yul.revert

// CHECK-LABEL:   yul.object @C_deployed {
// CHECK-LABEL:     yul.func @f : () -> ()
// CHECK:             %[[INC:.*]] = yul.constant 12{{$}}
// CHECK:             yul.func_call @exec(%[[INC]], %{{.*}}) : (i256, i256) -> i256
// CHECK-LABEL:     yul.func @exec : (i256, i256) -> i256
// CHECK-NEXT:      ^bb0(%[[FP:.*]]: i256, %[[Y:.*]]: i256):
// CHECK:             yul.func_call @__sol.internal_dispatch.rt.12.24(%[[FP]], %[[Y]]) : (i256, i256) -> i256
// CHECK-LABEL:     yul.func @__sol.internal_dispatch.rt.12.24 : (i256, i256) -> i256
// CHECK:             yul.switch %{{.*}} : i256 -> i256
// CHECK-NEXT:        case 12 {
// CHECK-NEXT:          yul.func_call @inc
// CHECK:             case 24 {
// CHECK-NEXT:          yul.func_call @dec
// CHECK:             default {
// CHECK:               yul.constant 81
// CHECK-LABEL:     yul.func @inc : (i256) -> i256
// CHECK-LABEL:     yul.func @dec : (i256) -> i256
// CHECK-LABEL:   yul.func @dec : (i256) -> i256

// icalls with the same candidate set share one dispatch helper.
// CHECK-LABEL: yul.object @R_deployed {
// CHECK-LABEL:   yul.func @b : (i256, i256) -> i256
// CHECK-NEXT:    ^bb0(%[[F:.*]]: i256, %[[X:.*]]: i256):
// CHECK-NEXT:      yul.func_call @__sol.internal_dispatch.rt.12(%[[F]], %[[X]]) : (i256, i256) -> i256
// CHECK-LABEL:   yul.func @a : (i256) -> i256
// CHECK-NEXT:    ^bb0(%[[Y:.*]]: i256):
// CHECK-NEXT:      %[[ID:.*]] = yul.constant 12
// CHECK-NEXT:      yul.func_call @__sol.internal_dispatch.rt.12(%[[ID]], %[[Y]]) : (i256, i256) -> i256
// CHECK-LABEL:   yul.func @__sol.internal_dispatch.rt.12 : (i256, i256) -> i256
// CHECK-NOT:     yul.func @__sol.internal_dispatch
// CHECK-LABEL:   yul.func @inc : (i256) -> i256

#Default = #sol<RevertStrings Default>
#Library = #sol<ContractKind Library>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @L {
    sol.func @exec(%f: !sol.func_ref<() -> ()>) {
      sol.icall %f() : !sol.func_ref<() -> ()>, () -> ()
      sol.return
    }
  } {kind = #Library}
}

// -----
#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @C() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      %0 = sol.func_constant @dec : !sol.func_ref<(ui256) -> ui256>
      %c21 = sol.constant 21 : ui256
      %1 = sol.icall %0(%c21) : !sol.func_ref<(ui256) -> ui256>, (ui256) -> ui256
      sol.return
    }
    sol.func @inc(%x: ui256) -> ui256 attributes {id = 12 : i64} {
      sol.return %x : ui256
    }
    sol.func @dec(%x: ui256) -> ui256 attributes {id = 24 : i64} {
      sol.return %x : ui256
    }
    sol.func @exec(%f: !sol.func_ref<(ui256) -> ui256>, %x: ui256) -> ui256 {
      %0 = sol.icall %f(%x) : !sol.func_ref<(ui256) -> ui256>, (ui256) -> ui256
      sol.return %0 : ui256
    }
    sol.func @f() {
      %0 = sol.func_constant @inc : !sol.func_ref<(ui256) -> ui256>
      %c1 = sol.constant 1 : ui256
      %1 = sol.call @exec(%0, %c1) : (!sol.func_ref<(ui256) -> ui256>, ui256) -> ui256
      sol.return
    }
  } {kind = #Contract}
}

// -----
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @R {
    sol.func @inc(%x: ui256) -> ui256 attributes {id = 12 : i64} {
      sol.return %x : ui256
    }
    sol.func @a(%x: ui256) -> ui256 {
      %f = sol.func_constant @inc : !sol.func_ref<(ui256) -> ui256>
      %0 = sol.icall %f(%x) : !sol.func_ref<(ui256) -> ui256>, (ui256) -> ui256
      sol.return %0 : ui256
    }
    sol.func @b(%f: !sol.func_ref<(ui256) -> ui256>, %x: ui256) -> ui256 {
      %0 = sol.icall %f(%x) : !sol.func_ref<(ui256) -> ui256>, (ui256) -> ui256
      sol.return %0 : ui256
    }
  } {kind = #Contract}
}
