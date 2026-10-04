// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A fixed-size array of mappings has nothing to clear.
// CHECK-LABEL: yul.func @fixedMapArr : (i256) -> ()
// CHECK-NEXT:  ^bb0
// CHECK-NEXT:    yul.func_return

// Mapping elements are never cleared: only the length is.
// CHECK-LABEL: yul.func @mapArr : (i256) -> ()
// CHECK:         %[[Z:.*]] = yul.constant 0{{$}}
// CHECK:         yul.sstore %arg0, %[[Z]]
// CHECK-NOT:     yul.sstore
// CHECK-NOT:     yul.for
// CHECK:         yul.func_return

// Inner array lengths are zeroed; the mapping elements are never touched.
// CHECK-LABEL: yul.func @mapArr2D : (i256) -> ()
// CHECK:         %[[LEN:.*]] = yul.sload %arg0
// CHECK:         yul.sstore %arg0, %{{.*}}
// CHECK:         yul.if
// CHECK:           yul.mstore %{{.*}}, %arg0
// CHECK:           yul.keccak256
// CHECK:           yul.for
// CHECK:             %[[E:.*]] = yul.add %{{.*}}, %{{.*}}
// CHECK:             yul.sload %[[E]]
// CHECK:             yul.sstore %[[E]], %{{.*}}
// CHECK-NOT:         yul.sstore
// CHECK:             yul.yield

// Two slots per element; only the value member (+0) is cleared.
// CHECK-LABEL: yul.func @withMapArr : (i256) -> ()
// CHECK:         yul.sstore %arg0, %{{.*}}
// CHECK:         yul.keccak256
// CHECK:         %[[STRIDE:.*]] = yul.constant 2{{$}}
// CHECK:         yul.for
// CHECK:         } body {
// CHECK:           yul.sstore
// CHECK-NOT:       yul.sstore
// CHECK:         } step {
// CHECK:           yul.add %{{.*}}, %[[STRIDE]]

// uint[3] at +0..2 by a full_unroll loop, the uint[] length at +3 then its
// data, the mapping at +4 skipped, the packed address/bool slot +5 zeroed once.
// CHECK-LABEL: yul.func @mixedStruct : (i256) -> ()
// CHECK:         %[[N:.*]] = yul.constant 3{{$}}
// CHECK:         yul.for
// CHECK:           yul.cmp ult, %{{.*}}, %[[N]]
// CHECK:           yul.sstore
// CHECK:         } {full_unroll}
// CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
// CHECK:         %[[LSLOT:.*]] = yul.add %arg0, %[[C3]]
// CHECK:         %[[LEN:.*]] = yul.sload %[[LSLOT]]
// CHECK:         yul.sstore %[[LSLOT]], %{{.*}}
// CHECK:         yul.if
// CHECK:           yul.keccak256
// CHECK:           yul.for
// CHECK:             yul.sstore
// CHECK:         %[[C5:.*]] = yul.constant 5{{$}}
// CHECK:         %[[OSLOT:.*]] = yul.add %arg0, %[[C5]]
// CHECK:         yul.sstore %[[OSLOT]], %{{.*}}
// CHECK-NOT:     yul.sstore
// CHECK:         yul.func_return

// 2**64 uint8 elements pack into 2**59 slots.
// CHECK-LABEL: yul.func @hugePacked : (i256) -> ()
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
// CHECK:         %[[N:.*]] = yul.constant 576460752303423488
// CHECK:         yul.for
// CHECK:           yul.cmp ult, %{{.*}}, %[[N]]
// CHECK:         } body {
// CHECK:           %[[P:.*]] = yul.add %[[A]], %{{.*}}
// CHECK:           yul.sstore %[[P]], %{{.*}}
// CHECK:         } step {

