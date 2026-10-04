// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @dyn_u256 : () -> i256
// CHECK:         %[[SLOT:.*]] = yul.constant 0{{$}}
// CHECK:         %[[OFF:.*]] = yul.sub
// CHECK:         yul.mstore %{{.*}}, %[[OFF]]
// CHECK:         %[[LEN:.*]] = yul.sload %[[SLOT]]
// CHECK:         yul.mstore %{{.*}}, %[[SLOT]]
// CHECK:         %[[DATA:.*]] = yul.keccak256
// CHECK:         yul.mstore %{{.*}}, %[[LEN]]
// CHECK:         yul.for %{{.*}}, %{{.*}}, %[[DATA]] :
// CHECK:           yul.cmp ult, %{{.*}}, %[[LEN]]
// CHECK:           %[[W:.*]] = yul.sload
// CHECK:           yul.mstore %{{.*}}, %[[W]]

// uint8 elements are unpacked from the slot and padded to 32 bytes.
// CHECK-LABEL: yul.func @static_u8x4 : () -> i256
// CHECK:         %[[SLOT:.*]] = yul.constant 1{{$}}
// CHECK:         %[[C128:.*]] = yul.constant 128
// CHECK:         yul.add %{{.*}}, %[[C128]]
// CHECK:         %[[LEN:.*]] = yul.constant 4{{$}}
// CHECK:         yul.cmp uge, %[[LEN]], %{{.*}}
// CHECK:         yul.for %{{.*}}, %{{.*}}, %[[SLOT]], %{{.*}} :
// CHECK:           %[[W:.*]] = yul.sload
// CHECK:           yul.for
// CHECK:             %[[SH:.*]] = yul.arith_shr %[[W]], %{{.*}}
// CHECK:             %[[M:.*]] = yul.constant 255
// CHECK:             %[[V:.*]] = yul.and %[[SH]], %[[M]]
// CHECK:             yul.mstore
// CHECK:             %[[C8:.*]] = yul.constant 8{{$}}
// CHECK:             yul.add %{{.*}}, %[[C8]]
// CHECK:         %[[T:.*]] = yul.cmp ult, %{{.*}}, %[[LEN]]
// CHECK:         yul.if %[[T]] -> i256 {
// CHECK:           %[[TW:.*]] = yul.sload
// CHECK:             yul.arith_shr %[[TW]], %{{.*}}
// CHECK:         } {full_unroll}

// CHECK-LABEL: yul.func @dyn_u256x2 : () -> i256
// CHECK:         %[[SLOT:.*]] = yul.constant 10{{$}}
// CHECK:         %[[LEN:.*]] = yul.sload %[[SLOT]]
// CHECK:         %[[DATA:.*]] = yul.keccak256
// CHECK:         %[[C64:.*]] = yul.constant 64{{$}}
// CHECK:         yul.mul %[[LEN]], %[[C64]]
// CHECK:         %[[SSTEP:.*]] = yul.constant 2{{$}}
// CHECK:         yul.for %{{.*}}, %{{.*}}, %[[DATA]], %{{.*}} :
// CHECK:           yul.for
// CHECK:             yul.sload
// CHECK:           yul.add %{{.*}}, %[[SSTEP]]

// Each dynamic element's data sits at keccak256 of its own slot.
// CHECK-LABEL: yul.func @static2_dyn_u256 : () -> i256
// CHECK:         %[[SLOT:.*]] = yul.constant 11{{$}}
// CHECK:         yul.for %{{.*}}, %{{.*}}, %[[SLOT]], %{{.*}} :
// CHECK:           %[[OFF:.*]] = yul.sub
// CHECK:           yul.mstore %{{.*}}, %[[OFF]]
// CHECK:           %[[ILEN:.*]] = yul.sload %[[ES:.*]]
// CHECK:           yul.mstore %{{.*}}, %[[ES]]
// CHECK:           %[[IDATA:.*]] = yul.keccak256
// CHECK:           yul.mstore %{{.*}}, %[[ILEN]]
// CHECK:           yul.for %{{.*}}, %{{.*}}, %[[IDATA]] :
// CHECK:             yul.sload

// A static struct array is encoded in place; each struct reads slots +0
// and +1 and advances by 2 slots.
// CHECK-LABEL: yul.func @static2_pair : () -> i256
// CHECK:         %[[SLOT:.*]] = yul.constant 14{{$}}
// CHECK:         %[[C128:.*]] = yul.constant 128
// CHECK:         %[[TAIL:.*]] = yul.add %{{.*}}, %[[C128]]
// CHECK:         %[[SSTEP:.*]] = yul.constant 2{{$}}
// CHECK:         yul.for %{{.*}}, %{{.*}}, %[[SLOT]], %[[TAIL]] :
// CHECK:           %[[F0:.*]] = yul.sload
// CHECK:           yul.mstore %{{.*}}, %[[F0]]
// CHECK:           %[[ONE:.*]] = yul.constant 1{{$}}
// CHECK:           %[[S1:.*]] = yul.add %{{.*}}, %[[ONE]]
// CHECK:           %[[F1:.*]] = yul.sload %[[S1]]
// CHECK:           yul.mstore %{{.*}}, %[[F1]]
// CHECK:           yul.add %{{.*}}, %[[SSTEP]]

