// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Inline assembly can retype an internal function pointer, so a call reaches
// every target that takes and returns as many words, whatever pointer type took
// the target. A calldata array is two words, so a case passes the call's words
// to its target in the target's grouping, and the results back in the call's.
// Calls whose pointer types lower to one signature share its dispatch function.

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         yul.func @f
// CHECK:           yul.func_call @[[ONE:__sol\.internal_dispatch\.[0-9]+]](
// CHECK:           yul.func_call @[[WORDS:__sol\.internal_dispatch\.[0-9]+]](
// CHECK:           yul.func_call @[[SLICES:__sol\.internal_dispatch\.[0-9]+]](
// CHECK:           yul.func_call @[[ONE]](
// CHECK:         yul.func @[[SLICES]] : (i256, !llvm.struct<(i256, i256)>) -> !llvm.struct<(i256, i256)>
// CHECK-NEXT:    ^bb0(%{{.*}}: i256, %[[SLICE:.*]]: !llvm.struct<(i256, i256)>):
// CHECK:           case 9 {
// CHECK-NEXT:        %[[OFFSET:.*]] = llvm.extractvalue %[[SLICE]][0]
// CHECK-NEXT:        %[[LENGTH:.*]] = llvm.extractvalue %[[SLICE]][1]
// CHECK-NEXT:        %[[PAIR:.*]]:2 = yul.func_call @pair(%[[OFFSET]], %[[LENGTH]])
// CHECK-NEXT:        %[[UNDEF:.*]] = llvm.mlir.undef : !llvm.struct<(i256, i256)>
// CHECK-NEXT:        %[[PARTIAL:.*]] = llvm.insertvalue %[[PAIR]]#0, %[[UNDEF]][0]
// CHECK-NEXT:        %[[FULL:.*]] = llvm.insertvalue %[[PAIR]]#1, %[[PARTIAL]][1]
// CHECK-NEXT:        yul.yield %[[FULL]]
// CHECK:           case 8 {
// CHECK-NEXT:        %[[RESULT:.*]] = yul.func_call @slice(%[[SLICE]])
// CHECK-NEXT:        yul.yield %[[RESULT]]
// CHECK:         yul.func @[[WORDS]] : (i256, i256, i256) -> (i256, i256)
// CHECK-NEXT:    ^bb0(%{{.*}}: i256, %[[FIRST:.*]]: i256, %[[SECOND:.*]]: i256):
// CHECK:           case 9 {
// CHECK-NEXT:        %[[PAIR:.*]]:2 = yul.func_call @pair(%[[FIRST]], %[[SECOND]])
// CHECK-NEXT:        yul.yield %[[PAIR]]#0, %[[PAIR]]#1
// CHECK:           case 8 {
// CHECK-NEXT:        %[[UNDEF:.*]] = llvm.mlir.undef : !llvm.struct<(i256, i256)>
// CHECK-NEXT:        %[[PARTIAL:.*]] = llvm.insertvalue %[[FIRST]], %[[UNDEF]][0]
// CHECK-NEXT:        %[[FULL:.*]] = llvm.insertvalue %[[SECOND]], %[[PARTIAL]][1]
// CHECK-NEXT:        %[[RESULT:.*]] = yul.func_call @slice(%[[FULL]])
// CHECK-NEXT:        %[[OFFSET:.*]] = llvm.extractvalue %[[RESULT]][0]
// CHECK-NEXT:        %[[LENGTH:.*]] = llvm.extractvalue %[[RESULT]][1]
// CHECK-NEXT:        yul.yield %[[OFFSET]], %[[LENGTH]]
// CHECK:         yul.func @[[ONE]] : (i256, i256) -> ()
// CHECK-NEXT:    ^bb0(%[[POINTER:.*]]: i256, %[[WORD:.*]]: i256):
// CHECK-NEXT:      yul.switch %[[POINTER]] : i256
// CHECK-NEXT:      case 7 {
// CHECK-NEXT:        yul.func_call @lt(%[[WORD]])
// CHECK-NEXT:        yul.yield
// CHECK-NEXT:      }
// CHECK-NEXT:      default {

module {
  sol.contract @C {
    sol.func @lt(%arg0: !sol.address) attributes {id = 7 : i64, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @slice(%arg0: !sol.array<? x ui256, CallData>) -> !sol.array<? x ui256, CallData> attributes {id = 8 : i64, state_mutability = #NonPayable} {
      sol.return %arg0 : !sol.array<? x ui256, CallData>
    }
    sol.func @pair(%arg0: ui256, %arg1: ui256) -> (ui256, ui256) attributes {id = 9 : i64, state_mutability = #NonPayable} {
      sol.return %arg0, %arg1 : ui256, ui256
    }
    sol.func @q(%arg0: ui256) -> ui256 attributes {id = 10 : i64, state_mutability = #NonPayable} {
      sol.return %arg0 : ui256
    }
    sol.func @f(%arg0: !sol.array<? x ui256, CallData>, %arg1: !sol.address) attributes {state_mutability = #NonPayable} {
      %0 = sol.func_constant @slice : !sol.func_ref<(!sol.array<? x ui256, CallData>) -> !sol.array<? x ui256, CallData>>
      %1 = sol.func_constant @pair : !sol.func_ref<(ui256, ui256) -> (ui256, ui256)>
      %2 = sol.default_func_constant : !sol.func_ref<(ui256) -> ()>
      %3 = sol.constant 1 : ui256
      sol.icall %2(%3) : !sol.func_ref<(ui256) -> ()>, (ui256) -> ()
      %4:2 = sol.icall %1(%3, %3) : !sol.func_ref<(ui256, ui256) -> (ui256, ui256)>, (ui256, ui256) -> (ui256, ui256)
      %5 = sol.icall %0(%arg0) : !sol.func_ref<(!sol.array<? x ui256, CallData>) -> !sol.array<? x ui256, CallData>>, (!sol.array<? x ui256, CallData>) -> !sol.array<? x ui256, CallData>
      %6 = sol.default_func_constant : !sol.func_ref<(!sol.address) -> ()>
      sol.icall %6(%arg1) : !sol.func_ref<(!sol.address) -> ()>, (!sol.address) -> ()
      %7 = sol.func_constant @q : !sol.func_ref<(ui256) -> ui256>
      sol.return
    }
  } {creation_func_refs = [@lt], kind = #Contract, runtime}
}
