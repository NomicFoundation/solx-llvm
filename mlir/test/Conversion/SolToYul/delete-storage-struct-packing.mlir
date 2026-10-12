// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// `delete` on a storage struct clears member by member, each at its own byte
// offset and width, as the legacy code generator does. The bytes of a packed
// slot that no member occupies survive: the slot is read, masked and written
// back. A slot the members fill completely is written zero without a read.
// Members that are not packable scalars own whole slots and clear through the
// recursion, so they never join a mask.
//
// A struct or an array is cleared by an out-of-line helper, one per type
// (`__sol.clear_storage_struct.*`, `__sol.clear_storage_array.*`), that takes
// the slot. The function that deletes only calls it.

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// Two one-byte members share the first slot, so 30 bytes of it survive. The
// third member fills the second slot.
!Padding = !sol.struct<(ui8, ui8, ui256), Storage>

// CHECK-LABEL: yul.func @__sol.clear_storage_struct.struct$_$_ui8_$_ui8_$_ui256_$_$_Storage_$ : (i256) -> ()
// CHECK-NEXT:  ^bb0([[BASE:%.+]]: i256):
// CHECK:         [[SLOT0:%.+]] = yul.add [[BASE]], %c0
// CHECK-NEXT:    [[OLD0:%.+]] = yul.sload [[SLOT0]]
// Two bytes cleared: ~(2^16 - 1).
// CHECK-NEXT:    [[MASK0:%.+]] = yul.constant -65536
// CHECK-NEXT:    [[NEW0:%.+]] = yul.and [[OLD0]], [[MASK0]]
// CHECK-NEXT:    yul.sstore [[SLOT0]], [[NEW0]]
// CHECK:         [[SLOT1:%.+]] = yul.add [[BASE]], %c1
// CHECK-NEXT:    [[ZERO:%.+]] = yul.constant 0
// CHECK-NEXT:    yul.sstore [[SLOT1]], [[ZERO]]
// CHECK-NEXT:    yul.func_return
// CHECK-LABEL: yul.func @delete_padding
// CHECK:         [[SLOT:%.+]] = yul.constant 0
// CHECK-NEXT:    yul.func_call @__sol.clear_storage_struct.struct$_$_ui8_$_ui8_$_ui256_$_$_Storage_$([[SLOT]]) : (i256) -> ()
// CHECK-NEXT:    yul.func_return
sol.contract @Padding {
  sol.state_var @s slot 0 offset 0 : !Padding
  sol.func @delete_padding() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %0 = sol.addr_of @s : !Padding
    sol.delete %0 : !Padding
    sol.return
  }
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// Two members that together fill the slot: nothing to preserve, so the slot is
// written zero without being read.
!Full = !sol.struct<(ui128, ui128), Storage>

// CHECK-LABEL: yul.func @__sol.clear_storage_struct.struct$_$_ui128_$_ui128_$_$_Storage_$ : (i256) -> ()
// CHECK-NOT:     yul.sload
// CHECK:         [[SLOT:%.+]] = yul.add
// CHECK-NEXT:    [[ZERO:%.+]] = yul.constant 0
// CHECK-NEXT:    yul.sstore [[SLOT]], [[ZERO]]
// CHECK-NEXT:    yul.func_return
// CHECK-LABEL: yul.func @delete_full
// CHECK:         yul.func_call @__sol.clear_storage_struct.struct$_$_ui128_$_ui128_$_$_Storage_$(
// CHECK-NEXT:    yul.func_return
sol.contract @Full {
  sol.state_var @s slot 0 offset 0 : !Full
  sol.func @delete_full() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %0 = sol.addr_of @s : !Full
    sol.delete %0 : !Full
    sol.return
  }
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// A full slot followed by a partial one: the mask is reset between slots, so
// the first is written zero outright and only the second is read and masked.
!TwoSlots = !sol.struct<(ui128, ui128, ui8), Storage>

