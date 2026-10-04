// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Memory bytes elements load as the word at the element, masked to its top
// byte; stores write a single byte with mstore8.
// CHECK-LABEL: yul.func @bxorMemory : (i256) -> ()
// CHECK:         %[[C:.*]] = yul.constant 7{{$}}
// CHECK:         yul.cmp uge
// CHECK:         %[[E:.*]] = yul.mload %[[ADDR:.*]]
// CHECK:         %[[V:.*]] = yul.and %[[E]], %{{.*}}
// CHECK:         %[[C248:.*]] = yul.constant 248
// CHECK:         %[[RHS:.*]] = yul.arith_shl %[[C]], %[[C248]]
// CHECK:         %[[OP:.*]] = yul.xor %[[V]], %[[RHS]]
// CHECK:         %[[B:.*]] = yul.byte %{{.*}}, %[[OP]]
// CHECK:         yul.mstore8 %[[ADDR]], %[[B]]

// Storage bytes elements are single bytes in the packed slot.
// CHECK-LABEL: yul.func @writeStorage : (i256) -> ()
// CHECK:         yul.keccak256
// CHECK:         %[[M:.*]] = yul.constant [[$B1MASK:-452312848583266388373324160190187140051835877600158453279131187530910662656]]
// CHECK:         %[[XM:.*]] = yul.and %arg0, %[[M]]
// CHECK:         %[[C248:.*]] = yul.constant 248
// CHECK:         %[[BYTE:.*]] = yul.arith_shr %[[XM]], %[[C248]]
// CHECK:         %[[SHAMT:.*]] = yul.mul
// CHECK:         %[[S:.*]] = yul.sload %[[SLOT:.*]]
// CHECK:         %[[FF:.*]] = yul.constant 255
// CHECK:         %[[HOLE:.*]] = yul.arith_shl %[[FF]], %[[SHAMT]]
// CHECK:         %[[KEEP:.*]] = yul.xor %[[HOLE]], %{{.*}}
// CHECK:         %[[CLR:.*]] = yul.and %[[S]], %[[KEEP]]
// CHECK:         %[[NEWB:.*]] = yul.arith_shl %[[BYTE]], %[[SHAMT]]
// CHECK:         %[[NEW:.*]] = yul.or %[[CLR]], %[[NEWB]]
// CHECK:         yul.sstore %[[SLOT]], %[[NEW]]

// CHECK-LABEL: yul.func @readStorage : () -> i256
// CHECK:         %[[LONG:.*]] = yul.cmp ugt
// CHECK:         %[[DATA:.*]] = yul.keccak256
// CHECK:         yul.arith_select %[[LONG]], %[[DATA]], %{{.*}}
// CHECK:         yul.arith_div
// CHECK:         yul.arith_mod
// CHECK:         %[[S:.*]] = yul.sload
// CHECK:         %[[SH:.*]] = yul.arith_shr %[[S]], %{{.*}}
// CHECK:         %[[C248:.*]] = yul.constant 248
// CHECK:         %[[R:.*]] = yul.arith_shl %[[SH]], %[[C248]]
// CHECK:         yul.func_return %[[R]] : i256

// CHECK-LABEL: yul.func @storeBytesMemory : (i256, i256) -> ()
// CHECK:         yul.cmp uge
// CHECK:         yul.add
// CHECK-NEXT:    %[[ADDR:.*]] = yul.add %{{.*}}, %{{.*}}
// CHECK:         %[[B:.*]] = yul.byte %{{.*}}, %arg1
// CHECK-NEXT:    yul.mstore8 %[[ADDR]], %[[B]]

// CHECK-LABEL: yul.func @readBytes2 : (i256) -> i256
// CHECK:         yul.cmp uge
// CHECK:         %[[E:.*]] = yul.mload
// CHECK:         %[[M:.*]] = yul.constant [[$B1MASK]]
// CHECK:         %[[V:.*]] = yul.and %[[E]], %[[M]]
// CHECK:         %[[R:.*]] = yul.and %[[V]], %{{.*}}
// CHECK:         yul.func_return %[[R]] : i256

