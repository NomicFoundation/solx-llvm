// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

sol.contract @C {
  // A fixed-size array of mappings has nothing to clear: its helper is empty.
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_3_mapping$_ui256_$_ui256_$_$_Storage_$ : (i256) -> ()
  // CHECK-NEXT:  ^bb0
  // CHECK-NEXT:    yul.func_return
  // CHECK-LABEL: yul.func @fixedMapArr : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
  // CHECK-NEXT:    yul.func_call @__sol.clear_storage_array.array$_3_mapping$_ui256_$_ui256_$_$_Storage_$(%[[A]])
  // CHECK-NEXT:    yul.func_return
  sol.func @fixedMapArr(%a: !sol.array<3 x !sol.mapping<ui256, ui256>, Storage>) {
    sol.delete %a : !sol.array<3 x !sol.mapping<ui256, ui256>, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // Mapping elements are never cleared: only the length is.
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_dyn_mapping$_ui256_$_ui256_$_$_Storage_$ : (i256) -> ()
  // CHECK:         %[[Z:.*]] = yul.constant 0{{$}}
  // CHECK:         yul.sstore %arg0, %[[Z]]
  // CHECK-NOT:     yul.sstore
  // CHECK-NOT:     yul.for
  // CHECK:         yul.func_return
  // CHECK-LABEL: yul.func @mapArr : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
  // CHECK-NEXT:    yul.func_call @__sol.clear_storage_array.array$_dyn_mapping$_ui256_$_ui256_$_$_Storage_$(%[[A]])
  sol.func @mapArr(%a: !sol.array<? x !sol.mapping<ui256, ui256>, Storage>) {
    sol.delete %a : !sol.array<? x !sol.mapping<ui256, ui256>, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // Inner array lengths are zeroed through the inner helper; the mapping
  // elements are never touched.
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_dyn_mapping$_ui256_$_ui256_$_$_Storage_$ : (i256) -> ()
  // CHECK:         yul.sload %arg0
  // CHECK:         yul.sstore %arg0, %{{.*}}
  // CHECK-NOT:     yul.sstore
  // CHECK-NOT:     yul.for
  // CHECK:         yul.func_return
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_dyn_array$_dyn_mapping$_ui256_$_ui256_$_$_Storage_$_$_Storage_$ : (i256) -> ()
  // CHECK:         %[[LEN:.*]] = yul.sload %arg0
  // CHECK:         yul.sstore %arg0, %{{.*}}
  // CHECK:         yul.if
  // CHECK:           yul.mstore %{{.*}}, %arg0
  // CHECK:           yul.keccak256
  // CHECK:           yul.for
  // CHECK:             %[[E:.*]] = yul.add %{{.*}}, %{{.*}}
  // CHECK:             yul.func_call @__sol.clear_storage_array.array$_dyn_mapping$_ui256_$_ui256_$_$_Storage_$(%[[E]])
  // CHECK-NOT:         yul.sstore
  // CHECK:             yul.yield
  // CHECK-LABEL: yul.func @mapArr2D : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
  // CHECK-NEXT:    yul.func_call @__sol.clear_storage_array.array$_dyn_array$_dyn_mapping$_ui256_$_ui256_$_$_Storage_$_$_Storage_$(%[[A]])
  sol.func @mapArr2D(%a: !sol.array<? x !sol.array<? x !sol.mapping<ui256, ui256>, Storage>, Storage>) {
    sol.delete %a : !sol.array<? x !sol.array<? x !sol.mapping<ui256, ui256>, Storage>, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // Two slots per element; only the value member (+0) is cleared.
  // CHECK-LABEL: yul.func @__sol.clear_storage_struct.struct$_$_ui256_$_mapping$_ui256_$_ui256_$_$_$_Storage_$ : (i256) -> ()
  // CHECK:         %[[V:.*]] = yul.add %arg0, %{{.*}}
  // CHECK:         yul.sstore %[[V]], %{{.*}}
  // CHECK-NOT:     yul.sstore
  // CHECK:         yul.func_return
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_dyn_struct$_$_ui256_$_mapping$_ui256_$_ui256_$_$_$_Storage_$_$_Storage_$ : (i256) -> ()
  // CHECK:         yul.sstore %arg0, %{{.*}}
  // CHECK:         yul.keccak256
  // CHECK:         %[[STRIDE:.*]] = yul.constant 2{{$}}
  // CHECK:         yul.for
  // CHECK:         } body {
  // CHECK:           yul.func_call @__sol.clear_storage_struct.struct$_$_ui256_$_mapping$_ui256_$_ui256_$_$_$_Storage_$
  // CHECK-NOT:       yul.sstore
  // CHECK:         } step {
  // CHECK:           yul.add %{{.*}}, %[[STRIDE]]
  // CHECK-LABEL: yul.func @withMapArr : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
  // CHECK-NEXT:    yul.func_call @__sol.clear_storage_array.array$_dyn_struct$_$_ui256_$_mapping$_ui256_$_ui256_$_$_$_Storage_$_$_Storage_$(%[[A]])
  sol.func @withMapArr(%a: !sol.array<? x !sol.struct<(ui256, !sol.mapping<ui256, ui256>), Storage>, Storage>) {
    sol.delete %a : !sol.array<? x !sol.struct<(ui256, !sol.mapping<ui256, ui256>), Storage>, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // uint[3] at +0..2 by a full_unroll loop in its helper, the uint[] length at
  // +3 then its data in its helper, the mapping at +4 skipped, the packed
  // address/bool slot +5 zeroed once.
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_dyn_ui256_$_Storage_$ : (i256) -> ()
  // CHECK:         %[[LEN:.*]] = yul.sload %arg0
  // CHECK:         yul.sstore %arg0, %{{.*}}
  // CHECK:         yul.if
  // CHECK:           yul.keccak256
  // CHECK:           yul.for
  // CHECK:             yul.sstore
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_3_ui256_$_Storage_$ : (i256) -> ()
  // CHECK:         %[[N:.*]] = yul.constant 3{{$}}
  // CHECK:         yul.for
  // CHECK:           yul.cmp ult, %{{.*}}, %[[N]]
  // CHECK:           yul.sstore
  // CHECK:         } {full_unroll}
  // CHECK-LABEL: yul.func @__sol.clear_storage_struct.struct$_$_array$_3_ui256_$_Storage_$_$_array$_dyn_ui256_$_Storage_$_$_mapping$_ui256_$_ui256_$_$_address_$_i1_$_$_Storage_$ : (i256) -> ()
  // CHECK:         %[[FSLOT:.*]] = yul.add %arg0, %{{.*}}
  // CHECK:         yul.func_call @__sol.clear_storage_array.array$_3_ui256_$_Storage_$(%[[FSLOT]])
  // CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
  // CHECK:         %[[LSLOT:.*]] = yul.add %arg0, %[[C3]]
  // CHECK:         yul.func_call @__sol.clear_storage_array.array$_dyn_ui256_$_Storage_$(%[[LSLOT]])
  // CHECK:         %[[C5:.*]] = yul.constant 5{{$}}
  // CHECK:         %[[OSLOT:.*]] = yul.add %arg0, %[[C5]]
  // CHECK:         yul.sstore %[[OSLOT]], %{{.*}}
  // CHECK-NOT:     yul.sstore
  // CHECK:         yul.func_return
  // CHECK-LABEL: yul.func @mixedStruct : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
  // CHECK-NEXT:    yul.func_call @__sol.clear_storage_struct.struct$_$_array$_3_ui256_$_Storage_$_$_array$_dyn_ui256_$_Storage_$_$_mapping$_ui256_$_ui256_$_$_address_$_i1_$_$_Storage_$(%[[A]])
  sol.func @mixedStruct(%a: !sol.struct<(!sol.array<3 x ui256, Storage>, !sol.array<? x ui256, Storage>, !sol.mapping<ui256, ui256>, !sol.address, i1), Storage>) {
    sol.delete %a : !sol.struct<(!sol.array<3 x ui256, Storage>, !sol.array<? x ui256, Storage>, !sol.mapping<ui256, ui256>, !sol.address, i1), Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // 2**64 uint8 elements pack into 2**59 slots.
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_18446744073709551616_ui8_$_Storage_$ : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
  // CHECK:         %[[N:.*]] = yul.constant 576460752303423488
  // CHECK:         yul.for
  // CHECK:           yul.cmp ult, %{{.*}}, %[[N]]
  // CHECK:         } body {
  // CHECK:           %[[P:.*]] = yul.add %[[A]], %{{.*}}
  // CHECK:           yul.sstore %[[P]], %{{.*}}
  // CHECK:         } step {
  // CHECK-LABEL: yul.func @hugePacked : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
  // CHECK-NEXT:    yul.func_call @__sol.clear_storage_array.array$_18446744073709551616_ui8_$_Storage_$(%[[A]])
  sol.func @hugePacked(%a: !sol.array<18446744073709551616 x ui8, Storage>) {
    sol.delete %a : !sol.array<18446744073709551616 x ui8, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // CHECK-LABEL: yul.func @__sol.clear_storage_string_tail : (i256, i256, i256) -> ()
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_18446744073709551616_string$_Storage_$_$_Storage_$ : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
  // CHECK:         %[[N:.*]] = yul.constant 18446744073709551616
  // CHECK:         yul.for
  // CHECK:           yul.cmp ult, %{{.*}}, %[[N]]
  // CHECK:         } body {
  // CHECK:           %[[P:.*]] = yul.add %[[A]], %{{.*}}
  // CHECK:           %[[L:.*]] = yul.func_call @__sol.storage_string_length
  // CHECK:           yul.func_call @__sol.clear_storage_string_tail(%[[P]], %[[L]],
  // CHECK:           yul.sstore %[[P]], %{{.*}}
  // CHECK:         } step {
  // CHECK-LABEL: yul.func @hugeStr : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
  // CHECK-NEXT:    yul.func_call @__sol.clear_storage_array.array$_18446744073709551616_string$_Storage_$_$_Storage_$(%[[A]])
  sol.func @hugeStr(%a: !sol.array<18446744073709551616 x !sol.string<Storage>, Storage>) {
    sol.delete %a : !sol.array<18446744073709551616 x !sol.string<Storage>, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // The member after the 2**64-slot array sits at slot 2**64 + 1.
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_18446744073709551616_ui256_$_Storage_$ : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[ARR:.*]]: i256):
  // CHECK:         %[[N:.*]] = yul.constant 18446744073709551616
  // CHECK:         yul.for
  // CHECK:           yul.cmp ult, %{{.*}}, %[[N]]
  // CHECK:         } body {
  // CHECK:           %[[P:.*]] = yul.add %[[ARR]], %{{.*}}
  // CHECK:           yul.sstore %[[P]], %{{.*}}
  // CHECK:         } step {
  // CHECK-LABEL: yul.func @__sol.clear_storage_struct.struct$_$_ui256_$_array$_18446744073709551616_ui256_$_Storage_$_$_ui256_$_$_Storage_$ : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[S:.*]]: i256):
  // CHECK:         %[[X:.*]] = yul.add %[[S]]
  // CHECK:         yul.sstore %[[X]], %{{.*}}
  // CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
  // CHECK:         %[[A:.*]] = yul.add %[[S]], %[[C1]]
  // CHECK:         yul.func_call @__sol.clear_storage_array.array$_18446744073709551616_ui256_$_Storage_$(%[[A]])
  // CHECK:         %[[YOFF:.*]] = yul.constant 18446744073709551617
  // CHECK:         %[[Y:.*]] = yul.add %[[S]], %[[YOFF]]
  // CHECK:         yul.sstore %[[Y]], %{{.*}}
  // CHECK-LABEL: yul.func @hugeStructMember : (i256) -> ()
  // CHECK-NEXT:  ^bb0(%[[S:.*]]: i256):
  // CHECK-NEXT:    yul.func_call @__sol.clear_storage_struct.struct$_$_ui256_$_array$_18446744073709551616_ui256_$_Storage_$_$_ui256_$_$_Storage_$(%[[S]])
  sol.func @hugeStructMember(%s: !sol.struct<(ui256, !sol.array<18446744073709551616 x ui256, Storage>, ui256), Storage>) {
    sol.delete %s : !sol.struct<(ui256, !sol.array<18446744073709551616 x ui256, Storage>, ui256), Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}
