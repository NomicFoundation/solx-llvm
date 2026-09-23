// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

module {
  sol.contract @C {
    // The runtime index goes through the array type's indexing helper, which
    // holds the bounds check and the slot arithmetic.
    // CHECK-LABEL: yul.func @__sol.index_storage_array.array$_36893488147419103232_ui256_$_Storage_$ : (i256, i256) -> !llvm.struct<(i256, i256)>
    // CHECK-NEXT:  ^bb0(%[[ARR:.*]]: i256, %[[I:.*]]: i256):
    // CHECK:         %[[N:.*]] = yul.constant 36893488147419103232
    // CHECK:         %[[OOB:.*]] = yul.cmp uge, %[[I]], %[[N]]
    // CHECK:         yul.if %[[OOB]] {
    // CHECK:           %[[C50:.*]] = yul.constant 50
    // CHECK:           yul.func_call @__sol.panic(%[[C50]])
    // CHECK:         %[[W:.*]] = yul.arith_div %[[I]], %{{.*}}
    // CHECK:         yul.add %[[ARR]], %[[W]]
    // CHECK-LABEL: yul.func @get : (i256, i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[ARR:.*]]: i256, %[[I:.*]]: i256):
    // CHECK:         %[[REF:.*]] = yul.func_call @__sol.index_storage_array.array$_36893488147419103232_ui256_$_Storage_$(%[[ARR]], %[[I]])
    // CHECK:         %[[SLOT:.*]] = llvm.extractvalue %[[REF]][0]
    // CHECK:         yul.sload %[[SLOT]]
    sol.func @get(%a: !sol.array<36893488147419103232 x ui256, Storage>, %i: ui256) -> ui256 {
      %0 = sol.gep %a, %i : !sol.array<36893488147419103232 x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
      %1 = sol.load %0 : !sol.ptr<ui256, Storage>, ui256
      sol.return %1 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // The constant 2**64 + 7 index needs no bounds check.
    // CHECK-LABEL: yul.func @setConst : (i256, i256) -> ()
    // CHECK:         %[[IDX:.*]] = yul.constant 18446744073709551623
    // CHECK-NOT:     yul.if
    // CHECK:         yul.arith_div %[[IDX]], %{{.*}}
    // CHECK:         yul.sstore
    sol.func @setConst(%a: !sol.array<36893488147419103232 x ui256, Storage>, %v: ui256) {
      %c = sol.constant 18446744073709551623 : ui72
      %0 = sol.gep %a, %c : !sol.array<36893488147419103232 x ui256, Storage>, ui72, !sol.ptr<ui256, Storage>
      sol.store %v, %0 : ui256, !sol.ptr<ui256, Storage>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // The outer stride is the 2**64-slot inner array. The inner index goes
    // through the inner array type's helper.
    // CHECK-LABEL: yul.func @__sol.index_storage_array.array$_18446744073709551616_ui256_$_Storage_$ : (i256, i256) -> !llvm.struct<(i256, i256)>
    // CHECK-NEXT:  ^bb0(%[[INNER:.*]]: i256, %[[I:.*]]: i256):
    // CHECK:         %[[N:.*]] = yul.constant 18446744073709551616
    // CHECK:         %[[OOB:.*]] = yul.cmp uge, %[[I]], %[[N]]
    // CHECK:         yul.if %[[OOB]] {
    // CHECK:           %[[C50:.*]] = yul.constant 50
    // CHECK:           yul.func_call @__sol.panic(%[[C50]])
    // CHECK:         %[[W:.*]] = yul.arith_div %[[I]], %{{.*}}
    // CHECK:         yul.add %[[INNER]], %[[W]]
    // CHECK-LABEL: yul.func @setNested : (i256, i256) -> ()
    // CHECK-NEXT:  ^bb0(%[[ARR:.*]]: i256, %[[I:.*]]: i256):
    // CHECK:         %[[C2:.*]] = yul.constant 2
    // CHECK:         %[[STRIDE:.*]] = yul.constant 18446744073709551616
    // CHECK:         %[[OFF:.*]] = yul.mul %[[C2]], %[[STRIDE]]
    // CHECK:         %[[INNER:.*]] = yul.add %[[ARR]], %[[OFF]]
    // CHECK:         %[[REF:.*]] = yul.func_call @__sol.index_storage_array.array$_18446744073709551616_ui256_$_Storage_$(%[[INNER]], %[[I]])
    // CHECK:         %[[SLOT:.*]] = llvm.extractvalue %[[REF]][0]
    // CHECK:         yul.sstore %[[SLOT]]
    sol.func @setNested(%a: !sol.array<3 x !sol.array<18446744073709551616 x ui256, Storage>, Storage>, %i: ui256) {
      %c1 = sol.constant 1 : ui256
      %c2 = sol.constant 2 : ui8
      %0 = sol.gep %a, %c2 : !sol.array<3 x !sol.array<18446744073709551616 x ui256, Storage>, Storage>, ui8, !sol.array<18446744073709551616 x ui256, Storage>
      %1 = sol.gep %0, %i : !sol.array<18446744073709551616 x ui256, Storage>, ui256, !sol.ptr<ui256, Storage>
      sol.store %c1, %1 : ui256, !sol.ptr<ui256, Storage>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // y sits after x and the 2**64-slot array: slot 2**64 + 1.
    // CHECK-LABEL: yul.func @setStructMember : (i256) -> ()
    // CHECK-NEXT:  ^bb0(%[[S:.*]]: i256):
    // CHECK:         %[[OFF:.*]] = yul.constant 18446744073709551617
    // CHECK:         %[[P:.*]] = yul.add %[[S]], %[[OFF]]
    // CHECK:         llvm.insertvalue %[[P]], %{{.*}}[0]
    // CHECK:         yul.sstore
    sol.func @setStructMember(%s: !sol.struct<(ui256, !sol.array<18446744073709551616 x ui256, Storage>, ui256), Storage>) {
      %c1 = sol.constant 1 : ui256
      %c2 = sol.constant 2 : ui64
      %0 = sol.gep %s, %c2 : !sol.struct<(ui256, !sol.array<18446744073709551616 x ui256, Storage>, ui256), Storage>, ui64, !sol.ptr<ui256, Storage>
      sol.store %c1, %0 : ui256, !sol.ptr<ui256, Storage>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