// Dynamic arrays read the length from the slot and the data from
// keccak256(slot); packed mode stores no length prefix. Two uint128 per
// slot, shifted by 128 bits.
// CHECK-LABEL: yul.func @packed_dyn_u128 : () -> i256
// CHECK:         %[[SLOT:.*]] = yul.constant 18{{$}}
// CHECK:         %[[LEN:.*]] = yul.sload %[[SLOT]]{{$}}
// CHECK:         yul.mstore %{{.*}}, %[[SLOT]]
// CHECK:         %[[DATA:.*]] = yul.keccak256
// CHECK-NOT:     yul.mstore %{{.*}}, %[[LEN]]
// CHECK:         %[[PER:.*]] = yul.constant 2{{$}}
// CHECK:         yul.cmp uge, %[[LEN]], %[[PER]]
// CHECK:         yul.for %{{.*}}, %{{.*}}, %[[DATA]], %{{.*}} :
// CHECK:           %[[W:.*]] = yul.sload
// CHECK:           yul.for
// CHECK:             %[[SH:.*]] = yul.arith_shr %[[W]], %{{.*}}
// CHECK:             %[[M:.*]] = yul.constant 340282366920938463463374607431768211455
// CHECK:             yul.and %[[SH]], %[[M]]
// CHECK:             %[[C128:.*]] = yul.constant 128
// CHECK:             yul.add %{{.*}}, %[[C128]]
// CHECK:         yul.cmp ult, %{{.*}}, %[[LEN]]
// CHECK:         yul.if %{{.*}} -> i256 {

// Packed elements are unpacked per slot (whole slots, then the tail slot)
// and each is padded to 32 bytes.
// CHECK-LABEL: yul.func @packed_static_u8x33 : () -> i256
// CHECK:         %[[SLOT:.*]] = yul.constant 19{{$}}
// CHECK:         %[[LEN:.*]] = yul.constant 33{{$}}
// CHECK:         yul.mul %[[LEN]], %{{.*}}
// CHECK:         %[[PER:.*]] = yul.constant 32{{$}}
// CHECK:         yul.cmp uge, %[[LEN]], %[[PER]]
// CHECK:         yul.for %{{.*}}, %{{.*}}, %[[SLOT]], %{{.*}} :
// CHECK:           %[[W:.*]] = yul.sload
// CHECK:           yul.for
// CHECK:             %[[SH:.*]] = yul.arith_shr %[[W]], %{{.*}}
// CHECK:             %[[M:.*]] = yul.constant 255
// CHECK:             %[[V:.*]] = yul.and %[[SH]], %[[M]]
// CHECK:             yul.mstore
// CHECK:             %[[C8:.*]] = yul.constant 8{{$}}
// CHECK:             yul.add %{{.*}}, %[[C8]]
// CHECK:         %[[TAIL:.*]] = yul.cmp ult, %{{.*}}, %[[LEN]]
// CHECK:         yul.if %[[TAIL]] -> i256 {
// CHECK:           %[[TW:.*]] = yul.sload
// CHECK:           yul.arith_shr %[[TW]], %{{.*}}
// CHECK:         } {full_unroll}

// 16 uint16 share a slot: whole slots first, then the partial tail slot.
// CHECK-LABEL: yul.func @packed_nested_u16 : () -> i256
// CHECK:         yul.for
// CHECK:         } body {
// CHECK:           %[[PER:.*]] = yul.constant 16
// CHECK:           yul.cmp uge, %{{.*}}, %[[PER]]
// CHECK:           yul.for
// CHECK:             %[[W:.*]] = yul.sload
// CHECK:             yul.for
// CHECK:               %[[SH:.*]] = yul.arith_shr %[[W]], %{{.*}}
// CHECK:               %[[M:.*]] = yul.constant 65535
// CHECK:               yul.and %[[SH]], %[[M]]
// CHECK:               yul.mstore
// CHECK:           yul.if %{{.*}} -> i256 {
// CHECK:             %[[TW:.*]] = yul.sload
// CHECK:             yul.for
// CHECK:               yul.arith_shr %[[TW]], %{{.*}}
// CHECK:               yul.mstore
// CHECK:             } {full_unroll}

