// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Memory array elements are cleaned on store and trusted on load.

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @loadByte : (i256) -> i256
    // CHECK:         yul.mload
    // CHECK:         %[[V:.*]] = yul.mload
    // CHECK:         %[[M:.*]] = yul.constant -452312848583266388373324160190187140051835877600158453279131187530910662656
    // CHECK:         %[[R:.*]] = yul.and %[[V]], %[[M]]
    // CHECK:         yul.func_return %[[R]] : i256
    sol.func @loadByte(%arg0: !sol.string<Memory>) -> !sol.fixedbytes<1> attributes {state_mutability = #Pure} {
      %c0 = sol.constant 0 : ui8
      %0 = sol.gep %arg0, %c0 : !sol.string<Memory>, ui8, !sol.ptr<!sol.byte, Memory>
      %1 = sol.load %0 : !sol.ptr<!sol.byte, Memory>, !sol.byte
      %2 = sol.bytes_cast %1 : !sol.byte to !sol.fixedbytes<1>
      sol.return %2 : !sol.fixedbytes<1>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // A bytes element store writes the single byte.
    // CHECK-LABEL: yul.func @storeByte : (i256, i256) -> ()
    // CHECK:         %[[B:.*]] = yul.byte %{{.*}}, %arg1
    // CHECK:         yul.mstore8 %{{.*}}, %[[B]]
    sol.func @storeByte(%arg0: !sol.string<Memory>, %arg1: !sol.fixedbytes<1>) attributes {state_mutability = #Pure} {
      %c0 = sol.constant 0 : ui8
      %0 = sol.gep %arg0, %c0 : !sol.string<Memory>, ui8, !sol.ptr<!sol.byte, Memory>
      %1 = sol.bytes_cast %arg1 : !sol.fixedbytes<1> to !sol.byte
      sol.store %1, %0 : !sol.byte, !sol.ptr<!sol.byte, Memory>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @loadUint8 : (i256) -> i256
    // CHECK:         yul.mload
    // CHECK:         %[[V:.*]] = yul.mload
    // CHECK-NEXT:    yul.func_return %[[V]] : i256
    sol.func @loadUint8(%arg0: !sol.array<? x ui8, Memory>) -> ui8 attributes {state_mutability = #Pure} {
      %c0 = sol.constant 0 : ui8
      %0 = sol.gep %arg0, %c0 : !sol.array<? x ui8, Memory>, ui8, !sol.ptr<ui8, Memory>
      %1 = sol.load %0 : !sol.ptr<ui8, Memory>, ui8
      sol.return %1 : ui8
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @storeUint8 : (i256, i256) -> ()
    // CHECK:         %[[V:.*]] = yul.and %arg1, %c255_i256
    // CHECK:         yul.mstore %{{.*}}, %[[V]]
    sol.func @storeUint8(%arg0: !sol.array<? x ui8, Memory>, %arg1: ui8) attributes {state_mutability = #Pure} {
      %c0 = sol.constant 0 : ui8
      %0 = sol.gep %arg0, %c0 : !sol.array<? x ui8, Memory>, ui8, !sol.ptr<ui8, Memory>
      sol.store %arg1, %0 : ui8, !sol.ptr<ui8, Memory>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @storeInt8 : (i256, i256) -> ()
    // CHECK:         %[[V:.*]] = yul.signextend %{{.*}}, %arg1
    // CHECK:         yul.mstore %{{.*}}, %[[V]]
    sol.func @storeInt8(%arg0: !sol.array<? x si8, Memory>, %arg1: si8) attributes {state_mutability = #Pure} {
      %c0 = sol.constant 0 : ui8
      %0 = sol.gep %arg0, %c0 : !sol.array<? x si8, Memory>, ui8, !sol.ptr<si8, Memory>
      sol.store %arg1, %0 : si8, !sol.ptr<si8, Memory>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @storeBool : (i256, i256) -> ()
    // CHECK:         %[[V:.*]] = yul.cmp ne, %arg1, %{{.*}}
    // CHECK:         yul.mstore %{{.*}}, %[[V]]
    sol.func @storeBool(%arg0: !sol.array<? x i1, Memory>, %arg1: i1) attributes {state_mutability = #Pure} {
      %c0 = sol.constant 0 : ui8
      %0 = sol.gep %arg0, %c0 : !sol.array<? x i1, Memory>, ui8, !sol.ptr<i1, Memory>
      sol.store %arg1, %0 : i1, !sol.ptr<i1, Memory>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @storeEnum : (i256, i256) -> ()
    // CHECK:         %[[C2:.*]] = yul.constant 2{{$}}
    // CHECK:         %[[OOR:.*]] = yul.cmp ugt, %arg1, %[[C2]]
    // CHECK:         yul.if %[[OOR]] {
    // CHECK:           yul.constant 33
    // CHECK:         yul.mstore %{{.*}}, %arg1
    sol.func @storeEnum(%arg0: !sol.array<? x !sol.enum<2>, Memory>, %arg1: !sol.enum<2>) attributes {state_mutability = #Pure} {
      %c0 = sol.constant 0 : ui8
      %0 = sol.gep %arg0, %c0 : !sol.array<? x !sol.enum<2>, Memory>, ui8, !sol.ptr<!sol.enum<2>, Memory>
      sol.store %arg1, %0 : !sol.enum<2>, !sol.ptr<!sol.enum<2>, Memory>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @storeAddress : (i256, i256) -> ()
    // CHECK:         %[[M:.*]] = yul.constant 1461501637330902918203684832716283019655932542975
    // CHECK:         %[[V:.*]] = yul.and %arg1, %[[M]]
    // CHECK:         yul.mstore %{{.*}}, %[[V]]
    sol.func @storeAddress(%arg0: !sol.array<? x !sol.address, Memory>, %arg1: !sol.address) attributes {state_mutability = #Pure} {
      %c0 = sol.constant 0 : ui8
      %0 = sol.gep %arg0, %c0 : !sol.array<? x !sol.address, Memory>, ui8, !sol.ptr<!sol.address, Memory>
      sol.store %arg1, %0 : !sol.address, !sol.ptr<!sol.address, Memory>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @storeBytes4 : (i256, i256) -> ()
    // CHECK:         %[[M:.*]] = yul.constant -26959946667150639794667015087019630673637144422540572481103610249216
    // CHECK:         %[[V:.*]] = yul.and %arg1, %[[M]]
    // CHECK:         yul.mstore %{{.*}}, %[[V]]
    sol.func @storeBytes4(%arg0: !sol.array<? x !sol.fixedbytes<4>, Memory>, %arg1: !sol.fixedbytes<4>) attributes {state_mutability = #Pure} {
      %c0 = sol.constant 0 : ui8
      %0 = sol.gep %arg0, %c0 : !sol.array<? x !sol.fixedbytes<4>, Memory>, ui8, !sol.ptr<!sol.fixedbytes<4>, Memory>
      sol.store %arg1, %0 : !sol.fixedbytes<4>, !sol.ptr<!sol.fixedbytes<4>, Memory>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
