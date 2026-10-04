// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Calldata array elements are validated: a dirty value reverts with empty
// data, a clean one is used as is.

// A bytes element is masked to its first byte without validation.
// CHECK-LABEL: yul.func @byte : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         %[[V:.*]] = yul.calldataload
// CHECK:         %[[M:.*]] = yul.constant -452312848583266388373324160190187140051835877600158453279131187530910662656
// CHECK:         %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK-NEXT:    yul.func_return %[[C]] : i256

// CHECK-LABEL: yul.func @bool : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         %[[V:.*]] = yul.calldataload
// CHECK:         %[[C:.*]] = yul.cmp ne, %[[V]], %{{.*}}
// CHECK:         %[[D:.*]] = yul.cmp ne, %[[V]], %[[C]]
// CHECK:         yul.if %[[D]] {
// CHECK:           yul.revert
// CHECK:         yul.func_return %[[C]] : i256

// CHECK-LABEL: yul.func @uint8 : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         %[[V:.*]] = yul.calldataload
// CHECK:         %[[M:.*]] = yul.constant 255
// CHECK:         %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK:         %[[D:.*]] = yul.cmp ne, %[[V]], %[[C]]
// CHECK:         yul.if %[[D]] {
// CHECK:           yul.revert
// CHECK:         yul.func_return %[[C]] : i256

// CHECK-LABEL: yul.func @int8 : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         %[[V:.*]] = yul.calldataload
// CHECK:         %[[C:.*]] = yul.signextend %{{.*}}, %[[V]]
// CHECK:         %[[D:.*]] = yul.cmp ne, %[[V]], %[[C]]
// CHECK:         yul.if %[[D]] {
// CHECK:           yul.revert
// CHECK:         yul.func_return %[[C]] : i256

// CHECK-LABEL: yul.func @enum : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         %[[V:.*]] = yul.calldataload
// CHECK:         %[[C2:.*]] = yul.constant 2
// CHECK:         %[[D:.*]] = yul.cmp ugt, %[[V]], %[[C2]]
// CHECK:         yul.if %[[D]] {
// CHECK:           yul.revert
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @address : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         %[[V:.*]] = yul.calldataload
// CHECK:         %[[M:.*]] = yul.constant 1461501637330902918203684832716283019655932542975
// CHECK:         %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK:         %[[D:.*]] = yul.cmp ne, %[[V]], %[[C]]
// CHECK:         yul.if %[[D]] {
// CHECK:           yul.revert
// CHECK:         yul.func_return %[[C]] : i256

// CHECK-LABEL: yul.func @bytes4 : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         %[[V:.*]] = yul.calldataload
// CHECK:         %[[M:.*]] = yul.constant -26959946667150639794667015087019630673637144422540572481103610249216
// CHECK:         %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK:         %[[D:.*]] = yul.cmp ne, %[[V]], %[[C]]
// CHECK:         yul.if %[[D]] {
// CHECK:           yul.revert
// CHECK:         yul.func_return %[[C]] : i256

// CHECK-LABEL: yul.func @fnPtr : (!llvm.struct<(i256, i256)>) -> !llvm.struct<(i256, i256)>
// CHECK:         %[[V:.*]] = yul.calldataload
// CHECK:         %[[M:.*]] = yul.constant -18446744073709551616
// CHECK:         %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK:         %[[D:.*]] = yul.cmp ne, %[[V]], %[[C]]
// CHECK:         yul.if %[[D]] {
// CHECK:           yul.revert
// CHECK:         %[[C96:.*]] = yul.constant 96
// CHECK:         %[[ADDR:.*]] = yul.arith_shr %[[V]], %[[C96]]
// CHECK:         %[[C64:.*]] = yul.constant 64
// CHECK:         %[[S:.*]] = yul.arith_shr %[[V]], %[[C64]]
// CHECK:         %[[SEL:.*]] = yul.and %[[S]], %{{.*}}
// CHECK:         %[[R0:.*]] = llvm.insertvalue %[[ADDR]], %{{.*}}[0]
// CHECK:         %[[R:.*]] = llvm.insertvalue %[[SEL]], %[[R0]][1]
// CHECK:         yul.func_return %[[R]]

