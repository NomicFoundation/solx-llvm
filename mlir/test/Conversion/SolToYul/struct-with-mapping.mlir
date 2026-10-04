// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The mapping member hashes the key with its own slot (struct base + 1); the
// members around it keep their slots 0 and 2.
// CHECK-LABEL: yul.func @get : (i256, i256) -> (i256, i256, i256)
// CHECK-NEXT:  ^bb0(%[[S:.*]]: i256, %[[K:.*]]: i256):
// CHECK:         yul.add %[[S]], %{{.*}}
// CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
// CHECK:         %[[MSLOT:.*]] = yul.add %[[S]], %[[C1]]
// CHECK:         yul.mstore %[[Z:.*]], %[[K]]
// CHECK:         yul.mstore %{{.*}}, %[[MSLOT]]
// CHECK:         yul.keccak256 %[[Z]]
// CHECK:         %[[C2:.*]] = yul.constant 2{{$}}
// CHECK:         yul.add %[[S]], %[[C2]]
// CHECK-COUNT-3: yul.sload
// CHECK:         yul.func_return

module {
  sol.contract @C {
    sol.func @get(%s: !sol.struct<(ui256, !sol.mapping<ui256, ui256>, ui256), Storage>, %k: ui256) -> (ui256, ui256, ui256) {
      %c0 = sol.constant 0 : ui64
      %c1 = sol.constant 1 : ui64
      %c2 = sol.constant 2 : ui64
      %0 = sol.gep %s, %c0 : !sol.struct<(ui256, !sol.mapping<ui256, ui256>, ui256), Storage>, ui64, !sol.ptr<ui256, Storage>
      %1 = sol.gep %s, %c1 : !sol.struct<(ui256, !sol.mapping<ui256, ui256>, ui256), Storage>, ui64, !sol.mapping<ui256, ui256>
      %2 = sol.map %1, %k : !sol.mapping<ui256, ui256>, ui256, !sol.ptr<ui256, Storage>
      %3 = sol.gep %s, %c2 : !sol.struct<(ui256, !sol.mapping<ui256, ui256>, ui256), Storage>, ui64, !sol.ptr<ui256, Storage>
      %4 = sol.load %0 : !sol.ptr<ui256, Storage>, ui256
      %5 = sol.load %2 : !sol.ptr<ui256, Storage>, ui256
      %6 = sol.load %3 : !sol.ptr<ui256, Storage>, ui256
      sol.return %4, %5, %6 : ui256, ui256, ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
