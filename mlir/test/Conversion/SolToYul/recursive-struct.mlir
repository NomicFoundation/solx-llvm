// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// S is two slots (a, b); each copy or clear of the S[] field recurses per
// element at keccak(slot of b) + 2 * i.

// CHECK-LABEL: yul.func @stoToSto : (i256, i256) -> ()
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK:         %[[NE:.*]] = yul.cmp ne, %[[A]], %[[B]]
// CHECK:         yul.if %[[NE]] {
// CHECK:           yul.func_call @__sol.copy.storage.storage.S(%[[A]], %[[B]]) : (i256, i256) -> ()

// CHECK-LABEL: yul.func @stoToMem : (i256) -> i256
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
// CHECK:         %[[R:.*]] = yul.func_call @__sol.copy.storage.memory.S(%[[A]]) : (i256) -> i256
// CHECK:         yul.func_return %[[R]]

// CHECK-LABEL: yul.func @memToSto : (i256, i256) -> ()
// CHECK-NEXT:  ^bb0(%[[M:.*]]: i256, %[[S:.*]]: i256):
// CHECK:         yul.func_call @__sol.copy.memory.storage.S(%[[M]], %[[S]]) : (i256, i256) -> ()

// CHECK-LABEL: yul.func @del : (i256) -> ()
// CHECK-NEXT:  ^bb0(%[[S:.*]]: i256):
// CHECK:         yul.func_call @__sol.clear_storage.S(%[[S]]) : (i256) -> ()

// CHECK-LABEL: yul.func @stoToStoPacked : (i256, i256) -> ()
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
// CHECK:         yul.func_call @__sol.copy.storage.storage.P(%[[A]], %[[B]]) : (i256, i256) -> ()

// CHECK-LABEL: yul.func @delMutual : (i256) -> ()
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
// CHECK:         yul.func_call @__sol.clear_storage.A(%[[A]]) : (i256) -> ()

// CHECK-LABEL: yul.func @delMapping : (i256) -> ()
// CHECK-NEXT:  ^bb0(%[[M:.*]]: i256):
// CHECK:         yul.func_call @__sol.clear_storage.M(%[[M]]) : (i256) -> ()

// CHECK-LABEL: yul.func @__sol.copy.storage.storage.S : (i256, i256) -> ()
// CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
// CHECK:         %[[SB:.*]] = yul.add %arg0, %[[C1]]
// CHECK:         %[[C1D:.*]] = yul.constant 1{{$}}
// CHECK:         %[[DB:.*]] = yul.add %arg1, %[[C1D]]
// CHECK:         %[[NE:.*]] = yul.cmp ne, %[[SB]], %[[DB]]
// CHECK:         yul.if %[[NE]] {
// CHECK:           %[[LEN:.*]] = yul.sload %[[SB]]
// CHECK:           yul.sstore %[[DB]], %[[LEN]]
// CHECK:           yul.func_call @__sol.clear_storage.S(
// CHECK:           yul.for
// CHECK:             yul.func_call @__sol.copy.storage.storage.S(%{{.*}}, %{{.*}}) : (i256, i256) -> ()

// CHECK-LABEL: yul.func @__sol.clear_storage.S : (i256) -> ()
// CHECK:         %[[C0:.*]] = yul.constant 0{{$}}
// CHECK:         %[[ASLOT:.*]] = yul.add %arg0, %[[C0]]
// CHECK:         yul.sstore %[[ASLOT]], %{{.*}}
// CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
// CHECK:         %[[BSLOT:.*]] = yul.add %arg0, %[[C1]]
// CHECK:         %[[LEN:.*]] = yul.sload %[[BSLOT]]
// CHECK:         yul.sstore %[[BSLOT]], %{{.*}}
// CHECK:         %[[NONEMPTY:.*]] = yul.cmp ult, %{{.*}}, %[[LEN]]
// CHECK:         yul.if %[[NONEMPTY]] {
// CHECK:           yul.mstore %{{.*}}, %[[BSLOT]]
// CHECK:           %[[DATA:.*]] = yul.keccak256
// CHECK:           yul.mul %[[LEN]], %{{.*}}
// CHECK:           %[[STRIDE:.*]] = yul.constant 2{{$}}
// CHECK-NEXT:      yul.for
// CHECK:           } body {
// CHECK:             %[[ELT:.*]] = yul.add %{{.*}}, %arg1
// CHECK:             yul.func_call @__sol.clear_storage.S(%[[ELT]]) : (i256) -> ()
// CHECK:           } step {
// CHECK:             yul.add %arg1, %[[STRIDE]]

// CHECK-LABEL: yul.func @__sol.copy.storage.memory.S : (i256) -> i256
// CHECK:         %[[M:.*]] = yul.mload
// CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
// CHECK:         %[[BSLOT:.*]] = yul.add %arg0, %[[C1]]
// CHECK:         %[[LEN:.*]] = yul.sload %[[BSLOT]]
// CHECK:         yul.mstore %{{.*}}, %[[BSLOT]]
// CHECK:         %[[DATA:.*]] = yul.keccak256
// CHECK:         yul.for
// CHECK:           %[[C2:.*]] = yul.constant 2{{$}}
// CHECK:           %[[OFF:.*]] = yul.mul %arg1, %[[C2]]
// CHECK:           %[[SRC:.*]] = yul.add %[[DATA]], %[[OFF]]
// CHECK:           %[[ELT:.*]] = yul.func_call @__sol.copy.storage.memory.S(%[[SRC]]) : (i256) -> i256
// CHECK:           yul.mstore %{{.*}}, %[[ELT]]
// CHECK:         yul.func_return %[[M]] : i256

