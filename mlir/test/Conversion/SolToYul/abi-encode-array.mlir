// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

module {
  sol.contract @C {
    // Memory array elements are cleaned, not validated.
    // CHECK-LABEL: yul.func @__sol.abi_encode_array.memory.packed.inplace.array$_dyn_ui8_$_Memory_$ : (i256, i256, i256) -> i256
    // CHECK:         } body {
    // CHECK-NEXT:    ^bb0(%{{.*}}: i256, %[[DST:.*]]: i256, %[[SRC:.*]]: i256):
    // CHECK-NEXT:      %[[E:.*]] = yul.mload %[[SRC]]
    // CHECK-NEXT:      %[[M:.*]] = yul.constant 255
    // CHECK-NEXT:      %[[C:.*]] = yul.and %[[E]], %[[M]]
    // CHECK-NEXT:      yul.mstore %[[DST]], %[[C]]
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.packed.inplace.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
    // CHECK:         %[[LEN:.*]] = yul.mload %arg0
    // CHECK-NEXT:    yul.func_call @__sol.abi_encode_array.memory.packed.inplace.array$_dyn_ui8_$_Memory_$(%arg0, %arg1, %[[LEN]])
    // CHECK-LABEL: yul.func @packed_u8_memory : (i256) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.packed.inplace.array$_dyn_ui8_$_Memory_$(%arg0,
    sol.func @packed_u8_memory(%arg0: !sol.array<? x ui8, Memory>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.array<? x ui8, Memory>) -> !sol.string<Memory> {packed}
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // Packed arrays keep their 32-byte element stride.
    // CHECK-LABEL: yul.func @__sol.abi_encode_array.memory.packed.inplace.array$_dyn_ext_func_ref$_$_ui256_$returnsui256_$_$_Memory_$ : (i256, i256, i256) -> i256
    // CHECK:         } body {
    // CHECK-NEXT:    ^bb0(%{{.*}}: i256, %[[DST:.*]]: i256, %[[SRC:.*]]: i256):
    // CHECK-NEXT:      %[[E:.*]] = yul.mload %[[SRC]]
    // CHECK-NEXT:      %[[M:.*]] = yul.constant -18446744073709551616
    // CHECK-NEXT:      %[[C:.*]] = yul.and %[[E]], %[[M]]
    // CHECK-NEXT:      yul.mstore %[[DST]], %[[C]]
    // CHECK-NEXT:      %[[STRIDE:.*]] = yul.constant 32
    // CHECK-NEXT:      yul.add %[[DST]], %[[STRIDE]]
    // CHECK-LABEL: yul.func @packed_fnptr_memory : (i256) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.packed.inplace.array$_dyn_ext_func_ref$_$_ui256_$returnsui256_$_$_Memory_$(%arg0,
    sol.func @packed_fnptr_memory(%arg0: !sol.array<? x !sol.ext_func_ref<(ui256) -> ui256>, Memory>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.array<? x !sol.ext_func_ref<(ui256) -> ui256>, Memory>) -> !sol.string<Memory> {packed}
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // Calldata array elements are validated before being encoded. Unlike packed
    // mode, the head holds the tail offset and the tail starts with the length.
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.array$_dyn_ui8_$_CallData_$ : (!llvm.struct<(i256, i256)>, i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[ARR:.*]]: !llvm.struct<(i256, i256)>, %[[HEAD:.*]]: i256):
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
    // CHECK-LABEL: yul.func @u8_calldata : (!llvm.struct<(i256, i256)>) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_dyn_ui8_$_CallData_$(%arg0,
    sol.func @u8_calldata(%arg0: !sol.array<? x ui8, CallData>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.array<? x ui8, CallData>) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.array$_dyn_array$_dyn_ui8_$_CallData_$_$_CallData_$ : (!llvm.struct<(i256, i256)>, i256) -> i256
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
    // CHECK-LABEL: yul.func @nested_u8_calldata : (!llvm.struct<(i256, i256)>) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_dyn_array$_dyn_ui8_$_CallData_$_$_CallData_$(%arg0,
    sol.func @nested_u8_calldata(%arg0: !sol.array<? x !sol.array<? x ui8, CallData>, CallData>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.array<? x !sol.array<? x ui8, CallData>, CallData>) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // Each element offset read from calldata is bounds-checked against the
    // remaining calldata, less the element's static size minus one (63 for a
    // uint[][2]).
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.array$_dyn_array$_2_array$_dyn_ui256_$_CallData_$_$_CallData_$_$_CallData_$ : (!llvm.struct<(i256, i256)>, i256) -> i256
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
    // CHECK-LABEL: yul.func @nested_dyn_static_dyn_calldata : (!llvm.struct<(i256, i256)>) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_dyn_array$_2_array$_dyn_ui256_$_CallData_$_$_CallData_$_$_CallData_$(%arg0,
    sol.func @nested_dyn_static_dyn_calldata(%arg0: !sol.array<? x !sol.array<2 x !sol.array<? x ui256, CallData>, CallData>, CallData>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.array<? x !sol.array<2 x !sol.array<? x ui256, CallData>, CallData>, CallData>) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // Static inner arrays are encoded in place: the head is len * 128 for
    // uint[2][2][], with each uint[2] taking 64 bytes. The innermost uint[2]
    // is a row of words and is copied whole.
    // CHECK-LABEL: yul.func @__sol.abi_encode_array.memory.padded.tail.array$_2_array$_2_ui256_$_Memory_$_$_Memory_$ : (i256, i256) -> i256
    // CHECK:         %[[C2:.*]] = yul.constant 2
    // CHECK-NEXT:    %[[ISTRIDE:.*]] = yul.constant 64
    // CHECK-NEXT:    yul.mul %[[C2]], %[[ISTRIDE]]
    // CHECK:         yul.for
    // CHECK:         } body {
    // CHECK-NEXT:    ^bb0(%{{.*}}: i256, %[[DST:.*]]: i256, %[[SRC:.*]]: i256, %{{.*}}: i256):
    // CHECK-NEXT:      %[[ROW:.*]] = yul.mload %[[SRC]]
    // CHECK-NOT:       yul.for
    // CHECK:           yul.mcopy %[[DST]], %[[ROW]], %{{.*}}
    // CHECK-NEXT:      yul.add %[[DST]], %[[ISTRIDE]]
    // CHECK-LABEL: yul.func @__sol.abi_encode_array.memory.padded.tail.array$_dyn_array$_2_array$_2_ui256_$_Memory_$_$_Memory_$_$_Memory_$ : (i256, i256, i256) -> i256
    // CHECK-NEXT:  ^bb0(%{{.*}}: i256, %[[TAIL:.*]]: i256, %[[LEN:.*]]: i256):
    // CHECK:         yul.mstore %[[TAIL]], %[[LEN]]
    // CHECK:         %[[STRIDE:.*]] = yul.constant 128
    // CHECK-NEXT:    %[[HSZ:.*]] = yul.mul %[[LEN]], %[[STRIDE]]
    // CHECK:         %[[END:.*]] = yul.add %{{.*}}, %[[HSZ]]
    // CHECK:         yul.for {{.*}}, %[[END]] :
    // CHECK:           yul.func_call @__sol.abi_encode_array.memory.padded.tail.array$_2_array$_2_ui256_$_Memory_$_$_Memory_$(
    // CHECK:           yul.add %{{.*}}, %[[STRIDE]]
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.array$_dyn_array$_2_array$_2_ui256_$_Memory_$_$_Memory_$_$_Memory_$ : (i256, i256) -> i256
    // CHECK:         %[[OFFS:.*]] = yul.sub
    // CHECK:         yul.mstore %{{.*}}, %[[OFFS]]
    // CHECK:         %[[N:.*]] = yul.mload %arg0
    // CHECK-NEXT:    yul.func_call @__sol.abi_encode_array.memory.padded.tail.array$_dyn_array$_2_array$_2_ui256_$_Memory_$_$_Memory_$_$_Memory_$(%arg0, %{{.*}}, %[[N]])
    // CHECK-LABEL: yul.func @nested_static_memory : (i256) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_dyn_array$_2_array$_2_ui256_$_Memory_$_$_Memory_$_$_Memory_$(%arg0,
    sol.func @nested_static_memory(%arg0: !sol.array<? x !sol.array<2 x !sol.array<2 x ui256, Memory>, Memory>, Memory>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.array<? x !sol.array<2 x !sol.array<2 x ui256, Memory>, Memory>, Memory>) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // Packed array elements are still padded to 32 bytes each.
    // CHECK-LABEL: yul.func @__sol.abi_encode_array.memory.padded.inplace.array$_2_ui16_$_Memory_$ : (i256, i256) -> i256
    // CHECK:         yul.for
    // CHECK:           %[[V:.*]] = yul.mload
    // CHECK:           %[[M:.*]] = yul.constant 65535
    // CHECK:           %[[C:.*]] = yul.and %[[V]], %[[M]]
    // CHECK:           yul.mstore %{{.*}}, %[[C]]
    // CHECK-LABEL: yul.func @__sol.abi_encode_array.memory.packed.inplace.array$_3_array$_2_ui16_$_Memory_$_$_Memory_$ : (i256, i256) -> i256
    // CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
    // CHECK:         %[[C64:.*]] = yul.constant 64{{$}}
    // CHECK:         yul.mul %[[C3]], %[[C64]]
    // CHECK:         yul.for
    // CHECK:           yul.func_call @__sol.abi_encode_array.memory.padded.inplace.array$_2_ui16_$_Memory_$(
    // CHECK-LABEL: yul.func @packed_nested_u16_memory : (i256) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.packed.inplace.array$_3_array$_2_ui16_$_Memory_$_$_Memory_$(%arg0,
    sol.func @packed_nested_u16_memory(%arg0: !sol.array<3 x !sol.array<2 x ui16, Memory>, Memory>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.array<3 x !sol.array<2 x ui16, Memory>, Memory>) -> !sol.string<Memory> {packed}
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.packed.inplace.array$_3_array$_2_ui16_$_CallData_$_$_CallData_$ : (i256, i256) -> i256
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
    // CHECK-LABEL: yul.func @packed_nested_u16_calldata : (i256) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.packed.inplace.array$_3_array$_2_ui16_$_CallData_$_$_CallData_$(%arg0,
    sol.func @packed_nested_u16_calldata(%arg0: !sol.array<3 x !sol.array<2 x ui16, CallData>, CallData>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.array<3 x !sol.array<2 x ui16, CallData>, CallData>) -> !sol.string<Memory> {packed}
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // The innermost uint256[4] is contiguous in calldata and copied whole.
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.packed.inplace.array$_4_array$_5_array$_4_ui256_$_CallData_$_$_CallData_$_$_CallData_$ : (i256, i256) -> i256
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
    // CHECK-LABEL: yul.func @packed_nested_u256_calldata : (i256) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.packed.inplace.array$_4_array$_5_array$_4_ui256_$_CallData_$_$_CallData_$_$_CallData_$(%arg0,
    sol.func @packed_nested_u256_calldata(%arg0: !sol.array<4 x !sol.array<5 x !sol.array<4 x ui256, CallData>, CallData>, CallData>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.array<4 x !sol.array<5 x !sol.array<4 x ui256, CallData>, CallData>, CallData>) -> !sol.string<Memory> {packed}
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
