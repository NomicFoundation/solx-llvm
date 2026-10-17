// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// S is two slots (a, b); each copy or clear of the S[] field recurses per
// element at keccak(slot of b) + 2 * i.

!S =!sol.struct<"S", Storage, (ui256, !sol.array<? x !sol.struct<"S", Storage>, Storage>)>
module {
  sol.contract @C {
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

    // CHECK-LABEL: yul.func @stoToSto : (i256, i256) -> ()
    // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
    // CHECK:         %[[NE:.*]] = yul.cmp ne, %[[A]], %[[B]]
    // CHECK:         yul.if %[[NE]] {
    // CHECK:           yul.func_call @__sol.copy.storage.storage.S(%[[A]], %[[B]]) : (i256, i256) -> ()
    sol.func @stoToSto(%a: !S, %b: !S) {
      sol.copy %a, %b : !S, !S
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

!S =!sol.struct<"S", Storage, (ui256, !sol.array<? x !sol.struct<"S", Storage>, Storage>)>
!Smem = !sol.struct<"S", Memory, (ui256, !sol.array<? x !sol.struct<"S", Memory>, Memory>)>
module {
  sol.contract @C {
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

    // CHECK-LABEL: yul.func @stoToMem : (i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
    // CHECK:         %[[R:.*]] = yul.func_call @__sol.copy.storage.memory.S(%[[A]]) : (i256) -> i256
    // CHECK:         yul.func_return %[[R]]
    sol.func @stoToMem(%a: !S) -> !Smem {
      %0 = sol.data_loc_cast %a : !S, !Smem
      sol.return %0 : !Smem
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

!S =!sol.struct<"S", Storage, (ui256, !sol.array<? x !sol.struct<"S", Storage>, Storage>)>
!Smem = !sol.struct<"S", Memory, (ui256, !sol.array<? x !sol.struct<"S", Memory>, Memory>)>
module {
  sol.contract @C {
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

    // CHECK-LABEL: yul.func @memToSto : (i256, i256) -> ()
    // CHECK-NEXT:  ^bb0(%[[M:.*]]: i256, %[[S:.*]]: i256):
    // CHECK:         yul.func_call @__sol.copy.memory.storage.S(%[[M]], %[[S]]) : (i256, i256) -> ()
    sol.func @memToSto(%m: !Smem, %s: !S) {
      sol.copy %m, %s : !Smem, !S
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

!S =!sol.struct<"S", Storage, (ui256, !sol.array<? x !sol.struct<"S", Storage>, Storage>)>
module {
  sol.contract @C {
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

    // CHECK-LABEL: yul.func @del : (i256) -> ()
    // CHECK-NEXT:  ^bb0(%[[S:.*]]: i256):
    // CHECK:         yul.func_call @__sol.clear_storage.S(%[[S]]) : (i256) -> ()
    sol.func @del(%s: !S) {
      sol.delete %s : !S
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

!P = !sol.struct<"P", Storage, (ui16, ui32, !sol.array<? x !sol.struct<"P", Storage>, Storage>)>
module {
  sol.contract @C {
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

    // CHECK-LABEL: yul.func @stoToStoPacked : (i256, i256) -> ()
    // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
    // CHECK:         yul.func_call @__sol.copy.storage.storage.P(%[[A]], %[[B]]) : (i256, i256) -> ()
    sol.func @stoToStoPacked(%a: !P, %b: !P) {
      sol.copy %a, %b : !P, !P
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

!A = !sol.struct<"A", Storage, (ui256, !sol.array<? x !sol.struct<"B", Storage, (ui256, !sol.array<? x !sol.struct<"A", Storage>, Storage>)>, Storage>)>
module {
  sol.contract @C {
    // A's array field holds Bs and B's holds As: each clear helper recurses into
    // the other's.
    // CHECK-LABEL: yul.func @__sol.clear_storage.B : (i256) -> ()
    // CHECK:         yul.for
    // CHECK:           yul.func_call @__sol.clear_storage.A(%{{.*}}) : (i256) -> ()

    // CHECK-LABEL: yul.func @__sol.clear_storage.A : (i256) -> ()
    // CHECK:         yul.for
    // CHECK:           yul.func_call @__sol.clear_storage.B(%{{.*}}) : (i256) -> ()

    // CHECK-LABEL: yul.func @delMutual : (i256) -> ()
    // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
    // CHECK:         yul.func_call @__sol.clear_storage.A(%[[A]]) : (i256) -> ()
    sol.func @delMutual(%a: !A) {
      sol.delete %a : !A
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

!M = !sol.struct<"M", Storage, (ui32, !sol.mapping<ui8, !sol.struct<"M", Storage>>)>
module {
  sol.contract @C {
    // Delete stops at the mapping: only the scalar is cleared, masked in its
    // slot, no recursion.
    // CHECK-LABEL: yul.func @__sol.clear_storage.M : (i256) -> ()
    // CHECK:         %[[SLOT:.*]] = yul.add %arg0, %c0_i256
    // CHECK:         %[[OLD:.*]] = yul.sload %[[SLOT]]
    // CHECK:         %[[KEEP:.*]] = yul.and %[[OLD]], %c-4294967296_i256
    // CHECK:         yul.sstore %[[SLOT]], %[[KEEP]]
    // CHECK-NOT:     yul.func_call
    // CHECK:         yul.func_return

    // CHECK-LABEL: yul.func @delMapping : (i256) -> ()
    // CHECK-NEXT:  ^bb0(%[[M:.*]]: i256):
    // CHECK:         yul.func_call @__sol.clear_storage.M(%[[M]]) : (i256) -> ()
    sol.func @delMapping(%m: !M) {
      sol.delete %m : !M
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

!R = !sol.struct<"R", CallData, (ui256, !sol.array<? x !sol.struct<"R", CallData>, CallData>)>
!Rmem = !sol.struct<"R", Memory, (ui256, !sol.array<? x !sol.struct<"R", Memory>, Memory>)>
module {
  sol.contract @C {
    // The calldata copy decodes R against the end of calldata, calling itself
    // per element of the array member.
    // CHECK-LABEL: yul.func @__sol.abi_decode.calldata.R : (i256, i256) -> i256
    // CHECK:         %[[M:.*]] = yul.mload
    // CHECK:         %[[A:.*]] = yul.calldataload %arg0
    // CHECK-NEXT:    yul.mstore %[[M]], %[[A]]
    // CHECK:         %[[OFF:.*]] = yul.calldataload
    // CHECK:         %[[TAIL:.*]] = yul.add %arg0, %[[OFF]]
    // CHECK:         %[[LEN:.*]] = yul.calldataload %[[TAIL]]
    // CHECK:         yul.mstore %{{.*}}, %[[LEN]]
    // CHECK-NEXT:    yul.constant 32
    // CHECK-NEXT:    %[[SPAN:.*]] = yul.mul %[[LEN]]
    // CHECK-NEXT:    %[[END:.*]] = yul.add %{{.*}}, %[[SPAN]]
    // CHECK-NEXT:    yul.cmp ugt, %[[END]], %arg1
    // CHECK:         yul.for
    // CHECK:           %[[C64:.*]] = yul.constant 64
    // CHECK-NEXT:      %[[HEADEND:.*]] = yul.add %{{.*}}, %[[C64]]
    // CHECK-NEXT:      yul.cmp ugt, %[[HEADEND]], %arg1
    // CHECK:           %[[ELT:.*]] = yul.func_call @__sol.abi_decode.calldata.R(%{{.*}}, %arg1) : (i256, i256) -> i256
    // CHECK-NEXT:      yul.mstore %{{.*}}, %[[ELT]]
    // CHECK:         yul.func_return %[[M]]

    // CHECK-LABEL: yul.func @cdToMem : (i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[R:.*]]: i256):
    // CHECK:         %[[CDS:.*]] = yul.calldatasize
    // CHECK-NEXT:    %[[C64:.*]] = yul.constant 64
    // CHECK-NEXT:    %[[HEADEND:.*]] = yul.add %[[R]], %[[C64]]
    // CHECK-NEXT:    yul.cmp ugt, %[[HEADEND]], %[[CDS]]
    // CHECK:         yul.revert
    // CHECK:         %[[M:.*]] = yul.func_call @__sol.abi_decode.calldata.R(%[[R]], %[[CDS]]) : (i256, i256) -> i256
    // CHECK:         yul.func_return %[[M]]
    sol.func @cdToMem(%r: !R) -> !Rmem {
      %0 = sol.data_loc_cast %r : !R, !Rmem
      sol.return %0 : !Rmem
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