// CHECK-LABEL: yul.func @readBytes1 : (i256) -> i256
// CHECK:         yul.cmp uge
// CHECK:         %[[E:.*]] = yul.mload
// CHECK:         %[[M:.*]] = yul.constant [[$B1MASK]]
// CHECK:         %[[V:.*]] = yul.and %[[E]], %[[M]]
// CHECK:         yul.func_return %[[V]] : i256

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @data slot 0 offset 0 : !sol.string<Storage>
    sol.func @readBytes1(%arg0: !sol.string<Memory>) -> !sol.fixedbytes<1> {
      %c1_ui8 = sol.constant 1 : ui8
      %0 = sol.gep %arg0, %c1_ui8 : !sol.string<Memory>, ui8, !sol.ptr<!sol.byte, Memory>
      %1 = sol.load %0 : !sol.ptr<!sol.byte, Memory>, !sol.byte
      %2 = sol.bytes_cast %1 : !sol.byte to !sol.fixedbytes<1>
      sol.return %2 : !sol.fixedbytes<1>
    }
    sol.func @readBytes2(%arg0: !sol.string<Memory>) -> !sol.fixedbytes<2> {
      %c1_ui8 = sol.constant 1 : ui8
      %0 = sol.gep %arg0, %c1_ui8 : !sol.string<Memory>, ui8, !sol.ptr<!sol.byte, Memory>
      %1 = sol.load %0 : !sol.ptr<!sol.byte, Memory>, !sol.byte
      %2 = sol.bytes_cast %1 : !sol.byte to !sol.fixedbytes<2>
      sol.return %2 : !sol.fixedbytes<2>
    }
    sol.func @storeBytesMemory(%arg0: !sol.string<Memory>, %arg1: !sol.fixedbytes<1>) {
      %c4_ui8 = sol.constant 4 : ui8
      %0 = sol.gep %arg0, %c4_ui8 : !sol.string<Memory>, ui8, !sol.ptr<!sol.byte, Memory>
      %1 = sol.bytes_cast %arg1 : !sol.fixedbytes<1> to !sol.byte
      sol.store %1, %0 : !sol.byte, !sol.ptr<!sol.byte, Memory>
      sol.return
    }
    sol.func @readStorage() -> !sol.fixedbytes<1> {
      %0 = sol.addr_of @data : !sol.string<Storage>
      %c1_ui8 = sol.constant 1 : ui8
      %1 = sol.gep %0, %c1_ui8 : !sol.string<Storage>, ui8, !sol.ptr<!sol.byte, Storage>
      %2 = sol.load %1 : !sol.ptr<!sol.byte, Storage>, !sol.byte
      %3 = sol.bytes_cast %2 : !sol.byte to !sol.fixedbytes<1>
      sol.return %3 : !sol.fixedbytes<1>
    }
    sol.func @writeStorage(%arg0: !sol.fixedbytes<1>) {
      %0 = sol.addr_of @data : !sol.string<Storage>
      %c4_ui8 = sol.constant 4 : ui8
      %1 = sol.gep %0, %c4_ui8 : !sol.string<Storage>, ui8, !sol.ptr<!sol.byte, Storage>
      %2 = sol.bytes_cast %arg0 : !sol.fixedbytes<1> to !sol.byte
      sol.store %2, %1 : !sol.byte, !sol.ptr<!sol.byte, Storage>
      sol.return
    }
    sol.func @bxorMemory(%arg0: !sol.string<Memory>) {
      %c7_ui8 = sol.constant 7 : ui8
      %c0_ui8 = sol.constant 0 : ui8
      %0 = sol.gep %arg0, %c0_ui8 : !sol.string<Memory>, ui8, !sol.ptr<!sol.byte, Memory>
      %1 = sol.load %0 : !sol.ptr<!sol.byte, Memory>, !sol.byte
      %2 = sol.bytes_cast %c7_ui8 : ui8 to !sol.byte
      %3 = sol.xor %1, %2 : !sol.byte
      sol.store %3, %0 : !sol.byte, !sol.ptr<!sol.byte, Memory>
      sol.return
    }
  } {kind = #Contract}
}
