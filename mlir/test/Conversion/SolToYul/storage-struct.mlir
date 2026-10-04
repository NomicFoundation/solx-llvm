// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A member's slot is the struct's slot plus the member's slot offset; its
// byte offset within that slot rides along in the (slot, offset) pair.
// CHECK-LABEL: yul.func @rw : () -> ()

// packed.a = packed.b: same slot, byte offsets 1 and 0.
// CHECK:         %[[PB:.*]] = yul.constant 0{{$}}
// CHECK-NEXT:    %[[PM:.*]] = yul.constant 0{{$}}
// CHECK-NEXT:    yul.add %[[PB]], %[[PM]]
// CHECK-NEXT:    %[[POFF:.*]] = yul.constant 1{{$}}
// CHECK:         llvm.insertvalue %[[POFF]], %{{.*}}[1]
// CHECK:         yul.constant 255
// CHECK:         yul.sstore

// nonPacked.x = nonPacked.y
// CHECK:         yul.constant 1{{$}}
// CHECK-NEXT:    %[[NB:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    %[[NM:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    yul.add %[[NB]], %[[NM]]
// CHECK:         yul.sload
// CHECK:         yul.sstore

// nested.inner.x = nested.z
// CHECK:         yul.constant 1{{$}}
// CHECK-NEXT:    %[[OB:.*]] = yul.constant 3{{$}}
// CHECK-NEXT:    %[[OM:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    yul.add %[[OB]], %[[OM]]
// CHECK:         %[[IB:.*]] = yul.constant 3{{$}}
// CHECK-NEXT:    %[[IM:.*]] = yul.constant 0{{$}}
// CHECK-NEXT:    %[[INNER:.*]] = yul.add %[[IB]], %[[IM]]
// CHECK:         yul.add %[[INNER]], %{{.*}}
// CHECK:         yul.sstore

// mixed.x = mixed.y; the dynamic array sits between them in its own slot.
// CHECK:         yul.constant 2{{$}}
// CHECK-NEXT:    %[[MB:.*]] = yul.constant 5{{$}}
// CHECK-NEXT:    %[[MM:.*]] = yul.constant 2{{$}}
// CHECK-NEXT:    yul.add %[[MB]], %[[MM]]
// CHECK:         yul.sstore

// mixed.arr.push(1)
// CHECK:         yul.constant 1{{$}}
// CHECK-NEXT:    %[[AB:.*]] = yul.constant 5{{$}}
// CHECK-NEXT:    %[[AM:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    %[[ASLOT:.*]] = yul.add %[[AB]], %[[AM]]
// CHECK:         %[[ALEN:.*]] = yul.sload %[[ASLOT]]
// CHECK:         %[[ANEW:.*]] = yul.add %[[ALEN]], %{{.*}}
// CHECK:         yul.sstore %[[ASLOT]], %[[ANEW]]
// CHECK:         yul.mstore %{{.*}}, %[[ASLOT]]
// CHECK:         yul.keccak256
// CHECK:         yul.sstore

// contractRef.c = this at byte offset 12.
// CHECK:         %[[THIS:.*]] = yul.address
// CHECK:         %[[COFF:.*]] = yul.constant 12
// CHECK:         llvm.insertvalue %[[COFF]], %{{.*}}[1]
// CHECK:         %[[AMASK:.*]] = yul.constant 1461501637330902918203684832716283019655932542975
// CHECK:         yul.and %[[THIS]], %[[AMASK]]
// CHECK:         yul.sstore

// nestedDynamic.inner.note, then right: the string-bearing inner struct
// spans slots 10-12.
// CHECK:         %[[NOTEB:.*]] = yul.constant 9{{$}}
// CHECK-NEXT:    %[[NOTEM:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    %[[NOTEI:.*]] = yul.add %[[NOTEB]], %[[NOTEM]]
// CHECK-NEXT:    %[[NOTEO:.*]] = yul.constant 2{{$}}
// CHECK-NEXT:    %[[NOTE:.*]] = yul.add %[[NOTEI]], %[[NOTEO]]
// CHECK-NEXT:    yul.func_call @__sol.copy.memory.storage.string(%{{.*}}, %[[NOTE]])
// CHECK:         yul.constant 300
// CHECK:         %[[RB:.*]] = yul.constant 9{{$}}
// CHECK-NEXT:    %[[RM:.*]] = yul.constant 4{{$}}
// CHECK-NEXT:    yul.add %[[RB]], %[[RM]]
// CHECK:         yul.sstore

