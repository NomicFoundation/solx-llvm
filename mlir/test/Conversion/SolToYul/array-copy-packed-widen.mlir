// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// uint160 needs a slot each: every uint8 is unpacked into its own slot.
// CHECK-LABEL: yul.func @s2s_u8_u160_d_91 : () -> ()
// CHECK:         %[[SRC:.*]] = yul.constant 16{{$}}
// CHECK:         %[[DST:.*]] = yul.constant 17{{$}}
// CHECK:         %[[LEN:.*]] = yul.sload %[[SRC]]
// CHECK:         yul.sstore %[[DST]], %[[LEN]]
// CHECK:         yul.for
// CHECK:           %[[W:.*]] = yul.sload
// CHECK:           yul.for
// CHECK:             %[[E:.*]] = yul.arith_shr %[[W]], %{{.*}}
// CHECK:             %[[SH:.*]] = yul.arith_shl %[[E]], %{{.*}}
// CHECK:             %[[M:.*]] = yul.constant 255
// CHECK:             %[[V:.*]] = yul.and %[[SH]], %[[M]]
// CHECK:             yul.sstore %{{.*}}, %[[V]]
// CHECK:             %[[C8:.*]] = yul.constant 8{{$}}
// CHECK:             yul.add %{{.*}}, %[[C8]]
// CHECK:         yul.if %{{.*}} -> i256 {

// Narrow-to-wide repacking: 32 uint8 per source slot, 4 uint64 per
// destination slot.
// CHECK-LABEL: yul.func @s2s_u8_u64_s_83 : () -> ()
// CHECK:         %[[SRC:.*]] = yul.constant 13{{$}}
// CHECK:         %[[DST:.*]] = yul.constant 14{{$}}
// CHECK:         yul.for
// CHECK:           %[[C8:.*]] = yul.constant 8{{$}}
// CHECK:           %[[OFF:.*]] = yul.mul %{{.*}}, %[[C8]]
// CHECK:           %[[E:.*]] = yul.arith_shr %{{.*}}, %[[OFF]]
// CHECK:           %[[M:.*]] = yul.constant 255
// CHECK:           yul.and %[[E]], %[[M]]
// CHECK:           %[[C64:.*]] = yul.constant 64
// CHECK:           %[[C32:.*]] = yul.constant 32{{$}}
// CHECK:           yul.cmp eq, %{{.*}}, %[[C32]]
// CHECK:           yul.sload
// CHECK:           %[[C4:.*]] = yul.constant 4{{$}}
// CHECK:           yul.cmp eq, %{{.*}}, %[[C4]]
// CHECK:             yul.sstore
// CHECK:         yul.sstore

// bytes9 lands in the upper 72 of bytes17's 136 bits.
// CHECK-LABEL: yul.func @s2s_b9_b17_d_75 : () -> ()
// CHECK:         %[[SRC:.*]] = yul.constant 11{{$}}
// CHECK:         %[[DST:.*]] = yul.constant 12{{$}}
// CHECK:         %[[LEN:.*]] = yul.sload %[[SRC]]
// CHECK:         yul.sstore %[[DST]], %[[LEN]]
// CHECK:         yul.for
// CHECK:           %[[W:.*]] = yul.sload
// CHECK:           yul.for
// CHECK:             %[[E:.*]] = yul.arith_shr %[[W]], %{{.*}}
// CHECK:             %[[C64:.*]] = yul.constant 64
// CHECK:             %[[SH:.*]] = yul.arith_shl %[[E]], %[[C64]]
// CHECK:             %[[M:.*]] = yul.constant 87112285931760246646605452758458952581120
// CHECK:             %[[V:.*]] = yul.and %[[SH]], %[[M]]
// CHECK:             yul.sstore %{{.*}}, %[[V]]
// CHECK:             %[[C72:.*]] = yul.constant 72
// CHECK:             yul.add %{{.*}}, %[[C72]]
// CHECK:         yul.if %{{.*}} -> i256 {