#Default = #sol<RevertStrings Default>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @byte(%arg0: !sol.string<CallData>) -> !sol.fixedbytes<1> attributes {state_mutability = #Pure} {
    %c0_ui8 = sol.constant 0 : ui8
    %0 = sol.gep %arg0, %c0_ui8 : !sol.string<CallData>, ui8, !sol.ptr<!sol.byte, CallData>
    %1 = sol.load %0 : !sol.ptr<!sol.byte, CallData>, !sol.byte
    %2 = sol.bytes_cast %1 : !sol.byte to !sol.fixedbytes<1>
    sol.return %2 : !sol.fixedbytes<1>
  }
  sol.func @bool(%arg0: !sol.array<? x i1, CallData>) -> i1 attributes {state_mutability = #Pure} {
    %c0_ui8 = sol.constant 0 : ui8
    %0 = sol.gep %arg0, %c0_ui8 : !sol.array<? x i1, CallData>, ui8, !sol.ptr<i1, CallData>
    %1 = sol.load %0 : !sol.ptr<i1, CallData>, i1
    sol.return %1 : i1
  }
  sol.func @uint8(%arg0: !sol.array<? x ui8, CallData>) -> ui8 attributes {state_mutability = #Pure} {
    %c0_ui8 = sol.constant 0 : ui8
    %0 = sol.gep %arg0, %c0_ui8 : !sol.array<? x ui8, CallData>, ui8, !sol.ptr<ui8, CallData>
    %1 = sol.load %0 : !sol.ptr<ui8, CallData>, ui8
    sol.return %1 : ui8
  }
  sol.func @int8(%arg0: !sol.array<? x si8, CallData>) -> si8 attributes {state_mutability = #Pure} {
    %c0_ui8 = sol.constant 0 : ui8
    %0 = sol.gep %arg0, %c0_ui8 : !sol.array<? x si8, CallData>, ui8, !sol.ptr<si8, CallData>
    %1 = sol.load %0 : !sol.ptr<si8, CallData>, si8
    sol.return %1 : si8
  }
  sol.func @enum(%arg0: !sol.array<? x !sol.enum<2>, CallData>) -> !sol.enum<2> attributes {state_mutability = #Pure} {
    %c0_ui8 = sol.constant 0 : ui8
    %0 = sol.gep %arg0, %c0_ui8 : !sol.array<? x !sol.enum<2>, CallData>, ui8, !sol.ptr<!sol.enum<2>, CallData>
    %1 = sol.load %0 : !sol.ptr<!sol.enum<2>, CallData>, !sol.enum<2>
    sol.return %1 : !sol.enum<2>
  }
  sol.func @address(%arg0: !sol.array<? x !sol.address, CallData>) -> !sol.address attributes {state_mutability = #Pure} {
    %c0_ui8 = sol.constant 0 : ui8
    %0 = sol.gep %arg0, %c0_ui8 : !sol.array<? x !sol.address, CallData>, ui8, !sol.ptr<!sol.address, CallData>
    %1 = sol.load %0 : !sol.ptr<!sol.address, CallData>, !sol.address
    sol.return %1 : !sol.address
  }
  sol.func @bytes4(%arg0: !sol.array<? x !sol.fixedbytes<4>, CallData>) -> !sol.fixedbytes<4> attributes {state_mutability = #Pure} {
    %c0_ui8 = sol.constant 0 : ui8
    %0 = sol.gep %arg0, %c0_ui8 : !sol.array<? x !sol.fixedbytes<4>, CallData>, ui8, !sol.ptr<!sol.fixedbytes<4>, CallData>
    %1 = sol.load %0 : !sol.ptr<!sol.fixedbytes<4>, CallData>, !sol.fixedbytes<4>
    sol.return %1 : !sol.fixedbytes<4>
  }
  sol.func @fnPtr(%arg0: !sol.array<? x !sol.ext_func_ref<() -> ()>, CallData>) -> !sol.ext_func_ref<() -> ()> attributes {state_mutability = #Pure} {
    %c0_ui8 = sol.constant 0 : ui8
    %0 = sol.gep %arg0, %c0_ui8 : !sol.array<? x !sol.ext_func_ref<() -> ()>, CallData>, ui8, !sol.ptr<!sol.ext_func_ref<() -> ()>, CallData>
    %1 = sol.load %0 : !sol.ptr<!sol.ext_func_ref<() -> ()>, CallData>, !sol.ext_func_ref<() -> ()>
    sol.return %1 : !sol.ext_func_ref<() -> ()>
  }
}
