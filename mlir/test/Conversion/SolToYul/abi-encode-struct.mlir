// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// The uint[2] and uint[] members are rows of words and are copied whole.
// CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.struct$_$_ui256_$_struct$_$_ui256_$_ui256_$_string$_Memory_$_$_array$_2_ui256_$_Memory_$_$_array$_dyn_ui256_$_Memory_$_$_$_Memory_$_$_ui256_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:         %[[C96:.*]] = yul.constant 96{{$}}
// CHECK:         %[[ITAIL:.*]] = yul.add %[[HEAD:.*]], %[[C96]]
// CHECK:         %[[IOFF:.*]] = yul.sub %[[ITAIL]], %[[HEAD]]
// CHECK:         yul.mstore %{{.*}}, %[[IOFF]]
// CHECK:         %[[C192:.*]] = yul.constant 192{{$}}
// CHECK:         %[[TAIL:.*]] = yul.add %[[ITAIL]], %[[C192]]
// CHECK:         %[[ID:.*]] = yul.mload
// CHECK:         yul.mstore %[[ITAIL]], %[[ID]]
// CHECK:         %[[SOFF:.*]] = yul.sub %[[TAIL]], %[[ITAIL]]
// CHECK:         yul.mstore %{{.*}}, %[[SOFF]]
// CHECK:         %[[SLEN:.*]] = yul.mload
// CHECK:         yul.mcopy %{{.*}}, %{{.*}}, %[[SLEN]]
// CHECK:         yul.mstore %[[TAIL]], %[[SLEN]]
// CHECK:         %[[C2:.*]] = yul.constant 2{{$}}
// CHECK:         %[[FSZ:.*]] = yul.mul %[[C2]],
// CHECK-NEXT:    yul.mcopy %{{.*}}, %{{.*}}, %[[FSZ]]
// CHECK:         %[[DARR:.*]] = yul.mload
// CHECK:         %[[DLEN:.*]] = yul.mload %[[DARR]]
// CHECK:         yul.mstore %{{.*}}, %[[DLEN]]
// CHECK:         yul.mul %[[DLEN]],
// CHECK:         yul.mcopy
// CHECK-NOT:     yul.for
// CHECK-LABEL: yul.func @mem_nested : (i256) -> i256
// CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.struct$_$_ui256_$_struct$_$_ui256_$_ui256_$_string$_Memory_$_$_array$_2_ui256_$_Memory_$_$_array$_dyn_ui256_$_Memory_$_$_$_Memory_$_$_ui256_$_$_Memory_$(%arg0,
module {
  sol.contract @C {
    sol.func @mem_nested(%arg0: !sol.struct<(ui256, !sol.struct<(ui256, ui256, !sol.string<Memory>, !sol.array<2 x ui256, Memory>, !sol.array<? x ui256, Memory>), Memory>, ui256), Memory>) -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.encode %arg0 : (!sol.struct<(ui256, !sol.struct<(ui256, ui256, !sol.string<Memory>, !sol.array<2 x ui256, Memory>, !sol.array<? x ui256, Memory>), Memory>, ui256), Memory>) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// Calldata members are bounds-checked, then bulk-copied.
// CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.struct$_$_ui256_$_struct$_$_ui256_$_ui256_$_string$_CallData_$_$_array$_2_ui256_$_CallData_$_$_array$_dyn_ui256_$_CallData_$_$_$_CallData_$_$_ui256_$_$_CallData_$ : (i256, i256) -> i256
// CHECK:         %[[C96:.*]] = yul.constant 96{{$}}
// CHECK:         yul.add %{{.*}}, %[[C96]]
// CHECK:         yul.cmp sge
// CHECK:         %[[C192:.*]] = yul.constant 192{{$}}
// CHECK:         yul.add %{{.*}}, %[[C192]]
// CHECK:         %[[ID:.*]] = yul.calldataload
// CHECK:         yul.mstore %{{.*}}, %[[ID]]
// CHECK:         %[[CODE:.*]] = yul.calldataload
// CHECK:         yul.mstore %{{.*}}, %[[CODE]]
// CHECK:         %[[SREL:.*]] = yul.calldataload
// CHECK:         %[[BAD:.*]] = yul.cmp sge, %[[SREL]], %{{.*}}
// CHECK:         yul.if %[[BAD]] {
// CHECK:         %[[SPTR:.*]] = yul.add %{{.*}}, %[[SREL]]
// CHECK:         %[[SLEN:.*]] = yul.calldataload %[[SPTR]]
// CHECK:         yul.calldatacopy %{{.*}}, %{{.*}}, %{{.*}}
// CHECK:         yul.calldatacopy
// CHECK:         %[[DREL:.*]] = yul.calldataload
// CHECK:         yul.cmp sge, %[[DREL]], %{{.*}}
// CHECK:         yul.calldatacopy
// CHECK-LABEL: yul.func @cd_nested : (i256) -> i256
// CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.struct$_$_ui256_$_struct$_$_ui256_$_ui256_$_string$_CallData_$_$_array$_2_ui256_$_CallData_$_$_array$_dyn_ui256_$_CallData_$_$_$_CallData_$_$_ui256_$_$_CallData_$(%arg0,
module {
  sol.contract @C {
    sol.func @cd_nested(%arg0: !sol.struct<(ui256, !sol.struct<(ui256, ui256, !sol.string<CallData>, !sol.array<2 x ui256, CallData>, !sol.array<? x ui256, CallData>), CallData>, ui256), CallData>) -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.encode %arg0 : (!sol.struct<(ui256, !sol.struct<(ui256, ui256, !sol.string<CallData>, !sol.array<2 x ui256, CallData>, !sol.array<? x ui256, CallData>), CallData>, ui256), CallData>) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// S[2] in calldata is static: copied word by word, 64 bytes per element.
// CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.array$_2_struct$_$_ui256_$_ui256_$_$_CallData_$_$_CallData_$ : (i256, i256) -> i256
// CHECK:         %[[C128:.*]] = yul.constant 128{{$}}
// CHECK:         yul.add %{{.*}}, %[[C128]]
// CHECK:         yul.for
// CHECK:           %[[A:.*]] = yul.calldataload
// CHECK:           yul.mstore %{{.*}}, %[[A]]
// CHECK:           %[[B:.*]] = yul.calldataload
// CHECK:           yul.mstore %{{.*}}, %[[B]]
// CHECK-LABEL: yul.func @enc_struct : (i256) -> i256
// CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_2_struct$_$_ui256_$_ui256_$_$_CallData_$_$_CallData_$(%arg0,
module {
  sol.contract @C {
    sol.func @enc_struct(%arg0: !sol.array<2 x !sol.struct<(ui256, ui256), CallData>, CallData>) -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.encode %arg0 : (!sol.array<2 x !sol.struct<(ui256, ui256), CallData>, CallData>) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#View = #sol<StateMutability View>

// CHECK-LABEL: yul.func @__sol.copy_string_bytes.storage.memory
// CHECK-LABEL: yul.func @__sol.storage_string_length

// The dynamic inner Big is behind an offset and starts at slot 7; its
// string length is decoded from the slot word and its bytes copied with the
// helpers; extra sits at slot 6 + 7.
// CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.struct$_$_ui256_$_struct$_$_ui256_$_ui256_$_string$_Storage_$_$_array$_2_ui256_$_Storage_$_$_array$_dyn_ui256_$_Storage_$_$_$_Storage_$_$_ui256_$_$_Storage_$ : (i256, i256) -> i256
// CHECK-NEXT:  ^bb0(%[[SLOT:.*]]: i256, %{{.*}}: i256):
// CHECK:         %[[C96:.*]] = yul.constant 96{{$}}
// CHECK:         %[[ITAIL:.*]] = yul.add %[[HEAD:.*]], %[[C96]]
// CHECK:         %[[ONE:.*]] = yul.constant 1{{$}}
// CHECK:         %[[INNER:.*]] = yul.add %[[SLOT]], %[[ONE]]
// CHECK:         %[[IOFF:.*]] = yul.sub %[[ITAIL]], %[[HEAD]]
// CHECK:         yul.mstore %{{.*}}, %[[IOFF]]
// CHECK:         %[[C192:.*]] = yul.constant 192{{$}}
// CHECK:         yul.add %[[ITAIL]], %[[C192]]
// CHECK:         %[[C2:.*]] = yul.constant 2{{$}}
// CHECK:         %[[SS:.*]] = yul.add %[[INNER]], %[[C2]]
// CHECK:         %[[SW:.*]] = yul.sload %[[SS]]
// CHECK:         %[[SLEN:.*]] = yul.func_call @__sol.storage_string_length(%[[SW]])
// CHECK:         yul.func_call @__sol.copy_string_bytes.storage.memory(%[[SS]], %[[SW]], %[[SLEN]], %{{.*}})
// CHECK:         yul.mstore %{{.*}}, %[[SLEN]]
// CHECK:         yul.for
// CHECK:           yul.sload
// CHECK:         %[[C5:.*]] = yul.constant 5{{$}}
// CHECK:         yul.add %[[INNER]], %[[C5]]
// CHECK:         %[[DLEN:.*]] = yul.sload
// CHECK:         yul.keccak256
// CHECK:         yul.for
// CHECK:           yul.cmp ult, %{{.*}}, %[[DLEN]]
// CHECK:           yul.sload
// CHECK:         %[[C7:.*]] = yul.constant 7{{$}}
// CHECK:         %[[ES:.*]] = yul.add %[[SLOT]], %[[C7]]
// CHECK:         %[[E:.*]] = yul.sload %[[ES]]
// CHECK:         yul.mstore %{{.*}}, %[[E]]
// CHECK-LABEL: yul.func @storage_big_nested : () -> i256
// CHECK:         %[[S:.*]] = yul.constant 6{{$}}
// CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.struct$_$_ui256_$_struct$_$_ui256_$_ui256_$_string$_Storage_$_$_array$_2_ui256_$_Storage_$_$_array$_dyn_ui256_$_Storage_$_$_$_Storage_$_$_ui256_$_$_Storage_$(%[[S]],
module {
  sol.contract @C {
    sol.state_var @storageBigNested slot 6 offset 0 : !sol.struct<(ui256, !sol.struct<(ui256, ui256, !sol.string<Storage>, !sol.array<2 x ui256, Storage>, !sol.array<? x ui256, Storage>), Storage>, ui256), Storage>
    sol.func @storage_big_nested() -> !sol.string<Memory> attributes {state_mutability = #View} {
      %0 = sol.addr_of @storageBigNested : !sol.struct<(ui256, !sol.struct<(ui256, ui256, !sol.string<Storage>, !sol.array<2 x ui256, Storage>, !sol.array<? x ui256, Storage>), Storage>, ui256), Storage>
      %1 = sol.encode %0 : (!sol.struct<(ui256, !sol.struct<(ui256, ui256, !sol.string<Storage>, !sol.array<2 x ui256, Storage>, !sol.array<? x ui256, Storage>), Storage>, ui256), Storage>) -> !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#View = #sol<StateMutability View>

// The static struct is encoded in place: a and d whole, b and c shifted
// out of slot 22 and masked.
// CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.struct$_$_ui128_$_ui64_$_i1_$_ui256_$_$_Storage_$ : (i256, i256) -> i256
// CHECK-NEXT:  ^bb0(%[[SLOT:.*]]: i256, %{{.*}}: i256):
// CHECK:         %[[C128:.*]] = yul.constant 128{{$}}
// CHECK:         yul.add %{{.*}}, %[[C128]]
// CHECK:         %[[W:.*]] = yul.sload
// CHECK:         %[[MA:.*]] = yul.constant 340282366920938463463374607431768211455
// CHECK:         yul.and %[[W]], %[[MA]]
// CHECK:         %[[SB:.*]] = yul.constant 128{{$}}
// CHECK:         %[[B:.*]] = yul.arith_shr %[[W]], %[[SB]]
// CHECK:         %[[MB:.*]] = yul.constant 18446744073709551615
// CHECK:         yul.and %[[B]], %[[MB]]
// CHECK:         %[[SC:.*]] = yul.constant 192{{$}}
// CHECK:         %[[C:.*]] = yul.arith_shr %[[W]], %[[SC]]
// CHECK:         %[[MC:.*]] = yul.constant 255{{$}}
// CHECK:         %[[CB:.*]] = yul.and %[[C]], %[[MC]]
// CHECK:         yul.cmp ne, %[[CB]], %{{.*}}
// CHECK:         %[[ONE:.*]] = yul.constant 1{{$}}
// CHECK:         %[[DS:.*]] = yul.add %[[SLOT]], %[[ONE]]
// CHECK:         %[[D:.*]] = yul.sload %[[DS]]
// CHECK:         yul.mstore %{{.*}}, %[[D]]
// CHECK-LABEL: yul.func @storage_packed : () -> i256
// CHECK:         %[[S:.*]] = yul.constant 22{{$}}
// CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.struct$_$_ui128_$_ui64_$_i1_$_ui256_$_$_Storage_$(%[[S]],
module {
  sol.contract @C {
    sol.state_var @storagePacked slot 22 offset 0 : !sol.struct<(ui128, ui64, i1, ui256), Storage>
    sol.func @storage_packed() -> !sol.string<Memory> attributes {state_mutability = #View} {
      %0 = sol.addr_of @storagePacked : !sol.struct<(ui128, ui64, i1, ui256), Storage>
      %1 = sol.encode %0 : (!sol.struct<(ui128, ui64, i1, ui256), Storage>) -> !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract}
}
