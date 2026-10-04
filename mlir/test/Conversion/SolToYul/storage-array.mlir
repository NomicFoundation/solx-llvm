// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// An element is at (slot + i / per-slot, (i % per-slot) * size): 1 uint256 or
// 32 uint8 per slot.

// CHECK-LABEL: yul.func @dyn256 : (i256, i256) -> ()
// CHECK:         %[[LEN:.*]] = yul.sload %arg0
// CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
// CHECK:         %[[NLEN:.*]] = yul.add %[[LEN]], %[[C1]]
// CHECK:         yul.sstore %arg0, %[[NLEN]]
// CHECK:         %[[DATA:.*]] = yul.keccak256
// CHECK:         %[[PER:.*]] = yul.constant 1{{$}}
// CHECK:         %[[Q:.*]] = yul.arith_div %[[LEN]], %[[PER]]
// CHECK:         yul.add %[[DATA]], %[[Q]]
// CHECK:         yul.sstore

// pop(): empty-pop panic 0x31.
// CHECK:         %[[LEN:.*]] = yul.sload %arg0
// CHECK:         %[[EMPTY:.*]] = yul.cmp eq, %[[LEN]], %{{.*}}
// CHECK:         yul.if %[[EMPTY]] {
// CHECK:           %[[P49:.*]] = yul.constant 49{{$}}
// CHECK:           yul.mstore %{{.*}}, %[[P49]]
// CHECK:           yul.revert
// CHECK:         %[[NLEN:.*]] = yul.sub %[[LEN]], %{{.*}}
// CHECK:         %[[PDATA:.*]] = yul.keccak256
// CHECK:         %[[E:.*]] = yul.add %[[PDATA]], %{{.*}}
// CHECK:         %[[Z:.*]] = yul.constant 0{{$}}
// CHECK-NEXT:    yul.sstore %[[E]], %[[Z]]
// CHECK:         yul.sstore %arg0, %[[NLEN]]

// CHECK-LABEL: yul.func @dyn8 : (i256, i256) -> ()
// CHECK:         %[[LEN:.*]] = yul.sload %arg0
// CHECK:         yul.sstore %arg0, %{{.*}}
// CHECK:         yul.keccak256
// CHECK:         %[[PER:.*]] = yul.constant 32{{$}}
// CHECK:         yul.arith_div %[[LEN]], %[[PER]]
// CHECK:         yul.arith_mod %[[LEN]], %[[PER]]
// CHECK:         %[[M:.*]] = yul.constant 255{{$}}
// CHECK:         yul.and %arg1, %[[M]]
// CHECK:         %[[FM:.*]] = yul.constant 255{{$}}
// CHECK:         yul.arith_shl %[[FM]], %{{.*}}
// CHECK:         yul.sstore

// pop(): clear the popped byte of a partial last slot, else the slot.
// CHECK:         %[[LEN:.*]] = yul.sload %arg0
// CHECK:         yul.constant 49{{$}}
// CHECK:         %[[NLEN:.*]] = yul.sub %[[LEN]], %{{.*}}
// CHECK:         %[[REM:.*]] = yul.arith_mod %[[NLEN]], %{{.*}}
// CHECK:         %[[PARTIAL:.*]] = yul.cmp ne, %[[REM]], %{{.*}}
// CHECK:         yul.if %[[PARTIAL]] {
// CHECK:           %[[ONES:.*]] = yul.constant -1{{$}}
// CHECK:           %[[KEEP:.*]] = yul.arith_shr %[[ONES]], %{{.*}}
// CHECK:           yul.and %{{.*}}, %[[KEEP]]
// CHECK:           yul.sstore
// CHECK:         } else {
// CHECK:           %[[Z:.*]] = yul.constant 0{{$}}
// CHECK-NEXT:      yul.sstore %{{.*}}, %[[Z]]
// CHECK:         }
// CHECK:         yul.sstore %arg0, %[[NLEN]]

// A non-packable element is slot-aligned: data + len * slots-per-element.
// CHECK-LABEL: yul.func @pushStruct : (i256) -> i256
// CHECK:         %[[LEN:.*]] = yul.sload %arg0
// CHECK:         %[[DATA:.*]] = yul.keccak256
// CHECK:         %[[C2:.*]] = yul.constant 2{{$}}
// CHECK:         %[[OFF:.*]] = yul.mul %[[LEN]], %[[C2]]
// CHECK:         %[[R:.*]] = yul.add %[[DATA]], %[[OFF]]
// CHECK:         yul.func_return %[[R]] : i256