// Storage slots advance by 1, 4 and 20 per nesting level.
// CHECK-LABEL: yul.func @packed_nested_u256 : () -> i256
// CHECK:         %[[SLOT:.*]] = yul.constant 24{{$}}
// CHECK:         %[[C640:.*]] = yul.constant 640
// CHECK:         yul.mul %{{.*}}, %[[C640]]
// CHECK:         %[[OSTEP:.*]] = yul.constant 20
// CHECK:         yul.for %{{.*}}, %{{.*}}, %[[SLOT]] :
// CHECK:           %[[MSTEP:.*]] = yul.constant 4{{$}}
// CHECK:           yul.for
// CHECK:             %[[ISTEP:.*]] = yul.constant 1{{$}}
// CHECK:             yul.for
// CHECK:               %[[W:.*]] = yul.sload
// CHECK:               yul.mstore %{{.*}}, %[[W]]
// CHECK:               yul.add %{{.*}}, %[[ISTEP]]
// CHECK:             yul.add %{{.*}}, %[[MSTEP]]
// CHECK:         yul.add %{{.*}}, %[[OSTEP]]

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @dyn256 slot 0 offset 0 : !sol.array<? x ui256, Storage>
    sol.state_var @static8x4 slot 1 offset 0 : !sol.array<4 x ui8, Storage>
    sol.state_var @dynRefStatic2x slot 10 offset 0 : !sol.array<? x !sol.array<2 x ui256, Storage>, Storage>
    sol.state_var @staticRefDyn256x2 slot 11 offset 0 : !sol.array<2 x !sol.array<? x ui256, Storage>, Storage>
    sol.state_var @staticStructPair2 slot 14 offset 0 : !sol.array<2 x !sol.struct<(ui256, ui256), Storage>, Storage>
    sol.state_var @dyn128 slot 18 offset 0 : !sol.array<? x ui128, Storage>
    sol.state_var @static8x33 slot 19 offset 0 : !sol.array<33 x ui8, Storage>
    sol.state_var @nestedU16 slot 21 offset 0 : !sol.array<3 x !sol.array<2 x ui16, Storage>, Storage>
    sol.state_var @nestedU256 slot 24 offset 0 : !sol.array<4 x !sol.array<5 x !sol.array<4 x ui256, Storage>, Storage>, Storage>
    sol.func @packed_nested_u256() -> !sol.string<Memory> {
      %0 = sol.addr_of @nestedU256 : !sol.array<4 x !sol.array<5 x !sol.array<4 x ui256, Storage>, Storage>, Storage>
      %1 = sol.encode %0 : !sol.array<4 x !sol.array<5 x !sol.array<4 x ui256, Storage>, Storage>, Storage> : !sol.string<Memory> {packed}
      sol.return %1 : !sol.string<Memory>
    }
    sol.func @packed_nested_u16() -> !sol.string<Memory> {
      %0 = sol.addr_of @nestedU16 : !sol.array<3 x !sol.array<2 x ui16, Storage>, Storage>
      %1 = sol.encode %0 : !sol.array<3 x !sol.array<2 x ui16, Storage>, Storage> : !sol.string<Memory> {packed}
      sol.return %1 : !sol.string<Memory>
    }
    sol.func @packed_static_u8x33() -> !sol.string<Memory> {
      %0 = sol.addr_of @static8x33 : !sol.array<33 x ui8, Storage>
      %1 = sol.encode %0 : !sol.array<33 x ui8, Storage> : !sol.string<Memory> {packed}
      sol.return %1 : !sol.string<Memory>
    }
    sol.func @packed_dyn_u128() -> !sol.string<Memory> {
      %0 = sol.addr_of @dyn128 : !sol.array<? x ui128, Storage>
      %1 = sol.encode %0 : !sol.array<? x ui128, Storage> : !sol.string<Memory> {packed}
      sol.return %1 : !sol.string<Memory>
    }
    sol.func @static2_pair() -> !sol.string<Memory> {
      %0 = sol.addr_of @staticStructPair2 : !sol.array<2 x !sol.struct<(ui256, ui256), Storage>, Storage>
      %1 = sol.encode %0 : !sol.array<2 x !sol.struct<(ui256, ui256), Storage>, Storage> : !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
    sol.func @static2_dyn_u256() -> !sol.string<Memory> {
      %0 = sol.addr_of @staticRefDyn256x2 : !sol.array<2 x !sol.array<? x ui256, Storage>, Storage>
      %1 = sol.encode %0 : !sol.array<2 x !sol.array<? x ui256, Storage>, Storage> : !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
    sol.func @dyn_u256x2() -> !sol.string<Memory> {
      %0 = sol.addr_of @dynRefStatic2x : !sol.array<? x !sol.array<2 x ui256, Storage>, Storage>
      %1 = sol.encode %0 : !sol.array<? x !sol.array<2 x ui256, Storage>, Storage> : !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
    sol.func @static_u8x4() -> !sol.string<Memory> {
      %0 = sol.addr_of @static8x4 : !sol.array<4 x ui8, Storage>
      %1 = sol.encode %0 : !sol.array<4 x ui8, Storage> : !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
    sol.func @dyn_u256() -> !sol.string<Memory> {
      %0 = sol.addr_of @dyn256 : !sol.array<? x ui256, Storage>
      %1 = sol.encode %0 : !sol.array<? x ui256, Storage> : !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract}
}
