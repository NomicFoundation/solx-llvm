// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Memory array elements are cleaned, not validated.
// CHECK-LABEL: yul.func @packed_u8_memory : (i256) -> i256
// CHECK:         } body {
// CHECK-NEXT:    ^bb0(%{{.*}}: i256, %[[DST:.*]]: i256, %[[SRC:.*]]: i256):
// CHECK-NEXT:      %[[E:.*]] = yul.mload %[[SRC]]
// CHECK-NEXT:      %[[M:.*]] = yul.constant 255
// CHECK-NEXT:      %[[C:.*]] = yul.and %[[E]], %[[M]]
// CHECK-NEXT:      yul.mstore %[[DST]], %[[C]]

// Packed arrays keep their 32-byte element stride.
// CHECK-LABEL: yul.func @packed_fnptr_memory : (i256) -> i256
// CHECK:         } body {
// CHECK-NEXT:    ^bb0(%{{.*}}: i256, %[[DST:.*]]: i256, %[[SRC:.*]]: i256):
// CHECK-NEXT:      %[[E:.*]] = yul.mload %[[SRC]]
// CHECK-NEXT:      %[[M:.*]] = yul.constant -18446744073709551616
// CHECK-NEXT:      %[[C:.*]] = yul.and %[[E]], %[[M]]
// CHECK-NEXT:      yul.mstore %[[DST]], %[[C]]
// CHECK-NEXT:      %[[STRIDE:.*]] = yul.constant 32
// CHECK-NEXT:      yul.add %[[DST]], %[[STRIDE]]

// Calldata array elements are validated before being encoded. Unlike packed
// mode, the head holds the tail offset and the tail starts with the length.
// CHECK-LABEL: yul.func @u8_calldata : (!llvm.struct<(i256, i256)>) -> i256
// CHECK-NEXT:  ^bb0(%[[ARR:.*]]: !llvm.struct<(i256, i256)>):
// CHECK:         %[[HEAD:.*]] = yul.add
// CHECK:         %[[TAIL:.*]] = yul.add %[[HEAD]],
// CHECK:         %[[OFF:.*]] = yul.sub %[[TAIL]], %[[HEAD]]
// CHECK:         yul.mstore %[[HEAD]], %[[OFF]]
// CHECK:         %[[LEN:.*]] = llvm.extractvalue %[[ARR]][1]
// CHECK:         %[[DATA:.*]] = llvm.extractvalue %[[ARR]][0]
// CHECK:         yul.mstore %[[TAIL]], %[[LEN]]
// CHECK:         yul.for %{{.*}}, %{{.*}}, %[[DATA]], %{{.*}} :
// CHECK:         } body {
// CHECK-NEXT:    ^bb0(%{{.*}}: i256, %[[DST:.*]]: i256, %[[SRC:.*]]: i256, %{{.*}}: i256):
// CHECK-NEXT:      %[[E:.*]] = yul.calldataload %[[SRC]]
// CHECK-NEXT:      %[[M:.*]] = yul.constant 255
// CHECK-NEXT:      %[[C:.*]] = yul.and %[[E]], %[[M]]
// CHECK-NEXT:      %[[D:.*]] = yul.cmp ne, %[[E]], %[[C]]
// CHECK-NEXT:      yul.if %[[D]] {
// CHECK:           yul.mstore %[[DST]], %[[C]]

// CHECK-LABEL: yul.func @nested_u8_calldata : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         } body {
// CHECK-NEXT:    ^bb0(%{{.*}}: i256, %{{.*}}: i256, %[[SRC:.*]]: i256, %{{.*}}: i256):
// CHECK-NEXT:      %[[OFF:.*]] = yul.calldataload %[[SRC]]
// CHECK:           yul.cmp sge, %[[OFF]], %{{.*}}
// CHECK:           %[[INNER:.*]] = yul.add %{{.*}}, %[[OFF]]
// CHECK:           %[[LEN:.*]] = yul.calldataload %[[INNER]]
// CHECK:           llvm.insertvalue %[[LEN]], %{{.*}}[1]
// CHECK:           } body {
// CHECK-NEXT:      ^bb0(%{{.*}}: i256, %[[IDST:.*]]: i256, %[[ISRC:.*]]: i256, %{{.*}}: i256):
// CHECK-NEXT:        %[[E:.*]] = yul.calldataload %[[ISRC]]
// CHECK-NEXT:        %[[M:.*]] = yul.constant 255
// CHECK-NEXT:        %[[C:.*]] = yul.and %[[E]], %[[M]]
// CHECK-NEXT:        yul.cmp ne, %[[E]], %[[C]]
// CHECK:             yul.mstore %[[IDST]], %[[C]]

// Each element offset read from calldata is bounds-checked against the
// remaining calldata, less the element's static size minus one (63 for a
// uint[][2]).
// CHECK-LABEL: yul.func @nested_dyn_static_dyn_calldata : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         yul.for
// CHECK:         } body {
// CHECK:           %[[REL:.*]] = yul.calldataload
// CHECK:           %[[C63:.*]] = yul.constant 63
// CHECK:           %[[LIM:.*]] = yul.sub %{{.*}}, %[[C63]]
// CHECK:           %[[BAD:.*]] = yul.cmp sge, %[[REL]], %[[LIM]]
// CHECK:           yul.if %[[BAD]] {
// CHECK:           %[[ELEM:.*]] = yul.add %{{.*}}, %[[REL]]
// CHECK:           yul.for %{{.*}}, %{{.*}}, %[[ELEM]], %{{.*}} :
// CHECK:           } body {
// CHECK:             %[[IREL:.*]] = yul.calldataload
// CHECK:             %[[C31:.*]] = yul.constant 31
// CHECK:             %[[ILIM:.*]] = yul.sub %{{.*}}, %[[C31]]
// CHECK:             yul.cmp sge, %[[IREL]], %[[ILIM]]
// CHECK:             %[[IELEM:.*]] = yul.add %[[ELEM]], %[[IREL]]
// CHECK:             %[[LEN:.*]] = yul.calldataload %[[IELEM]]
// CHECK:             %[[DATA:.*]] = yul.add %[[IELEM]], %{{.*}}
// CHECK:             yul.calldatacopy %{{.*}}, %{{.*}}, %{{.*}}

