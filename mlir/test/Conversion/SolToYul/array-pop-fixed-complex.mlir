// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The popped uint256[][3] is 3 slots: the pop helper clears the element
// through the fixed array's clear helper, which clears each inner array in a
// loop through the dynamic array's clear helper.
// CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_dyn_ui256_$_Storage_$ : (i256) -> ()
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
// CHECK:         yul.sload %[[A]]
// CHECK:         yul.sstore %[[A]], %{{.*}}
// CHECK:         yul.keccak256
// CHECK:         yul.for
// CHECK:           yul.sstore
// CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_3_array$_dyn_ui256_$_Storage_$_$_Storage_$ : (i256) -> ()
// CHECK-NEXT:  ^bb0(%[[ELT:.*]]: i256):
// CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
// CHECK:         yul.for
// CHECK:           yul.cmp ult, %{{.*}}, %[[C3]]
// CHECK:         } body {
// CHECK:           %[[A:.*]] = yul.add %[[ELT]], %{{.*}}
// CHECK:           yul.func_call @__sol.clear_storage_array.array$_dyn_ui256_$_Storage_$(%[[A]])
// CHECK-LABEL: yul.func @__sol.pop_storage_array.array$_dyn_array$_3_array$_dyn_ui256_$_Storage_$_$_Storage_$_$_Storage_$ : (i256) -> ()
// CHECK-NEXT:  ^bb0(%[[SLOT:.*]]: i256):
// CHECK:         %[[LEN:.*]] = yul.sload %[[SLOT]]
// CHECK:         %[[NEW:.*]] = yul.sub %[[LEN]], %{{.*}}
// CHECK:         %[[DATA:.*]] = yul.keccak256
// CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
// CHECK:         %[[OFF:.*]] = yul.mul %[[NEW]], %[[C3]]
// CHECK:         %[[ELT:.*]] = yul.add %[[DATA]], %[[OFF]]
// CHECK:         yul.func_call @__sol.clear_storage_array.array$_3_array$_dyn_ui256_$_Storage_$_$_Storage_$(%[[ELT]])
// CHECK:         yul.sstore %[[SLOT]], %[[NEW]]
// CHECK-LABEL: yul.func @popDynInFixed : () -> ()
// CHECK:         %[[SLOT:.*]] = yul.constant 0{{$}}
// CHECK:         yul.func_call @__sol.pop_storage_array.array$_dyn_array$_3_array$_dyn_ui256_$_Storage_$_$_Storage_$_$_Storage_$(%[[SLOT]])

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    sol.state_var @dynInFixed slot 0 offset 0 : !sol.array<? x !sol.array<3 x !sol.array<? x ui256, Storage>, Storage>, Storage>
    sol.func @popDynInFixed() attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @dynInFixed : !sol.array<? x !sol.array<3 x !sol.array<? x ui256, Storage>, Storage>, Storage>
      sol.pop %0 : !sol.array<? x !sol.array<3 x !sol.array<? x ui256, Storage>, Storage>, Storage>
      sol.return
    }
  } {kind = #Contract}
}
