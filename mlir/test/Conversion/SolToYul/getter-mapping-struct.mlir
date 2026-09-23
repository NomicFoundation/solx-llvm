// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// small, flag and addr share struct slot 2 at byte offsets 0, 1 and 2.
// CHECK-LABEL:   yul.func @get_m : (i256) -> (i256, i256, i256, i256, i256)
// CHECK:           %[[BASE:.*]] = yul.keccak256
// CHECK:           %[[A:.*]] = yul.arith_shr
// CHECK:           yul.add %[[BASE]], %c2_i256{{(_[0-9]+)?$}}
// CHECK-NEXT:      %[[OFF0:.*]] = yul.constant 0
// CHECK:           llvm.insertvalue %[[OFF0]], %{{.*}}[1]
// CHECK:           %[[SMALL:.*]] = yul.and %{{.*}}, %c255_i256{{(_[0-9]+)?$}}
// CHECK:           yul.add %[[BASE]], %c2_i256{{(_[0-9]+)?$}}
// CHECK-NEXT:      %[[OFF1:.*]] = yul.constant 1
// CHECK:           llvm.insertvalue %[[OFF1]], %{{.*}}[1]
// CHECK:           %[[FLAG:.*]] = yul.cmp ne
// CHECK:           yul.add %[[BASE]], %c2_i256{{(_[0-9]+)?$}}
// CHECK-NEXT:      %[[OFF2:.*]] = yul.constant 2
// CHECK:           llvm.insertvalue %[[OFF2]], %{{.*}}[1]
// CHECK:           %[[ADDR:.*]] = yul.and %{{.*}}, %c1461501637330902918203684832716283019655932542975_i256
// CHECK:           %[[SSLOT:.*]] = yul.add %[[BASE]], %c5_i256{{(_[0-9]+)?$}}
// CHECK-NEXT:      %[[STR:.*]] = yul.func_call @__sol.clone_string.storage.memory(%[[SSLOT]]) : (i256) -> i256
// CHECK-NEXT:      yul.func_return %[[A]], %[[SMALL]], %[[FLAG]], %[[ADDR]], %[[STR]]

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    sol.state_var @m slot 0 offset 0 : !sol.mapping<ui256, !sol.struct<(ui256, si256, ui8, i1, !sol.address, !sol.fixedbytes<32>, !sol.array<? x ui256, Storage>, !sol.string<Storage>, !sol.string<Storage>, !sol.array<2 x ui256, Storage>, ui256), Storage>>
    sol.func @get_m(%arg0: ui256) -> (ui256, ui8, i1, !sol.address, !sol.string<Memory>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @m : !sol.mapping<ui256, !sol.struct<(ui256, si256, ui8, i1, !sol.address, !sol.fixedbytes<32>, !sol.array<? x ui256, Storage>, !sol.string<Storage>, !sol.string<Storage>, !sol.array<2 x ui256, Storage>, ui256), Storage>>
      %1 = sol.map %0, %arg0 : !sol.mapping<ui256, !sol.struct<(ui256, si256, ui8, i1, !sol.address, !sol.fixedbytes<32>, !sol.array<? x ui256, Storage>, !sol.string<Storage>, !sol.string<Storage>, !sol.array<2 x ui256, Storage>, ui256), Storage>>, ui256, !sol.struct<(ui256, si256, ui8, i1, !sol.address, !sol.fixedbytes<32>, !sol.array<? x ui256, Storage>, !sol.string<Storage>, !sol.string<Storage>, !sol.array<2 x ui256, Storage>, ui256), Storage>
      %c0_ui64 = sol.constant 0 : ui64
      %2 = sol.gep %1, %c0_ui64 : !sol.struct<(ui256, si256, ui8, i1, !sol.address, !sol.fixedbytes<32>, !sol.array<? x ui256, Storage>, !sol.string<Storage>, !sol.string<Storage>, !sol.array<2 x ui256, Storage>, ui256), Storage>, ui64, !sol.ptr<ui256, Storage>
      %3 = sol.load %2 : !sol.ptr<ui256, Storage>, ui256
      %c2_ui64 = sol.constant 2 : ui64
      %6 = sol.gep %1, %c2_ui64 : !sol.struct<(ui256, si256, ui8, i1, !sol.address, !sol.fixedbytes<32>, !sol.array<? x ui256, Storage>, !sol.string<Storage>, !sol.string<Storage>, !sol.array<2 x ui256, Storage>, ui256), Storage>, ui64, !sol.ptr<ui8, Storage>
      %7 = sol.load %6 : !sol.ptr<ui8, Storage>, ui8
      %c3_ui64 = sol.constant 3 : ui64
      %8 = sol.gep %1, %c3_ui64 : !sol.struct<(ui256, si256, ui8, i1, !sol.address, !sol.fixedbytes<32>, !sol.array<? x ui256, Storage>, !sol.string<Storage>, !sol.string<Storage>, !sol.array<2 x ui256, Storage>, ui256), Storage>, ui64, !sol.ptr<i1, Storage>
      %9 = sol.load %8 : !sol.ptr<i1, Storage>, i1
      %c4_ui64 = sol.constant 4 : ui64
      %10 = sol.gep %1, %c4_ui64 : !sol.struct<(ui256, si256, ui8, i1, !sol.address, !sol.fixedbytes<32>, !sol.array<? x ui256, Storage>, !sol.string<Storage>, !sol.string<Storage>, !sol.array<2 x ui256, Storage>, ui256), Storage>, ui64, !sol.ptr<!sol.address, Storage>
      %11 = sol.load %10 : !sol.ptr<!sol.address, Storage>, !sol.address
      %c7_ui64 = sol.constant 7 : ui64
      %14 = sol.gep %1, %c7_ui64 : !sol.struct<(ui256, si256, ui8, i1, !sol.address, !sol.fixedbytes<32>, !sol.array<? x ui256, Storage>, !sol.string<Storage>, !sol.string<Storage>, !sol.array<2 x ui256, Storage>, ui256), Storage>, ui64, !sol.string<Storage>
      %15 = sol.data_loc_cast %14 : !sol.string<Storage>, !sol.string<Memory>
      sol.return %3, %7, %9, %11, %15 : ui256, ui8, i1, !sol.address, !sol.string<Memory>
    }
  } {kind = #Contract}
}
