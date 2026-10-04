// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Getter bounds failures revert with empty data, not Panic(0x32).
// CHECK-LABEL:   yul.func @get_fixArr : (i256) -> i256
// CHECK:           %[[C3:.*]] = yul.constant 3
// CHECK:           %[[OOB:.*]] = yul.cmp uge, %arg0, %[[C3]]
// CHECK:           yul.if %[[OOB]] {
// CHECK-NEXT:        %[[Z:.*]] = yul.constant 0
// CHECK-NEXT:        yul.revert %[[Z]], %[[Z]]
// CHECK-NEXT:        yul.yield
// CHECK:           yul.sload

// CHECK-LABEL:   yul.func @get_dynArr : (i256) -> i256
// CHECK:           %[[LEN:.*]] = yul.sload
// CHECK:           %[[OOB:.*]] = yul.cmp uge, %arg0, %[[LEN]]
// CHECK:           yul.if %[[OOB]] {
// CHECK-NEXT:        %[[Z:.*]] = yul.constant 0
// CHECK-NEXT:        yul.revert %[[Z]], %[[Z]]
// CHECK-NEXT:        yul.yield
// CHECK:           yul.keccak256
// CHECK:           yul.sload

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @dynArr slot 0 offset 0 : !sol.array<? x ui256, Storage>
    sol.state_var @fixArr slot 1 offset 0 : !sol.array<3 x ui256, Storage>
    sol.func @get_dynArr(%arg0: ui256) -> ui256 {
      %0 = sol.addr_of @dynArr : !sol.array<? x ui256, Storage>
      %1 = sol.gep %0, %arg0 no_panic_bounds : !sol.array<? x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
      %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
      sol.return %2 : ui256
    }
    sol.func @get_fixArr(%arg0: ui256) -> ui256 {
      %0 = sol.addr_of @fixArr : !sol.array<3 x ui256, Storage>
      %1 = sol.gep %0, %arg0 no_panic_bounds : !sol.array<3 x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
      %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
      sol.return %2 : ui256
    }
  } {kind = #Contract}
}