// CHECK-LABEL: yul.func @hugeStr : (i256) -> ()
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
// CHECK:         %[[N:.*]] = yul.constant 18446744073709551616
// CHECK:         yul.for
// CHECK:           yul.cmp ult, %{{.*}}, %[[N]]
// CHECK:         } body {
// CHECK:           %[[P:.*]] = yul.add %[[A]], %{{.*}}
// CHECK:           yul.func_call @__sol.clear_string_tail(%[[P]],
// CHECK:           yul.sstore %[[P]], %{{.*}}
// CHECK:         } step {

// The member after the 2**64-slot array sits at slot 2**64 + 1.
// CHECK-LABEL: yul.func @hugeStructMember : (i256) -> ()
// CHECK-NEXT:  ^bb0(%[[S:.*]]: i256):
// CHECK:         %[[X:.*]] = yul.add %[[S]]
// CHECK:         yul.sstore %[[X]], %{{.*}}
// CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
// CHECK:         %[[ARR:.*]] = yul.add %[[S]], %[[C1]]
// CHECK:         %[[N:.*]] = yul.constant 18446744073709551616
// CHECK:         yul.for
// CHECK:           yul.cmp ult, %{{.*}}, %[[N]]
// CHECK:         } body {
// CHECK:           %[[P:.*]] = yul.add %[[ARR]], %{{.*}}
// CHECK:           yul.sstore %[[P]], %{{.*}}
// CHECK:         } step {
// CHECK:         %[[YOFF:.*]] = yul.constant 18446744073709551617
// CHECK:         %[[Y:.*]] = yul.add %[[S]], %[[YOFF]]
// CHECK:         yul.sstore %[[Y]], %{{.*}}

sol.func @fixedMapArr(%a: !sol.array<3 x !sol.mapping<ui256, ui256>, Storage>) {
  sol.delete %a : !sol.array<3 x !sol.mapping<ui256, ui256>, Storage>
  sol.return
}

sol.func @mapArr(%a: !sol.array<? x !sol.mapping<ui256, ui256>, Storage>) {
  sol.delete %a : !sol.array<? x !sol.mapping<ui256, ui256>, Storage>
  sol.return
}

sol.func @mapArr2D(%a: !sol.array<? x !sol.array<? x !sol.mapping<ui256, ui256>, Storage>, Storage>) {
  sol.delete %a : !sol.array<? x !sol.array<? x !sol.mapping<ui256, ui256>, Storage>, Storage>
  sol.return
}

sol.func @withMapArr(%a: !sol.array<? x !sol.struct<(ui256, !sol.mapping<ui256, ui256>), Storage>, Storage>) {
  sol.delete %a : !sol.array<? x !sol.struct<(ui256, !sol.mapping<ui256, ui256>), Storage>, Storage>
  sol.return
}

sol.func @mixedStruct(%a: !sol.struct<(!sol.array<3 x ui256, Storage>, !sol.array<? x ui256, Storage>, !sol.mapping<ui256, ui256>, !sol.address, i1), Storage>) {
  sol.delete %a : !sol.struct<(!sol.array<3 x ui256, Storage>, !sol.array<? x ui256, Storage>, !sol.mapping<ui256, ui256>, !sol.address, i1), Storage>
  sol.return
}

sol.func @hugePacked(%a: !sol.array<18446744073709551616 x ui8, Storage>) {
  sol.delete %a : !sol.array<18446744073709551616 x ui8, Storage>
  sol.return
}

sol.func @hugeStr(%a: !sol.array<18446744073709551616 x !sol.string<Storage>, Storage>) {
  sol.delete %a : !sol.array<18446744073709551616 x !sol.string<Storage>, Storage>
  sol.return
}

sol.func @hugeStructMember(%s: !sol.struct<(ui256, !sol.array<18446744073709551616 x ui256, Storage>, ui256), Storage>) {
  sol.delete %s : !sol.struct<(ui256, !sol.array<18446744073709551616 x ui256, Storage>, ui256), Storage>
  sol.return
}
