// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The element spans 9 slots. Each member is cleared by kind: a plain slot,
// the bytes17[3] loop, the string tail, the uint256[] data, flag+direction
// sharing slot 6 and the nested bool[][].
// CHECK-LABEL: yul.func @pop : (i256) -> ()
// CHECK-NEXT:  ^bb0(%[[SLOT:.*]]: i256):
// CHECK:         %[[LEN:.*]] = yul.sload %[[SLOT]]
// CHECK:         yul.constant 49
// CHECK:         %[[NEW:.*]] = yul.sub %[[LEN]], %{{.*}}
// CHECK:         %[[DATA:.*]] = yul.keccak256
// CHECK:         %[[C9:.*]] = yul.constant 9{{$}}
// CHECK:         %[[OFF:.*]] = yul.mul %[[NEW]], %[[C9]]
// CHECK:         %[[ELT:.*]] = yul.add %[[DATA]], %[[OFF]]
// CHECK:         yul.sstore
// CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
// CHECK:         %[[CS:.*]] = yul.add %[[ELT]], %[[C1]]
// CHECK:         yul.for
// CHECK:           yul.add %[[CS]], %{{.*}}
// CHECK:         } {full_unroll}
// CHECK:         %[[C4:.*]] = yul.constant 4{{$}}
// CHECK:         %[[DS:.*]] = yul.add %[[ELT]], %[[C4]]
// CHECK:         %[[DLEN:.*]] = yul.arith_select
// CHECK:         yul.func_call @__sol.clear_string_tail(%[[DS]], %[[DLEN]], %{{.*}})
// CHECK:         yul.sstore %[[DS]], %{{.*}}
// CHECK:         %[[C5:.*]] = yul.constant 5{{$}}
// CHECK:         %[[ES:.*]] = yul.add %[[ELT]], %[[C5]]
// CHECK:         yul.sload %[[ES]]
// CHECK:         yul.sstore %[[ES]], %{{.*}}
// CHECK:         yul.for
// CHECK:         %[[C6:.*]] = yul.constant 6{{$}}
// CHECK:         %[[FLAG:.*]] = yul.add %[[ELT]], %[[C6]]
// CHECK:         yul.sstore %[[FLAG]], %{{.*}}
// CHECK:         %[[C7:.*]] = yul.constant 7{{$}}
// CHECK:         %[[INNER:.*]] = yul.add %[[ELT]], %[[C7]]
// CHECK:         %[[X:.*]] = yul.add %[[INNER]], %{{.*}}
// CHECK:         yul.sstore %[[X]], %{{.*}}
// CHECK:         %[[FLAGS:.*]] = yul.add %[[INNER]], %{{.*}}
// CHECK:         yul.sload %[[FLAGS]]
// CHECK:         yul.sstore %[[FLAGS]], %{{.*}}
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:         yul.sstore %[[SLOT]], %[[NEW]]
// CHECK-LABEL: yul.func @__sol.clear_string_tail : (i256, i256, i256) -> ()

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @pop(%a: !sol.array<? x !sol.struct<(ui8, !sol.array<3 x !sol.fixedbytes<17>, Storage>, !sol.string<Storage>, !sol.array<? x ui256, Storage>, i1, !sol.enum<3>, !sol.struct<(ui256, !sol.array<? x !sol.array<? x i1, Storage>, Storage>), Storage>), Storage>, Storage>) {
    sol.pop %a : !sol.array<? x !sol.struct<(ui8, !sol.array<3 x !sol.fixedbytes<17>, Storage>, !sol.string<Storage>, !sol.array<? x ui256, Storage>, i1, !sol.enum<3>, !sol.struct<(ui256, !sol.array<? x !sol.array<? x i1, Storage>, Storage>), Storage>), Storage>, Storage>
    sol.return
  }
}
