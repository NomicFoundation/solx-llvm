// RUN: mlir-opt -yul-fuse-free-ptr %s | FileCheck %s

module {
  sol.contract @C {

    // CHECK-LABEL: sol.func @f()
    // CHECK:         %[[C1:.*]] = arith.constant 1 : i256
    // CHECK:         %[[C2:.*]] = arith.constant 2 : i256
    // CHECK:         %[[SZ:.*]] = arith.addi %[[C2]], %[[C1]] : i256
    // CHECK-NEXT:    %[[A:.*]] = yul.upd_free_ptr %[[SZ]]
    // CHECK-NEXT:    arith.addi %[[A]], %[[C1]] : i256
    // CHECK-NEXT:    sol.return
    sol.func @f() {
      %c1 = arith.constant 1 : i256
      %c2 = arith.constant 2 : i256
      %a = yul.upd_free_ptr %c1
      %b = yul.upd_free_ptr %c2
      sol.return
    }

    // The mstore between the second and third update keeps the third separate.
    // CHECK-LABEL: sol.func @g(
    // CHECK-SAME:    %[[I:.*]]: i256, %[[J:.*]]: i256)
    // CHECK:         %[[SZ:.*]] = arith.addi %[[J]], %[[I]] : i256
    // CHECK-NEXT:    %[[A:.*]] = yul.upd_free_ptr %[[SZ]]
    // CHECK-NEXT:    %[[B:.*]] = arith.addi %[[A]], %[[I]] : i256
    // CHECK-NEXT:    yul.mstore %[[B]], %[[A]]
    // CHECK-NEXT:    yul.upd_free_ptr %[[J]]
    // CHECK-NEXT:    sol.return
    sol.func @g(%i : i256, %j : i256) {
      %a = yul.upd_free_ptr %i
      %b = yul.upd_free_ptr %j
      yul.mstore %b, %a
      %c = yul.upd_free_ptr %j
      sol.return
    }

  } {kind = #sol<ContractKind Contract>, runtime}
}