// CHECK-LABEL: yul.func @__sol.clear_storage_struct.struct$_$_ui128_$_ui128_$_ui8_$_$_Storage_$ : (i256) -> ()
// CHECK-NEXT:  ^bb0([[BASE:%.+]]: i256):
// CHECK:         [[SLOT0:%.+]] = yul.add [[BASE]], %c0
// CHECK-NEXT:    [[ZERO:%.+]] = yul.constant 0
// CHECK-NEXT:    yul.sstore [[SLOT0]], [[ZERO]]
// CHECK:         [[SLOT1:%.+]] = yul.add [[BASE]], %c1
// CHECK-NEXT:    [[OLD1:%.+]] = yul.sload [[SLOT1]]
// One byte cleared: ~(2^8 - 1).
// CHECK-NEXT:    [[MASK1:%.+]] = yul.constant -256
// CHECK-NEXT:    [[NEW1:%.+]] = yul.and [[OLD1]], [[MASK1]]
// CHECK-NEXT:    yul.sstore [[SLOT1]], [[NEW1]]
// CHECK-NEXT:    yul.func_return
// CHECK-LABEL: yul.func @delete_two_slots
// CHECK:         [[SLOT:%.+]] = yul.constant 1
// CHECK-NEXT:    yul.func_call @__sol.clear_storage_struct.struct$_$_ui128_$_ui128_$_ui8_$_$_Storage_$([[SLOT]]) : (i256) -> ()
// CHECK-NEXT:    yul.func_return
sol.contract @TwoSlots {
  sol.state_var @s slot 1 offset 0 : !TwoSlots
  sol.func @delete_two_slots() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %0 = sol.addr_of @s : !TwoSlots
    sol.delete %0 : !TwoSlots
    sol.return
  }
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// Every packable scalar kind contributes its storage width to the mask: bool
// 1, address 20, bytes4 4, uint8 1, which is 26 bytes.
!Kinds = !sol.struct<(i1, !sol.address, !sol.fixedbytes<4>, ui8), Storage>

// CHECK-LABEL: yul.func @__sol.clear_storage_struct.struct$_$_i1_$_address_$_fixedbytes$_4_$_$_ui8_$_$_Storage_$ : (i256) -> ()
// CHECK:         [[SLOT:%.+]] = yul.add
// CHECK-NEXT:    [[OLD:%.+]] = yul.sload [[SLOT]]
// 26 bytes cleared: -(2^208).
// CHECK-NEXT:    [[MASK:%.+]] = yul.constant -411376139330301510538742295639337626245683966408394965837152256
// CHECK-NEXT:    [[NEW:%.+]] = yul.and [[OLD]], [[MASK]]
// CHECK-NEXT:    yul.sstore [[SLOT]], [[NEW]]
// CHECK-NEXT:    yul.func_return
// CHECK-LABEL: yul.func @delete_kinds
// CHECK:         yul.func_call @__sol.clear_storage_struct.struct$_$_i1_$_address_$_fixedbytes$_4_$_$_ui8_$_$_Storage_$(
// CHECK-NEXT:    yul.func_return
sol.contract @Kinds {
  sol.state_var @s slot 0 offset 0 : !Kinds
  sol.func @delete_kinds() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %0 = sol.addr_of @s : !Kinds
    sol.delete %0 : !Kinds
    sol.return
  }
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// Aggregate members are slot aligned and clear through the recursion. Layout:
// slot 0 holds the first uint8, slots 1 and 2 the array, slot 3 the mapping,
// slot 4 the last uint8. The two scalars are each alone in their slot and are
// masked. The array's slots are zeroed by the loop of its own helper, and the
// mapping emits nothing.
!Aggregates = !sol.struct<(ui8, !sol.array<2 x ui256, Storage>, !sol.mapping<ui256, ui256>, ui8), Storage>

// CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_2_ui256_$_Storage_$ : (i256) -> ()
// CHECK-NEXT:  ^bb0([[ARR:%.+]]: i256):
// CHECK:         yul.for
// CHECK:         body {
// CHECK-NEXT:    ^bb0([[IDX:%.+]]: i256):
// CHECK-NEXT:      [[ELT:%.+]] = yul.add [[ARR]], [[IDX]]
// CHECK-NEXT:      yul.sstore [[ELT]], %c0
// CHECK:         } {full_unroll}
// CHECK:         yul.func_return
// CHECK-LABEL: yul.func @__sol.clear_storage_struct.struct$_$_ui8_$_array$_2_ui256_$_Storage_$_$_mapping$_ui256_$_ui256_$_$_ui8_$_$_Storage_$ : (i256) -> ()
// CHECK-NEXT:  ^bb0([[BASE:%.+]]: i256):
// CHECK:         [[SLOT0:%.+]] = yul.add [[BASE]], %c0
// CHECK-NEXT:    [[OLD0:%.+]] = yul.sload [[SLOT0]]
// CHECK-NEXT:    [[MASK0:%.+]] = yul.constant -256
// CHECK-NEXT:    [[NEW0:%.+]] = yul.and [[OLD0]], [[MASK0]]
// CHECK-NEXT:    yul.sstore [[SLOT0]], [[NEW0]]
// CHECK:         [[ARR:%.+]] = yul.add [[BASE]], %c1
// CHECK-NEXT:    yul.func_call @__sol.clear_storage_array.array$_2_ui256_$_Storage_$([[ARR]]) : (i256) -> ()
// The mapping at slot 3 is skipped: the next store is the scalar at slot 4.
// CHECK-NOT:     yul.sstore
// CHECK:         [[SLOT4:%.+]] = yul.add [[BASE]], %c4
// CHECK-NEXT:    [[OLD4:%.+]] = yul.sload [[SLOT4]]
// CHECK-NEXT:    [[MASK4:%.+]] = yul.constant -256
// CHECK-NEXT:    [[NEW4:%.+]] = yul.and [[OLD4]], [[MASK4]]
// CHECK-NEXT:    yul.sstore [[SLOT4]], [[NEW4]]
// CHECK-NEXT:    yul.func_return
// CHECK-LABEL: yul.func @delete_aggregates
// CHECK:         yul.func_call @__sol.clear_storage_struct.struct$_$_ui8_$_array$_2_ui256_$_Storage_$_$_mapping$_ui256_$_ui256_$_$_ui8_$_$_Storage_$(
// CHECK-NEXT:    yul.func_return
sol.contract @Aggregates {
  sol.state_var @s slot 0 offset 0 : !Aggregates
  sol.func @delete_aggregates() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %0 = sol.addr_of @s : !Aggregates
    sol.delete %0 : !Aggregates
    sol.return
  }
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// A static array of packed structs is an array of aggregates, so it is cleared
// element by element in a runtime loop that steps by the element's two slots,
// and every element keeps its padding: the array's helper calls the struct's.
// Before the fix such an array was zeroed slot by slot, since its element has
// no dynamically sized part.
!ArrayOfStructs = !sol.array<2 x !sol.struct<(ui8, ui256), Storage>, Storage>

// CHECK-LABEL: yul.func @__sol.clear_storage_struct.struct$_$_ui8_$_ui256_$_$_Storage_$ : (i256) -> ()
// CHECK-NEXT:  ^bb0([[ELT:%.+]]: i256):
// CHECK:         [[SLOT0:%.+]] = yul.add [[ELT]], %c0
// CHECK-NEXT:    [[OLD0:%.+]] = yul.sload [[SLOT0]]
// CHECK-NEXT:    [[MASK0:%.+]] = yul.constant -256
// CHECK-NEXT:    [[NEW0:%.+]] = yul.and [[OLD0]], [[MASK0]]
// CHECK-NEXT:    yul.sstore [[SLOT0]], [[NEW0]]
// CHECK:         [[SLOT1:%.+]] = yul.add [[ELT]], %c1
// CHECK-NEXT:    [[ZERO:%.+]] = yul.constant 0
// CHECK-NEXT:    yul.sstore [[SLOT1]], [[ZERO]]
// CHECK-NEXT:    yul.func_return
// CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_2_struct$_$_ui8_$_ui256_$_$_Storage_$_$_Storage_$ : (i256) -> ()
// CHECK-NEXT:  ^bb0([[BASE:%.+]]: i256):
// CHECK-NOT:     yul.sstore
// CHECK:         yul.for
// CHECK:         body {
// CHECK-NEXT:    ^bb0([[OFF:%.+]]: i256):
// CHECK-NEXT:      [[ELT:%.+]] = yul.add [[BASE]], [[OFF]]
// CHECK-NEXT:      yul.func_call @__sol.clear_storage_struct.struct$_$_ui8_$_ui256_$_$_Storage_$([[ELT]]) : (i256) -> ()
// CHECK:         } step {
// CHECK-NEXT:    ^bb0([[CUR:%.+]]: i256):
// CHECK-NEXT:      yul.add [[CUR]], %c2
// CHECK-NOT:     {full_unroll}
// CHECK:         yul.func_return
// CHECK-LABEL: yul.func @delete_array_of_structs
// CHECK:         [[SLOT:%.+]] = yul.constant 8
// CHECK-NEXT:    yul.func_call @__sol.clear_storage_array.array$_2_struct$_$_ui8_$_ui256_$_$_Storage_$_$_Storage_$([[SLOT]]) : (i256) -> ()
// CHECK-NEXT:    yul.func_return
sol.contract @ArrayOfStructs {
  sol.state_var @s slot 8 offset 0 : !ArrayOfStructs
  sol.func @delete_array_of_structs() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %0 = sol.addr_of @s : !ArrayOfStructs
    sol.delete %0 : !ArrayOfStructs
    sol.return
  }
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// A static array of packed scalars is still cleared whole slot by whole slot,
// as in legacy: the unused tail bytes of its slot read zero after the delete.
!ArrayOfBytes = !sol.array<4 x ui8, Storage>

// CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_4_ui8_$_Storage_$ : (i256) -> ()
// CHECK-NEXT:  ^bb0([[SLOT:%.+]]: i256):
// CHECK-NOT:     yul.sload
// CHECK:         [[ZERO:%.+]] = yul.constant 0
// CHECK-NEXT:    yul.sstore [[SLOT]], [[ZERO]]
// CHECK-NEXT:    yul.func_return
// CHECK-LABEL: yul.func @delete_array_of_bytes
// CHECK:         [[SLOT:%.+]] = yul.constant 12
// CHECK-NEXT:    yul.func_call @__sol.clear_storage_array.array$_4_ui8_$_Storage_$([[SLOT]]) : (i256) -> ()
// CHECK-NEXT:    yul.func_return
sol.contract @ArrayOfBytes {
  sol.state_var @s slot 12 offset 0 : !ArrayOfBytes
  sol.func @delete_array_of_bytes() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %0 = sol.addr_of @s : !ArrayOfBytes
    sol.delete %0 : !ArrayOfBytes
    sol.return
  }
} {kind = #Contract}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// An identified struct clears through its helper, which recurses at runtime
// through the nested array's helper. The struct helper's body masks the packed
// member the same way, and the caller only calls it.
!Recursive = !sol.struct<"R", Storage, (ui8, !sol.array<? x !sol.struct<"R", Storage>, Storage>)>

// CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_dyn_struct$_R_$_Storage_$_$_ui8_$_array$_dyn_struct$_R_$_Storage_$_$_Storage_$_$_$_$_Storage_$ : (i256) -> ()
// CHECK-NEXT:  ^bb0([[SLOT1:%.+]]: i256):
// CHECK-NEXT:    [[LEN:%.+]] = yul.sload [[SLOT1]]
// CHECK:         yul.sstore [[SLOT1]], %c0
// CHECK:         yul.func_call @__sol.clear_storage_struct.R(
// CHECK:         yul.func_return
// CHECK-LABEL: yul.func @__sol.clear_storage_struct.R : (i256) -> ()
// CHECK-NEXT:  ^bb0([[ARG:%.+]]: i256):
// CHECK:         [[SLOT0:%.+]] = yul.add [[ARG]], %c0
// CHECK-NEXT:    [[OLD0:%.+]] = yul.sload [[SLOT0]]
// CHECK-NEXT:    [[MASK0:%.+]] = yul.constant -256
// CHECK-NEXT:    [[NEW0:%.+]] = yul.and [[OLD0]], [[MASK0]]
// CHECK-NEXT:    yul.sstore [[SLOT0]], [[NEW0]]
// CHECK:         [[SLOT1:%.+]] = yul.add [[ARG]], %c1
// CHECK-NEXT:    yul.func_call @__sol.clear_storage_array.array$_dyn_struct$_R_$_Storage_$_$_ui8_$_array$_dyn_struct$_R_$_Storage_$_$_Storage_$_$_$_$_Storage_$([[SLOT1]]) : (i256) -> ()
// CHECK-NEXT:    yul.func_return
// CHECK-LABEL: yul.func @delete_recursive
// CHECK:         [[SLOT:%.+]] = yul.constant 13
// CHECK-NEXT:    yul.func_call @__sol.clear_storage_struct.R([[SLOT]]) : (i256) -> ()
// CHECK-NEXT:    yul.func_return
sol.contract @Recursive {
  sol.state_var @s slot 13 offset 0 : !Recursive
  sol.func @delete_recursive() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %0 = sol.addr_of @s : !Recursive
    sol.delete %0 : !Recursive
    sol.return
  }
} {kind = #Contract}
