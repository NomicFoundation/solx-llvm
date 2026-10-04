// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

module {
  sol.contract @C {
    // Indexing is bounds-checked (panic 0x32), then base + i * 32.
    // CHECK-LABEL: yul.func @ui_1d : (i256, i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[BASE:.*]]: i256, %[[I:.*]]: i256):
    // CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
    // CHECK:         %[[OOB:.*]] = yul.cmp uge, %[[I]], %[[C3]]
    // CHECK:         yul.if %[[OOB]] {
    // CHECK:           %[[C50:.*]] = yul.constant 50
    // CHECK:           yul.mstore %{{.*}}, %[[C50]]
    // CHECK:         %[[OFF:.*]] = yul.mul %[[I]], %{{.*}}
    // CHECK:         %[[P:.*]] = yul.add %[[BASE]], %[[OFF]]
    // CHECK:         %[[V:.*]] = yul.mload %[[P]]
    // CHECK:         yul.func_return %[[V]] : i256
    sol.func @ui_1d(%a: !sol.array<3 x ui256, Memory>, %i: ui256) -> ui256 {
      %0 = sol.gep %a, %i : !sol.array<3 x ui256, Memory>, ui256, !sol.ptr<ui256, Memory>
      %1 = sol.load %0 : !sol.ptr<ui256, Memory>, ui256
      sol.return %1 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // The outer element is a pointer to the inner array.
    // CHECK-LABEL: yul.func @ui_2d : (i256, i256) -> i256
    // CHECK:         %[[C4:.*]] = yul.constant 4{{$}}
    // CHECK:         yul.cmp uge, %{{.*}}, %[[C4]]
    // CHECK:         %[[INNER:.*]] = yul.mload
    // CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
    // CHECK:         yul.cmp uge, %{{.*}}, %[[C3]]
    // CHECK:         %[[P:.*]] = yul.add %[[INNER]], %{{.*}}
    // CHECK:         %[[V:.*]] = yul.mload %[[P]]
    // CHECK:         yul.func_return %[[V]] : i256
    sol.func @ui_2d(%a: !sol.array<4 x !sol.array<3 x ui256, Memory>, Memory>, %i: ui256) -> ui256 {
      %0 = sol.gep %a, %i : !sol.array<4 x !sol.array<3 x ui256, Memory>, Memory>, ui256, !sol.ptr<!sol.array<3 x ui256, Memory>, Memory>
      %1 = sol.load %0 : !sol.ptr<!sol.array<3 x ui256, Memory>, Memory>, !sol.array<3 x ui256, Memory>
      %2 = sol.gep %1, %i : !sol.array<3 x ui256, Memory>, ui256, !sol.ptr<ui256, Memory>
      %3 = sol.load %2 : !sol.ptr<ui256, Memory>, ui256
      sol.return %3 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // A narrow element is cleaned on store.
    // CHECK-LABEL: yul.func @ui32_1d : (i256, i256, i256) -> ()
    // CHECK-NEXT:  ^bb0(%{{.*}}: i256, %{{.*}}: i256, %[[V:.*]]: i256):
    // CHECK:         %[[M:.*]] = yul.constant 4294967295
    // CHECK:         %[[CV:.*]] = yul.and %[[V]], %[[M]]
    // CHECK:         yul.mstore %{{.*}}, %[[CV]]
    sol.func @ui32_1d(%a: !sol.array<3 x ui32, Memory>, %i: ui256, %v: ui32) {
      %0 = sol.gep %a, %i : !sol.array<3 x ui32, Memory>, ui256, !sol.ptr<ui32, Memory>
      sol.store %v, %0 : ui32, !sol.ptr<ui32, Memory>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // A static array's length is a constant.
    // CHECK-LABEL: yul.func @len : (i256, i256) -> (i256, i256)
    // CHECK-NEXT:  ^bb0(%[[D:.*]]: i256, %{{.*}}: i256):
    // CHECK:         %[[LEN:.*]] = yul.mload %[[D]]
    // CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
    // CHECK:         yul.func_return %[[LEN]], %[[C3]] : i256, i256
    sol.func @len(%d: !sol.array<? x ui256, Memory>, %s: !sol.array<3 x ui256, Memory>) -> (ui256, ui256) {
      %0 = sol.length %d : !sol.array<? x ui256, Memory>
      %1 = sol.length %s : !sol.array<3 x ui256, Memory>
      sol.return %0, %1 : ui256, ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @lit_2d : () -> i256
    // CHECK:         %[[R0:.*]] = yul.mload
    // CHECK:         yul.mstore %[[R0]], %{{.*}}
    // CHECK:         %[[R1:.*]] = yul.mload
    // CHECK:         yul.mstore %[[R1]], %{{.*}}
    // CHECK:         %[[OUT:.*]] = yul.mload
    // CHECK:         yul.mstore %[[OUT]], %[[R0]]
    // CHECK:         %[[O1:.*]] = yul.add %[[OUT]], %{{.*}}
    // CHECK:         yul.mstore %[[O1]], %[[R1]]
    sol.func @lit_2d() -> !sol.array<2 x !sol.array<2 x ui256, Memory>, Memory> {
      %c10 = sol.constant 10 : ui256
      %c11 = sol.constant 11 : ui256
      %0 = sol.array_lit %c10, %c11 : (ui256, ui256) -> !sol.array<2 x ui256, Memory>
      %c20 = sol.constant 20 : ui256
      %c21 = sol.constant 21 : ui256
      %1 = sol.array_lit %c20, %c21 : (ui256, ui256) -> !sol.array<2 x ui256, Memory>
      %2 = sol.array_lit %0, %1 : (!sol.array<2 x ui256, Memory>, !sol.array<2 x ui256, Memory>) -> !sol.array<2 x !sol.array<2 x ui256, Memory>, Memory>
      sol.return %2 : !sol.array<2 x !sol.array<2 x ui256, Memory>, Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // A calldata array is an (offset, length) pair.
    // CHECK-LABEL: yul.func @cd_arr : (!llvm.struct<(i256, i256)>) -> (i256, i256)
    // CHECK:         %[[LEN:.*]] = llvm.extractvalue %{{.*}}[1]
    // CHECK:         %[[LEN2:.*]] = llvm.extractvalue %{{.*}}[1]
    // CHECK:         yul.cmp uge, %{{.*}}, %[[LEN2]]
    // CHECK:         %[[OFF:.*]] = llvm.extractvalue %{{.*}}[0]
    // CHECK:         %[[P:.*]] = yul.add %[[OFF]], %{{.*}}
    // CHECK:         %[[V:.*]] = yul.calldataload %[[P]]
    // CHECK:         yul.func_return %[[LEN]], %[[V]] : i256, i256
    sol.func @cd_arr(%a: !sol.array<? x ui256, CallData>) -> (ui256, ui256) {
      %0 = sol.length %a : !sol.array<? x ui256, CallData>
      %c0_ui8 = sol.constant 0 : ui8
      %1 = sol.gep %a, %c0_ui8 : !sol.array<? x ui256, CallData>, ui8, !sol.ptr<ui256, CallData>
      %2 = sol.load %1 : !sol.ptr<ui256, CallData>, ui256
      sol.return %0, %2 : ui256, ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // The default calldata array is an empty slice at calldatasize.
    // CHECK-LABEL: yul.func @default_cd : () -> !llvm.struct<(i256, i256)>
    // CHECK:         %[[CDS:.*]] = yul.calldatasize
    // CHECK:         %[[S0:.*]] = llvm.insertvalue %[[CDS]], %{{.*}}[0]
    // CHECK:         %[[DEF:.*]] = llvm.insertvalue %{{.*}}, %[[S0]][1]
    // CHECK:         yul.func_return %[[DEF]] : !llvm.struct<(i256, i256)>
    sol.func @default_cd() -> !sol.array<? x ui256, CallData> {
      %0 = sol.default_calldata : !sol.array<? x ui256, CallData>
      sol.return %0 : !sol.array<? x ui256, CallData>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @stg_arr : (i256) -> (i256, i256)
    // CHECK:         %[[LEN:.*]] = yul.sload
    // CHECK:         %[[LEN2:.*]] = yul.sload %[[SLOT:.*]]
    // CHECK:         yul.cmp uge, %{{.*}}, %[[LEN2]]
    // CHECK:         yul.mstore %{{.*}}, %[[SLOT]]
    // CHECK:         %[[DATA:.*]] = yul.keccak256
    // CHECK:         %[[ES:.*]] = yul.add %[[DATA]], %{{.*}}
    // CHECK:         %[[W:.*]] = yul.sload
    // CHECK:         %[[V:.*]] = yul.arith_shr %[[W]], %{{.*}}
    // CHECK:         yul.func_return %[[LEN]], %[[V]] : i256, i256
    sol.func @stg_arr(%a: !sol.array<? x ui256, Storage>) -> (ui256, ui256) {
      %0 = sol.length %a : !sol.array<? x ui256, Storage>
      %c0_ui8 = sol.constant 0 : ui8
      %1 = sol.gep %a, %c0_ui8 : !sol.array<? x ui256, Storage>, ui8, !sol.ptr<ui256, Storage>
      %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
      sol.return %0, %2 : ui256, ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