// Static inner arrays are encoded in place: the head is len * 128 for
// uint[2][2][], with each uint[2] taking 64 bytes.
// CHECK-LABEL: yul.func @nested_static_memory : (i256) -> i256
// CHECK:         %[[OFFS:.*]] = yul.sub
// CHECK:         yul.mstore %{{.*}}, %[[OFFS]]
// CHECK:         %[[LEN:.*]] = yul.mload
// CHECK:         %[[STRIDE:.*]] = yul.constant 128
// CHECK-NEXT:    %[[HSZ:.*]] = yul.mul %[[LEN]], %[[STRIDE]]
// CHECK:         %[[TAIL:.*]] = yul.add %{{.*}}, %[[HSZ]]
// CHECK:         yul.for {{.*}}, %[[TAIL]] :
// CHECK:           %[[ISTRIDE:.*]] = yul.constant 64
// CHECK:           yul.for
// CHECK:             yul.for
// CHECK:           yul.add %{{.*}}, %[[ISTRIDE]]
// CHECK:         yul.add %{{.*}}, %[[STRIDE]]

// Packed array elements are still padded to 32 bytes each.
// CHECK-LABEL: yul.func @packed_nested_u16_memory : (i256) -> i256
// CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
// CHECK:         %[[C64:.*]] = yul.constant 64{{$}}
// CHECK:         yul.mul %[[C3]], %[[C64]]
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.mload
// CHECK:             %[[M:.*]] = yul.constant 65535
// CHECK:             %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK:             yul.mstore %{{.*}}, %[[C]]

// CHECK-LABEL: yul.func @packed_nested_u16_calldata : (i256) -> i256
// CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
// CHECK:         %[[C64:.*]] = yul.constant 64{{$}}
// CHECK:         yul.mul %[[C3]], %[[C64]]
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.calldataload
// CHECK:             %[[M:.*]] = yul.constant 65535
// CHECK:             %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK:             %[[BAD:.*]] = yul.cmp ne, %[[V]], %[[C]]
// CHECK:             yul.if %[[BAD]] {
// CHECK:               yul.revert
// CHECK:             yul.mstore %{{.*}}, %[[C]]

// The innermost uint256[4] is contiguous in calldata and copied whole.
// CHECK-LABEL: yul.func @packed_nested_u256_calldata : (i256) -> i256
// CHECK:         %[[C640:.*]] = yul.constant 640
// CHECK:         yul.mul %{{.*}}, %[[C640]]
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:           } body {
// CHECK-NEXT:      ^bb0(%{{.*}}: i256, %[[DST:.*]]: i256, %[[SRC:.*]]: i256):
// CHECK-NEXT:        %[[N:.*]] = yul.constant 4{{$}}
// CHECK-NEXT:        %[[W:.*]] = yul.constant 32{{$}}
// CHECK:             yul.mul %[[N]], %[[W]]
// CHECK:             %[[SZ:.*]] = yul.mul %[[N]], %[[W]]
// CHECK-NEXT:        yul.calldatacopy %[[DST]], %[[SRC]], %[[SZ]]

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @packed_u8_memory(%arg0: !sol.array<? x ui8, Memory>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.array<? x ui8, Memory> : !sol.string<Memory> {packed}
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @packed_fnptr_memory(%arg0: !sol.array<? x !sol.ext_func_ref<(ui256) -> ui256>, Memory>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.array<? x !sol.ext_func_ref<(ui256) -> ui256>, Memory> : !sol.string<Memory> {packed}
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @u8_calldata(%arg0: !sol.array<? x ui8, CallData>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.array<? x ui8, CallData> : !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @nested_u8_calldata(%arg0: !sol.array<? x !sol.array<? x ui8, CallData>, CallData>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.array<? x !sol.array<? x ui8, CallData>, CallData> : !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @nested_dyn_static_dyn_calldata(%arg0: !sol.array<? x !sol.array<2 x !sol.array<? x ui256, CallData>, CallData>, CallData>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.array<? x !sol.array<2 x !sol.array<? x ui256, CallData>, CallData>, CallData> : !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @nested_static_memory(%arg0: !sol.array<? x !sol.array<2 x !sol.array<2 x ui256, Memory>, Memory>, Memory>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.array<? x !sol.array<2 x !sol.array<2 x ui256, Memory>, Memory>, Memory> : !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @packed_nested_u16_memory(%arg0: !sol.array<3 x !sol.array<2 x ui16, Memory>, Memory>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.array<3 x !sol.array<2 x ui16, Memory>, Memory> : !sol.string<Memory> {packed}
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @packed_nested_u16_calldata(%arg0: !sol.array<3 x !sol.array<2 x ui16, CallData>, CallData>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.array<3 x !sol.array<2 x ui16, CallData>, CallData> : !sol.string<Memory> {packed}
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @packed_nested_u256_calldata(%arg0: !sol.array<4 x !sol.array<5 x !sol.array<4 x ui256, CallData>, CallData>, CallData>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.array<4 x !sol.array<5 x !sol.array<4 x ui256, CallData>, CallData>, CallData> : !sol.string<Memory> {packed}
    sol.return %0 : !sol.string<Memory>
  }
}