// CHECK-LABEL: yul.func @__sol.copy.memory.storage.S : (i256, i256) -> ()
// CHECK:         yul.mload %arg0
// CHECK:         %[[AV:.*]] = yul.or %{{.*}}, %{{.*}}
// CHECK:         yul.sstore %{{.*}}, %[[AV]]
// CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
// CHECK:         %[[BSLOT:.*]] = yul.add %arg1, %[[C1]]
// CHECK:         %[[LEN:.*]] = yul.mload
// CHECK:         %[[OLDLEN:.*]] = yul.sload %[[BSLOT]]
// CHECK:         yul.sstore %[[BSLOT]], %[[LEN]]
// CHECK:         %[[SHRINK:.*]] = yul.cmp ult, %[[LEN]], %[[OLDLEN]]
// CHECK:         yul.if %[[SHRINK]] {
// CHECK:           yul.for
// CHECK:             yul.func_call @__sol.clear_storage.S(
// CHECK:         yul.mstore %{{.*}}, %[[BSLOT]]
// CHECK:         %[[DATA:.*]] = yul.keccak256
// CHECK:         yul.for
// CHECK:           %[[C2:.*]] = yul.constant 2{{$}}
// CHECK:           %[[OFF:.*]] = yul.mul %arg2, %[[C2]]
// CHECK:           %[[DST:.*]] = yul.add %[[DATA]], %[[OFF]]
// CHECK:           %[[SRC:.*]] = yul.mload
// CHECK:           yul.func_call @__sol.copy.memory.storage.S(%[[SRC]], %[[DST]]) : (i256, i256) -> ()

// P's v (bits 0-15) and w (bits 16-47) share slot 0. They are repacked and
// merged into the destination slot, preserving its bits above 48.
// CHECK-LABEL: yul.func @__sol.copy.storage.storage.P : (i256, i256) -> ()
// CHECK:         %[[SRC:.*]] = yul.sload
// CHECK:         %[[V:.*]] = yul.and %[[SRC]], %c65535_i256
// CHECK:         %[[VP:.*]] = yul.or %c0_i256{{.*}}, %[[V]]
// CHECK:         %[[WS:.*]] = yul.arith_shr %[[SRC]], %c16_i256
// CHECK:         %[[W:.*]] = yul.and %[[WS]], %c4294967295_i256
// CHECK:         %[[WP:.*]] = yul.arith_shl %[[W]], %c16_i256
// CHECK:         %[[VWP:.*]] = yul.or %[[VP]], %[[WP]]
// CHECK:         %[[DSLOT:.*]] = yul.add %arg1, %c0_i256
// CHECK:         %[[DST:.*]] = yul.sload %[[DSLOT]]
// CHECK:         %[[KEEP:.*]] = yul.and %[[DST]], %c-281474976710656_i256
// CHECK:         %[[NEW:.*]] = yul.or %[[KEEP]], %[[VWP]]
// CHECK:         yul.sstore %[[DSLOT]], %[[NEW]]
// CHECK:         yul.for
// CHECK:           yul.func_call @__sol.copy.storage.storage.P(%{{.*}}, %{{.*}}) : (i256, i256) -> ()

// A's array field holds Bs and B's holds As: each clear helper recurses into
// the other's.
// CHECK-LABEL: yul.func @__sol.clear_storage.A : (i256) -> ()
// CHECK:         yul.for
// CHECK:           yul.func_call @__sol.clear_storage.B(%{{.*}}) : (i256) -> ()

// CHECK-LABEL: yul.func @__sol.clear_storage.B : (i256) -> ()
// CHECK:         yul.for
// CHECK:           yul.func_call @__sol.clear_storage.A(%{{.*}}) : (i256) -> ()

// Delete stops at the mapping: only the scalar's slot is cleared, no
// recursion.
// CHECK-LABEL: yul.func @__sol.clear_storage.M : (i256) -> ()
// CHECK:         %[[SLOT:.*]] = yul.add %arg0, %c0_i256
// CHECK:         yul.sstore %[[SLOT]], %c0_i256
// CHECK-NOT:     yul.func_call
// CHECK:         yul.func_return

!S =!sol.struct<"S", Storage, (ui256, !sol.array<? x !sol.struct<"S", Storage>, Storage>)>
!Smem = !sol.struct<"S", Memory, (ui256, !sol.array<? x !sol.struct<"S", Memory>, Memory>)>
!P = !sol.struct<"P", Storage, (ui16, ui32, !sol.array<? x !sol.struct<"P", Storage>, Storage>)>
!A = !sol.struct<"A", Storage, (ui256, !sol.array<? x !sol.struct<"B", Storage, (ui256, !sol.array<? x !sol.struct<"A", Storage>, Storage>)>, Storage>)>
!M = !sol.struct<"M", Storage, (ui32, !sol.mapping<ui8, !sol.struct<"M", Storage>>)>
#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @stoToSto(%a: !S, %b: !S) {
    sol.copy %a, %b : !S, !S
    sol.return
  }
  sol.func @stoToMem(%a: !S) -> !Smem {
    %0 = sol.data_loc_cast %a : !S, !Smem
    sol.return %0 : !Smem
  }
  sol.func @memToSto(%m: !Smem, %s: !S) {
    sol.copy %m, %s : !Smem, !S
    sol.return
  }
  sol.func @del(%s: !S) {
    sol.delete %s : !S
    sol.return
  }
  sol.func @stoToStoPacked(%a: !P, %b: !P) {
    sol.copy %a, %b : !P, !P
    sol.return
  }
  sol.func @delMutual(%a: !A) {
    sol.delete %a : !A
    sol.return
  }
  sol.func @delMapping(%m: !M) {
    sol.delete %m : !M
    sol.return
  }
}