// a[0] = a[1]: a constant index into a static array has no bounds check.
// CHECK-LABEL: yul.func @static8 : (i256) -> ()
// CHECK:         %[[I1:.*]] = yul.constant 1{{$}}
// CHECK-NOT:     yul.cmp uge
// CHECK:         %[[PER:.*]] = yul.constant 32{{$}}
// CHECK:         %[[Q:.*]] = yul.arith_div %[[I1]], %[[PER]]
// CHECK:         yul.add %arg0, %[[Q]]
// CHECK:         %[[S:.*]] = yul.arith_shr
// CHECK:         %[[M:.*]] = yul.constant 255{{$}}
// CHECK:         %[[V:.*]] = yul.and %[[S]], %[[M]]
// CHECK:         %[[I0:.*]] = yul.constant 0{{$}}
// CHECK-NOT:     yul.cmp uge
// CHECK:         yul.arith_div %[[I0]], %{{.*}}
// CHECK:         %[[VC:.*]] = yul.and %[[V]], %{{.*}}
// CHECK:         %[[FM:.*]] = yul.constant 255{{$}}
// CHECK:         yul.arith_shl %[[FM]], %{{.*}}
// CHECK:         yul.arith_shl %[[VC]], %{{.*}}
// CHECK:         yul.sstore

// 32 bools per slot.
// CHECK-LABEL: yul.func @dynBool : (i256, i256) -> i256
// CHECK:         yul.keccak256
// CHECK:         %[[C32:.*]] = yul.constant 32{{$}}
// CHECK:         yul.arith_div %arg1, %[[C32]]
// CHECK:         yul.arith_mod %arg1, %[[C32]]
// CHECK:         %[[S:.*]] = yul.sload
// CHECK:         %[[SH:.*]] = yul.arith_shr %[[S]], %{{.*}}
// CHECK:         %[[MASK:.*]] = yul.constant 255{{$}}
// CHECK:         %[[M:.*]] = yul.and %[[SH]], %[[MASK]]
// CHECK:         %[[B:.*]] = yul.cmp ne, %[[M]], %{{.*}}
// CHECK:         yul.func_return %[[B]] : i256

sol.func @dyn256(%a: !sol.array<? x ui256, Storage>, %v: ui256) {
  %0 = sol.push %a : !sol.array<? x ui256, Storage> -> !sol.ptr<ui256, Storage>
  sol.store %v, %0 : ui256, !sol.ptr<ui256, Storage>
  sol.pop %a : !sol.array<? x ui256, Storage>
  sol.return
}

sol.func @dyn8(%a: !sol.array<? x ui8, Storage>, %v: ui8) {
  %0 = sol.push %a : !sol.array<? x ui8, Storage> -> !sol.ptr<ui8, Storage>
  sol.store %v, %0 : ui8, !sol.ptr<ui8, Storage>
  sol.pop %a : !sol.array<? x ui8, Storage>
  sol.return
}

sol.func @pushStruct(%a: !sol.array<? x !sol.struct<(ui256, ui256), Storage>, Storage>) -> !sol.struct<(ui256, ui256), Storage> {
  %0 = sol.push %a : !sol.array<? x !sol.struct<(ui256, ui256), Storage>, Storage> -> !sol.struct<(ui256, ui256), Storage>
  sol.return %0 : !sol.struct<(ui256, ui256), Storage>
}

sol.func @static8(%a: !sol.array<4 x ui8, Storage>) {
  %c1 = sol.constant 1 : ui8
  %0 = sol.gep %a, %c1 : !sol.array<4 x ui8, Storage>, ui8, !sol.ptr<ui8, Storage>
  %1 = sol.load %0 : !sol.ptr<ui8, Storage>, ui8
  %c0 = sol.constant 0 : ui8
  %2 = sol.gep %a, %c0 : !sol.array<4 x ui8, Storage>, ui8, !sol.ptr<ui8, Storage>
  sol.store %1, %2 : ui8, !sol.ptr<ui8, Storage>
  sol.return
}

sol.func @dynBool(%a: !sol.array<? x i1, Storage>, %i: ui256) -> i1 {
  %0 = sol.gep %a, %i : !sol.array<? x i1, Storage>, ui256, !sol.ptr<i1, Storage>
  %1 = sol.load %0 : !sol.ptr<i1, Storage>, i1
  sol.return %1 : i1
}
