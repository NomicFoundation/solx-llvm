// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The popped uint256[][3] is 3 slots, each inner array cleared in a loop.
// CHECK-LABEL: yul.func @popDynInFixed : () -> ()
// CHECK:         %[[LEN:.*]] = yul.sload %[[SLOT:.*]]
// CHECK:         %[[NEW:.*]] = yul.sub %[[LEN]], %{{.*}}
// CHECK:         %[[DATA:.*]] = yul.keccak256
// CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
// CHECK:         %[[OFF:.*]] = yul.mul %[[NEW]], %[[C3]]
// CHECK:         %[[ELT:.*]] = yul.add %[[DATA]], %[[OFF]]
// CHECK:         yul.for
// CHECK:         } body {
// CHECK:           %[[A:.*]] = yul.add %[[ELT]], %{{.*}}
// CHECK:           yul.sload %[[A]]
// CHECK:           yul.sstore %[[A]], %{{.*}}
// CHECK:           yul.keccak256
// CHECK:           yul.for
// CHECK:             yul.sstore
// CHECK:         yul.sstore %[[SLOT]], %[[NEW]]

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @dynInFixed slot 0 offset 0 : !sol.array<? x !sol.array<3 x !sol.array<? x ui256, Storage>, Storage>, Storage>
    sol.func @popDynInFixed() attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @dynInFixed : !sol.array<? x !sol.array<3 x !sol.array<? x ui256, Storage>, Storage>, Storage>
      sol.pop %0 : !sol.array<? x !sol.array<3 x !sol.array<? x ui256, Storage>, Storage>, Storage>
      sol.return
    }
  } {kind = #Contract}
}
