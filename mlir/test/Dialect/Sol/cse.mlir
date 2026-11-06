// RUN: mlir-opt %s -cse | FileCheck %s

sol.contract @C {
  sol.state_var @m slot 0 offset 0 : !sol.mapping<ui256, ui256>
  sol.state_var @n slot 1 offset 0 : !sol.mapping<!sol.address, !sol.mapping<ui256, ui256>>
  sol.state_var @s slot 2 offset 0 : !sol.mapping<ui256, !sol.struct<(ui256, !sol.mapping<ui256, ui256>), Storage>>
  sol.state_var @e slot 3 offset 0 : !sol.mapping<!sol.enum<1>, ui256>
  sol.state_var @t slot 4 offset 0 : !sol.mapping<!sol.string<Memory>, ui256>
  sol.state_var @a slot 5 offset 0 : !sol.array<? x ui256, Storage>

  // A slot is one value across a storage write.
  // CHECK-LABEL: sol.func @rmw(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[Y:[^:]*]]: ui256
  // CHECK-NEXT:    %[[M:.*]] = sol.addr_of @m
  // CHECK-NEXT:    %[[P:.*]] = sol.map %[[M]], %[[X]]
  // CHECK-NEXT:    %[[V:.*]] = sol.load %[[P]]
  // CHECK-NEXT:    sol.store %[[Y]], %[[P]]
  // CHECK-NEXT:    %[[R:.*]] = sol.load %[[P]]
  // CHECK-NEXT:    sol.return %[[V]], %[[R]]
  sol.func @rmw(%x: ui256, %y: ui256) -> (ui256, ui256) {
    %0 = sol.addr_of @m : !sol.mapping<ui256, ui256>
    %1 = sol.map %0, %x : !sol.mapping<ui256, ui256>, ui256, !sol.ptr<ui256, Storage>
    %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
    %3 = sol.addr_of @m : !sol.mapping<ui256, ui256>
    %4 = sol.map %3, %x : !sol.mapping<ui256, ui256>, ui256, !sol.ptr<ui256, Storage>
    sol.store %y, %4 : ui256, !sol.ptr<ui256, Storage>
    %5 = sol.addr_of @m : !sol.mapping<ui256, ui256>
    %6 = sol.map %5, %x : !sol.mapping<ui256, ui256>, ui256, !sol.ptr<ui256, Storage>
    %7 = sol.load %6 : !sol.ptr<ui256, Storage>, ui256
    sol.return %2, %7 : ui256, ui256
  }

  // A nested slot keyed by the caller is reused in a nested region.
  // CHECK-LABEL: sol.func @nested(
  // CHECK-SAME:    %[[X:[^:]*]]: ui256, %[[C:[^:]*]]: i1
  // CHECK-NEXT:    %[[N:.*]] = sol.addr_of @n
  // CHECK-NEXT:    %[[A:.*]] = sol.caller
  // CHECK-NEXT:    %[[I:.*]] = sol.map %[[N]], %[[A]]
  // CHECK-NEXT:    %[[P:.*]] = sol.map %[[I]], %[[X]]
  // CHECK-NEXT:    %[[V:.*]] = sol.load %[[P]]
  // CHECK-NEXT:    sol.if %[[C]] {
  // CHECK-NEXT:      sol.store %[[X]], %[[P]]
  // CHECK-NEXT:      sol.yield
  sol.func @nested(%x: ui256, %c: i1) -> ui256 {
    %0 = sol.addr_of @n : !sol.mapping<!sol.address, !sol.mapping<ui256, ui256>>
    %1 = sol.caller : !sol.address
    %2 = sol.map %0, %1 : !sol.mapping<!sol.address, !sol.mapping<ui256, ui256>>, !sol.address, !sol.mapping<ui256, ui256>
    %3 = sol.map %2, %x : !sol.mapping<ui256, ui256>, ui256, !sol.ptr<ui256, Storage>
    %4 = sol.load %3 : !sol.ptr<ui256, Storage>, ui256
    sol.if %c {
      %5 = sol.addr_of @n : !sol.mapping<!sol.address, !sol.mapping<ui256, ui256>>
      %6 = sol.caller : !sol.address
      %7 = sol.map %5, %6 : !sol.mapping<!sol.address, !sol.mapping<ui256, ui256>>, !sol.address, !sol.mapping<ui256, ui256>
      %8 = sol.map %7, %x : !sol.mapping<ui256, ui256>, ui256, !sol.ptr<ui256, Storage>
      sol.store %x, %8 : ui256, !sol.ptr<ui256, Storage>
      sol.yield
    } else {
    }
    sol.return %4 : ui256
  }

  // A mapping struct member is one value.
  // CHECK-LABEL: sol.func @member(
  // CHECK:         %[[G:.*]] = sol.gep
  // CHECK-NEXT:    %[[P:.*]] = sol.map %[[G]]
  // CHECK-NEXT:    sol.store %{{.*}}, %[[P]]
  // CHECK-NEXT:    sol.store %{{.*}}, %[[P]]
  sol.func @member(%x: ui256, %y: ui256) {
    %c1 = sol.constant 1 : ui64
    %0 = sol.addr_of @s : !sol.mapping<ui256, !sol.struct<(ui256, !sol.mapping<ui256, ui256>), Storage>>
    %1 = sol.map %0, %x : !sol.mapping<ui256, !sol.struct<(ui256, !sol.mapping<ui256, ui256>), Storage>>, ui256, !sol.struct<(ui256, !sol.mapping<ui256, ui256>), Storage>
    %2 = sol.gep %1, %c1 : !sol.struct<(ui256, !sol.mapping<ui256, ui256>), Storage>, ui64, !sol.mapping<ui256, ui256>
    %3 = sol.map %2, %y : !sol.mapping<ui256, ui256>, ui256, !sol.ptr<ui256, Storage>
    sol.store %x, %3 : ui256, !sol.ptr<ui256, Storage>
    %4 = sol.map %0, %x : !sol.mapping<ui256, !sol.struct<(ui256, !sol.mapping<ui256, ui256>), Storage>>, ui256, !sol.struct<(ui256, !sol.mapping<ui256, ui256>), Storage>
    %5 = sol.gep %4, %c1 : !sol.struct<(ui256, !sol.mapping<ui256, ui256>), Storage>, ui64, !sol.mapping<ui256, ui256>
    %6 = sol.map %5, %y : !sol.mapping<ui256, ui256>, ui256, !sol.ptr<ui256, Storage>
    sol.store %y, %6 : ui256, !sol.ptr<ui256, Storage>
    sol.return
  }

  // An enum key may panic, and a dynamic array index is bounds checked.
  // CHECK-LABEL: sol.func @checked(
  // CHECK-COUNT-2: sol.map
  // CHECK-COUNT-2: sol.gep
  sol.func @checked(%k: !sol.enum<1>, %i: ui256) -> (ui256, ui256, ui256, ui256) {
    %0 = sol.addr_of @e : !sol.mapping<!sol.enum<1>, ui256>
    %1 = sol.map %0, %k : !sol.mapping<!sol.enum<1>, ui256>, !sol.enum<1>, !sol.ptr<ui256, Storage>
    %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
    %3 = sol.map %0, %k : !sol.mapping<!sol.enum<1>, ui256>, !sol.enum<1>, !sol.ptr<ui256, Storage>
    %4 = sol.load %3 : !sol.ptr<ui256, Storage>, ui256
    %5 = sol.addr_of @a : !sol.array<? x ui256, Storage>
    %6 = sol.gep %5, %i : !sol.array<? x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
    %7 = sol.load %6 : !sol.ptr<ui256, Storage>, ui256
    %8 = sol.gep %5, %i : !sol.array<? x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
    %9 = sol.load %8 : !sol.ptr<ui256, Storage>, ui256
    sol.return %2, %4, %7, %9 : ui256, ui256, ui256, ui256
  }

  // A string key is read, so a write keeps the second slot.
  // CHECK-LABEL: sol.func @string_key(
  // CHECK:         sol.map
  // CHECK:         sol.store
  // CHECK:         sol.map
  sol.func @string_key(%k: !sol.string<Memory>, %x: ui256) -> ui256 {
    %0 = sol.addr_of @t : !sol.mapping<!sol.string<Memory>, ui256>
    %1 = sol.map %0, %k : !sol.mapping<!sol.string<Memory>, ui256>, !sol.string<Memory>, !sol.ptr<ui256, Storage>
    sol.store %x, %1 : ui256, !sol.ptr<ui256, Storage>
    %2 = sol.map %0, %k : !sol.mapping<!sol.string<Memory>, ui256>, !sol.string<Memory>, !sol.ptr<ui256, Storage>
    %3 = sol.load %2 : !sol.ptr<ui256, Storage>, ui256
    sol.return %3 : ui256
  }

  // CHECK-LABEL: sol.func @code_hash(
  // CHECK-COUNT-2: sol.code_hash
  sol.func @code_hash(%a: !sol.address) -> (ui256, ui256) {
    %0 = sol.code_hash %a : !sol.address -> ui256
    %1 = sol.code_hash %a : !sol.address -> ui256
    sol.return %0, %1 : ui256, ui256
  }

  // CHECK-LABEL: sol.func @assembly(
  // CHECK-COUNT-2: yul.gas
  // CHECK-COUNT-2: yul.msize
  sol.func @assembly() {
    sol.inline_asm {
      %c0 = yul.constant 0
      %0 = yul.gas
      yul.mstore %c0, %0
      %1 = yul.gas
      yul.mstore %c0, %1
      %2 = yul.msize
      %3 = yul.mload %2
      %4 = yul.msize
      yul.mstore %c0, %3
      yul.mstore %c0, %4
    }
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}
