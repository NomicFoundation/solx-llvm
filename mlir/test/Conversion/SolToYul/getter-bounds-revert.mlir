// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Getter bounds failures revert with empty data, not Panic(0x32).

#Contract = #sol<ContractKind Contract>

// CHECK-LABEL:   yul.func @__sol.index_storage_array.array$_3_ui256_$_Storage_$.nopanic : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK:           %[[C3:.*]] = yul.constant 3
// CHECK:           %[[OOB:.*]] = yul.cmp uge, %arg1, %[[C3]]
// CHECK:           yul.if %[[OOB]] {
// CHECK-NEXT:        %[[Z:.*]] = yul.constant 0
// CHECK-NEXT:        yul.revert %[[Z]], %[[Z]]
// CHECK-NEXT:        yul.yield
// CHECK-LABEL:   yul.func @get_fixArr : (i256) -> i256
// CHECK:           yul.func_call @__sol.index_storage_array.array$_3_ui256_$_Storage_$.nopanic(%{{.*}}, %arg0)
// CHECK:           yul.sload
module {
  sol.contract @C {
    sol.state_var @fixArr slot 1 offset 0 : !sol.array<3 x ui256, Storage>
    sol.func @get_fixArr(%arg0: ui256) -> ui256 {
      %0 = sol.addr_of @fixArr : !sol.array<3 x ui256, Storage>
      %1 = sol.gep %0, %arg0 no_panic_bounds : !sol.array<3 x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
      %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
      sol.return %2 : ui256
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>

// CHECK-LABEL:   yul.func @__sol.index_storage_array.array$_dyn_ui256_$_Storage_$.nopanic : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK:           %[[LEN:.*]] = yul.sload %arg0
// CHECK:           %[[OOB:.*]] = yul.cmp uge, %arg1, %[[LEN]]
// CHECK:           yul.if %[[OOB]] {
// CHECK-NEXT:        %[[Z:.*]] = yul.constant 0
// CHECK-NEXT:        yul.revert %[[Z]], %[[Z]]
// CHECK-NEXT:        yul.yield
// CHECK:           yul.keccak256
// CHECK-LABEL:   yul.func @get_dynArr : (i256) -> i256
// CHECK:           yul.func_call @__sol.index_storage_array.array$_dyn_ui256_$_Storage_$.nopanic(%{{.*}}, %arg0)
// CHECK:           yul.sload
module {
  sol.contract @C {
    sol.state_var @dynArr slot 0 offset 0 : !sol.array<? x ui256, Storage>
    sol.func @get_dynArr(%arg0: ui256) -> ui256 {
      %0 = sol.addr_of @dynArr : !sol.array<? x ui256, Storage>
      %1 = sol.gep %0, %arg0 no_panic_bounds : !sol.array<? x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
      %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
      sol.return %2 : ui256
    }
  } {kind = #Contract}
}
