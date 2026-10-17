// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
module {
  // The element spans 9 slots. The pop is an outlined helper that clears the
  // element through the struct's clear helper, which clears each member by
  // kind: a plain slot, the bytes17[3] loop, the string tail, the uint256[]
  // data, flag+direction sharing slot 6 and the nested struct with its
  // bool[][], each nested aggregate through its own clear helper.
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_dyn_i1_$_Storage_$ : (i256) -> ()
  // CHECK:         yul.sload
  // CHECK:         yul.sstore
  // CHECK:         yul.keccak256
  // CHECK:         yul.for
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_dyn_array$_dyn_i1_$_Storage_$_$_Storage_$ : (i256) -> ()
  // CHECK:         yul.for
  // CHECK:           yul.func_call @__sol.clear_storage_array.array$_dyn_i1_$_Storage_$
  // CHECK-LABEL: yul.func @__sol.clear_storage_struct.struct$_$_ui256_$_array$_dyn_array$_dyn_i1_$_Storage_$_$_Storage_$_$_$_Storage_$ : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[INNER:.*]]: i256):
  // CHECK:         %[[X:.*]] = yul.add %[[INNER]], %{{.*}}
  // CHECK:         yul.sstore %[[X]], %{{.*}}
  // CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
  // CHECK:         %[[FLAGS:.*]] = yul.add %[[INNER]], %[[C1]]
  // CHECK:         yul.func_call @__sol.clear_storage_array.array$_dyn_array$_dyn_i1_$_Storage_$_$_Storage_$(%[[FLAGS]])
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_dyn_ui256_$_Storage_$ : (i256) -> ()
  // CHECK:         yul.sload
  // CHECK:         yul.sstore
  // CHECK:         yul.keccak256
  // CHECK:         yul.for
  // CHECK-LABEL: yul.func @__sol.clear_storage_string_tail : (i256, i256, i256) -> ()
  // CHECK-LABEL: yul.func @__sol.storage_string_length : (i256) -> i256
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_3_fixedbytes$_17_$_$_Storage_$ : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[CS:.*]]: i256):
  // CHECK:         yul.for
  // CHECK:           yul.add %[[CS]], %{{.*}}
  // CHECK:           yul.sstore
  // CHECK:         } {full_unroll}
  // CHECK-LABEL: yul.func @__sol.clear_storage_struct.struct$_$_ui8_$_array$_3_fixedbytes$_17_$_$_Storage_$_$_string$_Storage_$_$_array$_dyn_ui256_$_Storage_$_$_i1_$_enum$_3_$_$_struct$_$_ui256_$_array$_dyn_array$_dyn_i1_$_Storage_$_$_Storage_$_$_$_Storage_$_$_$_Storage_$ : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[ELT:.*]]: i256):
  // CHECK:         yul.sstore
  // CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
  // CHECK:         %[[CS:.*]] = yul.add %[[ELT]], %[[C1]]
  // CHECK:         yul.func_call @__sol.clear_storage_array.array$_3_fixedbytes$_17_$_$_Storage_$(%[[CS]])
  // CHECK:         %[[C4:.*]] = yul.constant 4{{$}}
  // CHECK:         %[[DS:.*]] = yul.add %[[ELT]], %[[C4]]
  // CHECK:         %[[DLEN:.*]] = yul.func_call @__sol.storage_string_length
  // CHECK:         yul.func_call @__sol.clear_storage_string_tail(%[[DS]], %[[DLEN]], %{{.*}})
  // CHECK:         yul.sstore %[[DS]], %{{.*}}
  // CHECK:         %[[C5:.*]] = yul.constant 5{{$}}
  // CHECK:         %[[ES:.*]] = yul.add %[[ELT]], %[[C5]]
  // CHECK:         yul.func_call @__sol.clear_storage_array.array$_dyn_ui256_$_Storage_$(%[[ES]])
  // CHECK:         %[[C6:.*]] = yul.constant 6{{$}}
  // CHECK:         %[[FLAG:.*]] = yul.add %[[ELT]], %[[C6]]
  // CHECK:         yul.sload %[[FLAG]]
  // CHECK:         yul.sstore %[[FLAG]], %{{.*}}
  // CHECK:         %[[C7:.*]] = yul.constant 7{{$}}
  // CHECK:         %[[INNER:.*]] = yul.add %[[ELT]], %[[C7]]
  // CHECK:         yul.func_call @__sol.clear_storage_struct.struct$_$_ui256_$_array$_dyn_array$_dyn_i1_$_Storage_$_$_Storage_$_$_$_Storage_$(%[[INNER]])
  // CHECK-LABEL: yul.func @__sol.panic : (i256) -> ()
  // CHECK-LABEL: yul.func @__sol.pop_storage_array.array$_dyn_struct$_$_ui8_$_array$_3_fixedbytes$_17_$_$_Storage_$_$_string$_Storage_$_$_array$_dyn_ui256_$_Storage_$_$_i1_$_enum$_3_$_$_struct$_$_ui256_$_array$_dyn_array$_dyn_i1_$_Storage_$_$_Storage_$_$_$_Storage_$_$_$_Storage_$_$_Storage_$ : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[SLOT:.*]]: i256):
  // CHECK:         %[[LEN:.*]] = yul.sload %[[SLOT]]
  // CHECK:         yul.constant 49
  // CHECK:         yul.func_call @__sol.panic
  // CHECK:         %[[NEW:.*]] = yul.sub %[[LEN]], %{{.*}}
  // CHECK:         %[[DATA:.*]] = yul.keccak256
  // CHECK:         %[[C9:.*]] = yul.constant 9{{$}}
  // CHECK:         %[[OFF:.*]] = yul.mul %[[NEW]], %[[C9]]
  // CHECK:         %[[ELT:.*]] = yul.add %[[DATA]], %[[OFF]]
  // CHECK:         yul.func_call @__sol.clear_storage_struct.struct$_$_ui8_$_array$_3_fixedbytes$_17_$_$_Storage_$_$_string$_Storage_$_$_array$_dyn_ui256_$_Storage_$_$_i1_$_enum$_3_$_$_struct$_$_ui256_$_array$_dyn_array$_dyn_i1_$_Storage_$_$_Storage_$_$_$_Storage_$_$_$_Storage_$(%[[ELT]])
  // CHECK:         yul.sstore %[[SLOT]], %[[NEW]]
  // CHECK-LABEL: yul.func @pop : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
  // CHECK-NEXT:    yul.func_call @__sol.pop_storage_array.array$_dyn_struct{{.*}}(%[[A]])
  sol.contract @C {
    sol.func @pop(%a: !sol.array<? x !sol.struct<(ui8, !sol.array<3 x !sol.fixedbytes<17>, Storage>, !sol.string<Storage>, !sol.array<? x ui256, Storage>, i1, !sol.enum<3>, !sol.struct<(ui256, !sol.array<? x !sol.array<? x i1, Storage>, Storage>), Storage>), Storage>, Storage>) {
      sol.pop %a : !sol.array<? x !sol.struct<(ui8, !sol.array<3 x !sol.fixedbytes<17>, Storage>, !sol.string<Storage>, !sol.array<? x ui256, Storage>, i1, !sol.enum<3>, !sol.struct<(ui256, !sol.array<? x !sol.array<? x i1, Storage>, Storage>), Storage>), Storage>, Storage>
      sol.return
    }
  } {kind = #Contract, runtime}
}
