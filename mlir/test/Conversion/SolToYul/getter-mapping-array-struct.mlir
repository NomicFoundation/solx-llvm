// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The array index with the getter's bounds revert is outlined; the helper
// takes the array's slot and the index and returns the element's slot.
// CHECK-LABEL:   yul.func @__sol.index_storage_array.array$_dyn_struct$_$_ui256_$_ui256_$_$_Storage_$_$_Storage_$.nopanic : (i256, i256) -> i256
// CHECK-NEXT:    ^bb0(%[[ARR:.*]]: i256, %[[IDX:.*]]: i256):
// CHECK:           %[[LEN:.*]] = yul.sload %[[ARR]]
// CHECK:           %[[OOB:.*]] = yul.cmp uge, %[[IDX]], %[[LEN]]
// CHECK:           yul.if %[[OOB]] {
// CHECK-NEXT:        %[[Z:.*]] = yul.constant 0
// CHECK-NEXT:        yul.revert %[[Z]], %[[Z]]
// CHECK:           yul.mstore %{{.*}}, %[[ARR]]
// CHECK:           %[[DATA:.*]] = yul.keccak256
// CHECK:           %[[C2:.*]] = yul.constant 2
// CHECK:           %[[OFF:.*]] = yul.mul %[[IDX]], %[[C2]]
// CHECK:           %[[S:.*]] = yul.add %[[DATA]], %[[OFF]]
// CHECK:           yul.func_return %[[S]] : i256

// CHECK-LABEL:   yul.func @get_m : (i256, i256) -> (i256, i256)
// CHECK:           %[[SLOT:.*]] = yul.constant 0
// CHECK:           yul.mstore %{{.*}}, %arg0
// CHECK:           yul.mstore %{{.*}}, %[[SLOT]]
// CHECK:           %[[ARR:.*]] = yul.keccak256
// CHECK:           %[[S:.*]] = yul.func_call @__sol.index_storage_array.array$_dyn_struct$_$_ui256_$_ui256_$_$_Storage_$_$_Storage_$.nopanic(%[[ARR]], %arg1)
// CHECK:           yul.add %[[S]], %{{.*}}
// CHECK:           %[[F0:.*]] = yul.arith_shr
// CHECK:           yul.add %[[S]], %{{.*}}
// CHECK:           %[[F1:.*]] = yul.arith_shr
// CHECK:           yul.func_return %[[F0]], %[[F1]] : i256, i256

#Contract = #sol<ContractKind Contract>
module {
  sol.contract @C {
    sol.state_var @m slot 0 offset 0 : !sol.mapping<ui256, !sol.array<? x !sol.struct<(ui256, ui256), Storage>, Storage>>
    sol.func @get_m(%arg0: ui256, %arg1: ui256) -> (ui256, ui256) {
      %0 = sol.addr_of @m : !sol.mapping<ui256, !sol.array<? x !sol.struct<(ui256, ui256), Storage>, Storage>>
      %1 = sol.map %0, %arg0 : !sol.mapping<ui256, !sol.array<? x !sol.struct<(ui256, ui256), Storage>, Storage>>, ui256, !sol.array<? x !sol.struct<(ui256, ui256), Storage>, Storage>
      %2 = sol.gep %1, %arg1 no_panic_bounds : !sol.array<? x !sol.struct<(ui256, ui256), Storage>, Storage>, ui256, !sol.struct<(ui256, ui256), Storage>
      %c0_ui64 = sol.constant 0 : ui64
      %3 = sol.gep %2, %c0_ui64 : !sol.struct<(ui256, ui256), Storage>, ui64, !sol.ptr<ui256, Storage>
      %4 = sol.load %3 : !sol.ptr<ui256, Storage>, ui256
      %c1_ui64 = sol.constant 1 : ui64
      %5 = sol.gep %2, %c1_ui64 : !sol.struct<(ui256, ui256), Storage>, ui64, !sol.ptr<ui256, Storage>
      %6 = sol.load %5 : !sol.ptr<ui256, Storage>, ui256
      sol.return %4, %6 : ui256, ui256
    }
  } {kind = #Contract}
}