// bytes3 -> bytes8 shifts left by 40 bits; 10 per source slot, 4 per
// destination slot.
// CHECK-LABEL: yul.func @s2s_b3_b8_d_59 : () -> ()
// CHECK:         %[[SRC:.*]] = yul.constant 3{{$}}
// CHECK:         %[[LEN:.*]] = yul.sload %[[SRC]]
// CHECK:         yul.sstore %{{.*}}, %[[LEN]]
// CHECK:         yul.for
// CHECK:           %[[C24:.*]] = yul.constant 24{{$}}
// CHECK:           %[[OFF:.*]] = yul.mul %{{.*}}, %[[C24]]
// CHECK:           %[[E:.*]] = yul.arith_shr %{{.*}}, %[[OFF]]
// CHECK:           %[[M:.*]] = yul.constant 16777215
// CHECK:           %[[V:.*]] = yul.and %[[E]], %[[M]]
// CHECK:           %[[C40:.*]] = yul.constant 40
// CHECK:           yul.arith_shl %[[V]], %[[C40]]
// CHECK:           %[[C10:.*]] = yul.constant 10{{$}}
// CHECK:           yul.cmp eq, %{{.*}}, %[[C10]]
// CHECK:           yul.cmp eq, %{{.*}}, %{{.*}}
// CHECK:             yul.sstore
// CHECK:         yul.sstore

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @ArrayCopyPackedWiden_92 {
    sol.state_var @sb3d_12 slot 3 offset 0 : !sol.array<? x !sol.fixedbytes<3>, Storage>
    sol.state_var @sb8d_15 slot 4 offset 0 : !sol.array<? x !sol.fixedbytes<8>, Storage>
    sol.state_var @sb9d_26 slot 11 offset 0 : !sol.array<? x !sol.fixedbytes<9>, Storage>
    sol.state_var @sb17d_29 slot 12 offset 0 : !sol.array<? x !sol.fixedbytes<17>, Storage>
    sol.state_var @su8s_33 slot 13 offset 0 : !sol.array<5 x ui8, Storage>
    sol.state_var @su64s_37 slot 14 offset 0 : !sol.array<5 x ui64, Storage>
    sol.state_var @su8d_40 slot 16 offset 0 : !sol.array<? x ui8, Storage>
    sol.state_var @su160d_43 slot 17 offset 0 : !sol.array<? x ui160, Storage>
    sol.func @s2s_b3_b8_d_59() {
      %0 = sol.addr_of @sb3d_12 : !sol.array<? x !sol.fixedbytes<3>, Storage>
      %1 = sol.addr_of @sb8d_15 : !sol.array<? x !sol.fixedbytes<8>, Storage>
      sol.copy %0, %1 : !sol.array<? x !sol.fixedbytes<3>, Storage>, !sol.array<? x !sol.fixedbytes<8>, Storage>
      sol.return
    }
    sol.func @s2s_b9_b17_d_75() {
      %0 = sol.addr_of @sb9d_26 : !sol.array<? x !sol.fixedbytes<9>, Storage>
      %1 = sol.addr_of @sb17d_29 : !sol.array<? x !sol.fixedbytes<17>, Storage>
      sol.copy %0, %1 : !sol.array<? x !sol.fixedbytes<9>, Storage>, !sol.array<? x !sol.fixedbytes<17>, Storage>
      sol.return
    }
    sol.func @s2s_u8_u64_s_83() {
      %0 = sol.addr_of @su8s_33 : !sol.array<5 x ui8, Storage>
      %1 = sol.addr_of @su64s_37 : !sol.array<5 x ui64, Storage>
      sol.copy %0, %1 : !sol.array<5 x ui8, Storage>, !sol.array<5 x ui64, Storage>
      sol.return
    }
    sol.func @s2s_u8_u160_d_91() {
      %0 = sol.addr_of @su8d_40 : !sol.array<? x ui8, Storage>
      %1 = sol.addr_of @su160d_43 : !sol.array<? x ui160, Storage>
      sol.copy %0, %1 : !sol.array<? x ui8, Storage>, !sol.array<? x ui160, Storage>
      sol.return
    }
  } {kind = #Contract}
}