// fixedArrayTail.a[1]: the uint8[4] packs into slot 14 at byte offset 1;
// fixedArrayTail.b follows in slot 15.
// CHECK:         yul.constant 14{{$}}
// CHECK:         yul.add
// CHECK-NEXT:    %[[I:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    %[[C32:.*]] = yul.constant 32{{$}}
// CHECK-NEXT:    yul.arith_div %[[I]], %[[C32]]
// CHECK-NEXT:    %[[MOD:.*]] = yul.arith_mod %[[I]], %[[C32]]
// CHECK:         %[[OFF:.*]] = yul.mul %[[MOD]], %{{.*}}
// CHECK:         llvm.insertvalue %[[OFF]], %{{.*}}[1]
// CHECK:         yul.sstore
// CHECK:         yul.constant 48059
// CHECK:         %[[TB:.*]] = yul.constant 14{{$}}
// CHECK-NEXT:    %[[TM:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    yul.add %[[TB]], %[[TM]]
// CHECK:         yul.sstore
// CHECK:         yul.func_return

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @packed slot 0 offset 0 : !sol.struct<(ui8, ui8, ui16), Storage>
    sol.state_var @nonPacked slot 1 offset 0 : !sol.struct<(ui256, ui256), Storage>
    sol.state_var @nested slot 3 offset 0 : !sol.struct<(!sol.struct<(ui8, ui8), Storage>, ui8), Storage>
    sol.state_var @mixed slot 5 offset 0 : !sol.struct<(ui8, !sol.array<? x ui256, Storage>, ui8), Storage>
    sol.state_var @contractRef slot 8 offset 0 : !sol.struct<(ui96, !sol.contract<"C">), Storage>
    sol.state_var @nestedDynamic slot 9 offset 0 : !sol.struct<(ui256, !sol.struct<(ui256, ui128, !sol.string<Storage>), Storage>, ui256), Storage>
    sol.state_var @fixedArrayTail slot 14 offset 0 : !sol.struct<(!sol.array<4 x ui8, Storage>, ui256), Storage>
    sol.func @rw() attributes {state_mutability = #NonPayable} {
      %c1_ui64 = sol.constant 1 : ui64
      %0 = sol.addr_of @packed : !sol.struct<(ui8, ui8, ui16), Storage>
      %1 = sol.gep %0, %c1_ui64 : !sol.struct<(ui8, ui8, ui16), Storage>, ui64, !sol.ptr<ui8, Storage>
      %2 = sol.load %1 : !sol.ptr<ui8, Storage>, ui8
      %c0_ui64 = sol.constant 0 : ui64
      %3 = sol.addr_of @packed : !sol.struct<(ui8, ui8, ui16), Storage>
      %4 = sol.gep %3, %c0_ui64 : !sol.struct<(ui8, ui8, ui16), Storage>, ui64, !sol.ptr<ui8, Storage>
      sol.store %2, %4 : ui8, !sol.ptr<ui8, Storage>
      %c1_ui64_0 = sol.constant 1 : ui64
      %5 = sol.addr_of @nonPacked : !sol.struct<(ui256, ui256), Storage>
      %6 = sol.gep %5, %c1_ui64_0 : !sol.struct<(ui256, ui256), Storage>, ui64, !sol.ptr<ui256, Storage>
      %7 = sol.load %6 : !sol.ptr<ui256, Storage>, ui256
      %c0_ui64_1 = sol.constant 0 : ui64
      %8 = sol.addr_of @nonPacked : !sol.struct<(ui256, ui256), Storage>
      %9 = sol.gep %8, %c0_ui64_1 : !sol.struct<(ui256, ui256), Storage>, ui64, !sol.ptr<ui256, Storage>
      sol.store %7, %9 : ui256, !sol.ptr<ui256, Storage>
      %c1_ui64_2 = sol.constant 1 : ui64
      %10 = sol.addr_of @nested : !sol.struct<(!sol.struct<(ui8, ui8), Storage>, ui8), Storage>
      %11 = sol.gep %10, %c1_ui64_2 : !sol.struct<(!sol.struct<(ui8, ui8), Storage>, ui8), Storage>, ui64, !sol.ptr<ui8, Storage>
      %12 = sol.load %11 : !sol.ptr<ui8, Storage>, ui8
      %c0_ui64_3 = sol.constant 0 : ui64
      %c0_ui64_4 = sol.constant 0 : ui64
      %13 = sol.addr_of @nested : !sol.struct<(!sol.struct<(ui8, ui8), Storage>, ui8), Storage>
      %14 = sol.gep %13, %c0_ui64_4 : !sol.struct<(!sol.struct<(ui8, ui8), Storage>, ui8), Storage>, ui64, !sol.struct<(ui8, ui8), Storage>
      %15 = sol.gep %14, %c0_ui64_3 : !sol.struct<(ui8, ui8), Storage>, ui64, !sol.ptr<ui8, Storage>
      sol.store %12, %15 : ui8, !sol.ptr<ui8, Storage>
      %c2_ui64 = sol.constant 2 : ui64
      %16 = sol.addr_of @mixed : !sol.struct<(ui8, !sol.array<? x ui256, Storage>, ui8), Storage>
      %17 = sol.gep %16, %c2_ui64 : !sol.struct<(ui8, !sol.array<? x ui256, Storage>, ui8), Storage>, ui64, !sol.ptr<ui8, Storage>
      %18 = sol.load %17 : !sol.ptr<ui8, Storage>, ui8
      %c0_ui64_5 = sol.constant 0 : ui64
      %19 = sol.addr_of @mixed : !sol.struct<(ui8, !sol.array<? x ui256, Storage>, ui8), Storage>
      %20 = sol.gep %19, %c0_ui64_5 : !sol.struct<(ui8, !sol.array<? x ui256, Storage>, ui8), Storage>, ui64, !sol.ptr<ui8, Storage>
      sol.store %18, %20 : ui8, !sol.ptr<ui8, Storage>
      %c1_ui64_6 = sol.constant 1 : ui64
      %21 = sol.addr_of @mixed : !sol.struct<(ui8, !sol.array<? x ui256, Storage>, ui8), Storage>
      %22 = sol.gep %21, %c1_ui64_6 : !sol.struct<(ui8, !sol.array<? x ui256, Storage>, ui8), Storage>, ui64, !sol.array<? x ui256, Storage>
      %23 = sol.push %22 : !sol.array<? x ui256, Storage> -> !sol.ptr<ui256, Storage>
      %c1_ui256 = sol.constant 1 : ui256
      sol.store %c1_ui256, %23 : ui256, !sol.ptr<ui256, Storage>
      %30 = sol.this : !sol.contract<"C">
      %c1_ui64_9 = sol.constant 1 : ui64
      %33 = sol.addr_of @contractRef : !sol.struct<(ui96, !sol.contract<"C">), Storage>
      %34 = sol.gep %33, %c1_ui64_9 : !sol.struct<(ui96, !sol.contract<"C">), Storage>, ui64, !sol.ptr<!sol.contract<"C">, Storage>
      sol.store %30, %34 : !sol.contract<"C">, !sol.ptr<!sol.contract<"C">, Storage>
      %46 = sol.string_lit "in" -> !sol.string<Memory>
      %c2_ui64_15 = sol.constant 2 : ui64
      %c1_ui64_16 = sol.constant 1 : ui64
      %47 = sol.addr_of @nestedDynamic : !sol.struct<(ui256, !sol.struct<(ui256, ui128, !sol.string<Storage>), Storage>, ui256), Storage>
      %48 = sol.gep %47, %c1_ui64_16 : !sol.struct<(ui256, !sol.struct<(ui256, ui128, !sol.string<Storage>), Storage>, ui256), Storage>, ui64, !sol.struct<(ui256, ui128, !sol.string<Storage>), Storage>
      %49 = sol.gep %48, %c2_ui64_15 : !sol.struct<(ui256, ui128, !sol.string<Storage>), Storage>, ui64, !sol.string<Storage>
      sol.copy %46, %49 : !sol.string<Memory>, !sol.string<Storage>
      %c300_ui256 = sol.constant 300 : ui256
      %c2_ui64_17 = sol.constant 2 : ui64
      %50 = sol.addr_of @nestedDynamic : !sol.struct<(ui256, !sol.struct<(ui256, ui128, !sol.string<Storage>), Storage>, ui256), Storage>
      %51 = sol.gep %50, %c2_ui64_17 : !sol.struct<(ui256, !sol.struct<(ui256, ui128, !sol.string<Storage>), Storage>, ui256), Storage>, ui64, !sol.ptr<ui256, Storage>
      sol.store %c300_ui256, %51 : ui256, !sol.ptr<ui256, Storage>
      %c2_ui8 = sol.constant 2 : ui8
      %c0_ui64_23 = sol.constant 0 : ui64
      %62 = sol.addr_of @fixedArrayTail : !sol.struct<(!sol.array<4 x ui8, Storage>, ui256), Storage>
      %63 = sol.gep %62, %c0_ui64_23 : !sol.struct<(!sol.array<4 x ui8, Storage>, ui256), Storage>, ui64, !sol.array<4 x ui8, Storage>
      %c1_ui8_24 = sol.constant 1 : ui8
      %64 = sol.gep %63, %c1_ui8_24 : !sol.array<4 x ui8, Storage>, ui8, !sol.ptr<ui8, Storage>
      sol.store %c2_ui8, %64 : ui8, !sol.ptr<ui8, Storage>
      %c48059_ui256 = sol.constant 48059 : ui256
      %c1_ui64_29 = sol.constant 1 : ui64
      %73 = sol.addr_of @fixedArrayTail : !sol.struct<(!sol.array<4 x ui8, Storage>, ui256), Storage>
      %74 = sol.gep %73, %c1_ui64_29 : !sol.struct<(!sol.array<4 x ui8, Storage>, ui256), Storage>, ui64, !sol.ptr<ui256, Storage>
      sol.store %c48059_ui256, %74 : ui256, !sol.ptr<ui256, Storage>
      sol.return
    }
  } {kind = #Contract}
}
