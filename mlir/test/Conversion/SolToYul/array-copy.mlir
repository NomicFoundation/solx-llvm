// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

sol.contract @C {
  // The outer copy helper walks the rows and hands each to the inner one.
  // CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_3_ui256_$_Memory_$.array$_3_ui256_$_Storage_$ : (i256, i256) -> ()
  // CHECK:         yul.for
  // CHECK:           %[[S:.*]] = yul.add %arg1, %{{.*}}
  // CHECK:           %[[V:.*]] = yul.mload
  // CHECK:           yul.sstore %[[S]], %[[V]]
  // CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_2_array$_3_ui256_$_Memory_$_$_Memory_$.array$_2_array$_3_ui256_$_Storage_$_$_Storage_$ : (i256, i256) -> ()
  // CHECK:         yul.for
  // CHECK:           %[[ROW:.*]] = yul.mload
  // CHECK:           %[[C3:.*]] = yul.constant 3{{$}}
  // CHECK:           %[[OFF:.*]] = yul.mul %{{.*}}, %[[C3]]
  // CHECK:           %[[ISLOT:.*]] = yul.add %arg1, %[[OFF]]
  // CHECK:           yul.func_call @__sol.copy_array.memory.storage.array$_3_ui256_$_Memory_$.array$_3_ui256_$_Storage_$(%[[ROW]], %[[ISLOT]])
  // CHECK-LABEL: yul.func @m2s_stat2d : (i256, i256) -> ()
  // CHECK:         yul.func_call @__sol.copy_array.memory.storage.array$_2_array$_3_ui256_$_Memory_$_$_Memory_$.array$_2_array$_3_ui256_$_Storage_$_$_Storage_$(%arg0, %arg1)
  sol.func @m2s_stat2d(%m: !sol.array<2 x !sol.array<3 x ui256, Memory>, Memory>, %s: !sol.array<2 x !sol.array<3 x ui256, Storage>, Storage>) {
    sol.copy %m, %s : !sol.array<2 x !sol.array<3 x ui256, Memory>, Memory>, !sol.array<2 x !sol.array<3 x ui256, Storage>, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // Storing a shorter array clears the old tail slots. The inner copy stores
  // its length and the words, the outer one clears each dropped row through
  // the clear helper and copies each kept row through the inner one.
  // CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_dyn_ui256_$_Memory_$.array$_dyn_ui256_$_Storage_$ : (i256, i256) -> ()
  // CHECK:         %[[ILEN:.*]] = yul.mload %arg0
  // CHECK:         yul.sload %arg1
  // CHECK:         yul.sstore %arg1, %[[ILEN]]
  // CHECK:         yul.for
  // CHECK:           yul.sstore %{{.*}}, %{{.*}}
  // CHECK:         yul.for
  // CHECK:           yul.cmp ult, %{{.*}}, %[[ILEN]]
  // CHECK:           %[[V:.*]] = yul.mload
  // CHECK:           yul.sstore %{{.*}}, %[[V]]
  // CHECK-LABEL: yul.func @__sol.clear_storage_array.array$_dyn_ui256_$_Storage_$ : (i256) -> ()
  // CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_dyn_array$_dyn_ui256_$_Memory_$_$_Memory_$.array$_dyn_array$_dyn_ui256_$_Storage_$_$_Storage_$ : (i256, i256) -> ()
  // CHECK:         %[[LEN:.*]] = yul.mload %arg0
  // CHECK:         yul.sload %arg1
  // CHECK:         yul.sstore %arg1, %[[LEN]]
  // CHECK:         yul.for
  // CHECK:           yul.func_call @__sol.clear_storage_array.array$_dyn_ui256_$_Storage_$
  // CHECK:         yul.for
  // CHECK:           yul.cmp ult, %{{.*}}, %[[LEN]]
  // CHECK:           %[[IPTR:.*]] = yul.mload
  // CHECK:           yul.func_call @__sol.copy_array.memory.storage.array$_dyn_ui256_$_Memory_$.array$_dyn_ui256_$_Storage_$(%[[IPTR]], %{{.*}})
  // CHECK-LABEL: yul.func @m2s_dyn2d : (i256, i256) -> ()
  // CHECK:         yul.func_call @__sol.copy_array.memory.storage.array$_dyn_array$_dyn_ui256_$_Memory_$_$_Memory_$.array$_dyn_array$_dyn_ui256_$_Storage_$_$_Storage_$(%arg0, %arg1)
  sol.func @m2s_dyn2d(%m: !sol.array<? x !sol.array<? x ui256, Memory>, Memory>, %s: !sol.array<? x !sol.array<? x ui256, Storage>, Storage>) {
    sol.copy %m, %s : !sol.array<? x !sol.array<? x ui256, Memory>, Memory>, !sol.array<? x !sol.array<? x ui256, Storage>, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // Storage-to-storage copies are skipped on self-assignment. The 2**64 element
  // count stays a 256-bit constant, not truncated to 64 bits.
  // CHECK-LABEL: yul.func @__sol.copy_array.storage.storage.array$_18446744073709551616_ui256_$_Storage_$.array$_18446744073709551616_ui256_$_Storage_$ : (i256, i256) -> ()
  // CHECK:         %[[NE:.*]] = yul.cmp ne, %arg0, %arg1
  // CHECK:         yul.if %[[NE]] {
  // CHECK:           %[[N:.*]] = yul.constant 18446744073709551616
  // CHECK:           yul.for
  // CHECK:             yul.cmp ult, %{{.*}}, %[[N]]
  // CHECK:             %[[SRC:.*]] = yul.add %arg0, %{{.*}}
  // CHECK:             %[[DST:.*]] = yul.add %arg1, %{{.*}}
  // CHECK:             %[[V:.*]] = yul.sload %[[SRC]]
  // CHECK:             yul.sstore %[[DST]], %[[V]]
  // CHECK-LABEL: yul.func @s2s_stat : (i256, i256) -> ()
  // CHECK:         yul.func_call @__sol.copy_array.storage.storage.array$_18446744073709551616_ui256_$_Storage_$.array$_18446744073709551616_ui256_$_Storage_$(%arg0, %arg1)
  sol.func @s2s_stat(%a: !sol.array<18446744073709551616 x ui256, Storage>, %b: !sol.array<18446744073709551616 x ui256, Storage>) {
    sol.copy %a, %b : !sol.array<18446744073709551616 x ui256, Storage>, !sol.array<18446744073709551616 x ui256, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // CHECK-LABEL: yul.func @__sol.copy_array.storage.storage.array$_dyn_ui256_$_Storage_$.array$_dyn_ui256_$_Storage_$ : (i256, i256) -> ()
  // CHECK:         %[[NE:.*]] = yul.cmp ne, %arg0, %arg1
  // CHECK:         yul.if %[[NE]] {
  // CHECK:           %[[LEN:.*]] = yul.sload %arg0
  // CHECK:           %[[SDATA:.*]] = yul.keccak256
  // CHECK:           %[[OLDLEN:.*]] = yul.sload %arg1
  // CHECK:           yul.sstore %arg1, %[[LEN]]
  // CHECK:           %[[SHRINK:.*]] = yul.cmp ult, %[[LEN]], %[[OLDLEN]]
  // CHECK:           yul.if %[[SHRINK]] {
  // CHECK:             yul.for
  // CHECK:               yul.sstore
  // CHECK:           %[[DDATA:.*]] = yul.keccak256
  // CHECK:           yul.for
  // CHECK:             yul.cmp ult, %{{.*}}, %[[LEN]]
  // CHECK:             %[[SRC:.*]] = yul.add %[[SDATA]], %{{.*}}
  // CHECK:             %[[DST:.*]] = yul.add %[[DDATA]], %{{.*}}
  // CHECK:             %[[V:.*]] = yul.sload %[[SRC]]
  // CHECK:             yul.sstore %[[DST]], %[[V]]
  // CHECK-LABEL: yul.func @s2s_dyn : (i256, i256) -> ()
  // CHECK:         yul.func_call @__sol.copy_array.storage.storage.array$_dyn_ui256_$_Storage_$.array$_dyn_ui256_$_Storage_$(%arg0, %arg1)
  sol.func @s2s_dyn(%a: !sol.array<? x ui256, Storage>, %b: !sol.array<? x ui256, Storage>) {
    sol.copy %a, %b : !sol.array<? x ui256, Storage>, !sol.array<? x ui256, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // Each clone helper allocates its array and returns it, the outer one
  // storing the inner clones as its elements.
  // CHECK-LABEL: yul.func @__sol.clone_array.storage.memory.array$_3_ui256_$_Storage_$ : (i256) -> i256
  // CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
  // CHECK:         %[[P:.*]] = yul.mload %c64
  // CHECK:         yul.mstore %c64{{.*}}, %{{.*}}
  // CHECK:         yul.for
  // CHECK:           yul.cmp ult, %{{.*}}, %[[C3]]
  // CHECK:           %[[V:.*]] = yul.sload
  // CHECK:           yul.mstore %{{.*}}, %[[V]]
  // CHECK:         yul.func_return %[[P]] : i256
  // CHECK-LABEL: yul.func @__sol.clone_array.storage.memory.array$_2_array$_3_ui256_$_Storage_$_$_Storage_$ : (i256) -> i256
  // CHECK:         %[[C2:.*]] = yul.constant 2{{$}}
  // CHECK:         %[[P:.*]] = yul.mload %c64
  // CHECK:         yul.for
  // CHECK:           yul.cmp ult, %{{.*}}, %[[C2]]
  // CHECK:           %[[C3:.*]] = yul.constant 3{{$}}
  // CHECK:           %[[OFF:.*]] = yul.mul %{{.*}}, %[[C3]]
  // CHECK:           %[[ISLOT:.*]] = yul.add %arg0, %[[OFF]]
  // CHECK:           %[[IP:.*]] = yul.func_call @__sol.clone_array.storage.memory.array$_3_ui256_$_Storage_$(%[[ISLOT]])
  // CHECK:           yul.mstore %{{.*}}, %[[IP]]
  // CHECK:         yul.func_return %[[P]] : i256
  // CHECK-LABEL: yul.func @s2m_stat2d : (i256) -> i256
  // CHECK:         %[[R:.*]] = yul.func_call @__sol.clone_array.storage.memory.array$_2_array$_3_ui256_$_Storage_$_$_Storage_$(%arg0)
  // CHECK:         yul.func_return %[[R]] : i256
  sol.func @s2m_stat2d(%s: !sol.array<2 x !sol.array<3 x ui256, Storage>, Storage>) -> !sol.array<2 x !sol.array<3 x ui256, Memory>, Memory> {
    %0 = sol.data_loc_cast %s : !sol.array<2 x !sol.array<3 x ui256, Storage>, Storage>, !sol.array<2 x !sol.array<3 x ui256, Memory>, Memory>
    sol.return %0 : !sol.array<2 x !sol.array<3 x ui256, Memory>, Memory>
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // CHECK-LABEL: yul.func @__sol.clone_array.storage.memory.array$_dyn_ui256_$_Storage_$ : (i256) -> i256
  // CHECK:         %[[ILEN:.*]] = yul.sload %arg0
  // CHECK:         yul.mstore %{{.*}}, %arg0
  // CHECK:         yul.keccak256
  // CHECK:         %[[IP:.*]] = yul.func_call @__sol.alloc
  // CHECK:         yul.mstore %[[IP]], %[[ILEN]]
  // CHECK:         yul.for
  // CHECK:           yul.cmp ult, %{{.*}}, %[[ILEN]]
  // CHECK:           %[[V:.*]] = yul.sload
  // CHECK:           yul.mstore %{{.*}}, %[[V]]
  // CHECK:         yul.func_return %[[IP]] : i256
  // CHECK-LABEL: yul.func @__sol.clone_array.storage.memory.array$_dyn_array$_dyn_ui256_$_Storage_$_$_Storage_$ : (i256) -> i256
  // CHECK:         %[[LEN:.*]] = yul.sload %arg0
  // CHECK:         yul.mstore %{{.*}}, %arg0
  // CHECK:         %[[DATA:.*]] = yul.keccak256
  // CHECK:         %[[P:.*]] = yul.func_call @__sol.alloc
  // CHECK:         yul.mstore %[[P]], %[[LEN]]
  // CHECK:         yul.for
  // CHECK:           yul.cmp ult, %{{.*}}, %[[LEN]]
  // CHECK:           %[[ISLOT:.*]] = yul.add %[[DATA]], %{{.*}}
  // CHECK:           %[[IP:.*]] = yul.func_call @__sol.clone_array.storage.memory.array$_dyn_ui256_$_Storage_$(%[[ISLOT]])
  // CHECK:           yul.mstore %{{.*}}, %[[IP]]
  // CHECK:         yul.func_return %[[P]] : i256
  // CHECK-LABEL: yul.func @s2m_dyn2d : (i256) -> i256
  // CHECK:         %[[R:.*]] = yul.func_call @__sol.clone_array.storage.memory.array$_dyn_array$_dyn_ui256_$_Storage_$_$_Storage_$(%arg0)
  // CHECK:         yul.func_return %[[R]] : i256
  sol.func @s2m_dyn2d(%s: !sol.array<? x !sol.array<? x ui256, Storage>, Storage>) -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory> {
    %0 = sol.data_loc_cast %s : !sol.array<? x !sol.array<? x ui256, Storage>, Storage>, !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
    sol.return %0 : !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // The word rows are bulk-copied with one calldatacopy each.
  // CHECK-LABEL: yul.func @__sol.clone_array.calldata.memory.array$_2_array$_3_ui256_$_CallData_$_$_CallData_$ : (i256) -> i256
  // CHECK:         %[[C2:.*]] = yul.constant 2{{$}}
  // CHECK:         %[[P:.*]] = yul.mload %c64
  // CHECK:         yul.for
  // CHECK:           yul.cmp ult, %{{.*}}, %[[C2]]
  // CHECK:           %[[ISTRIDE:.*]] = yul.constant 96{{$}}
  // CHECK:           %[[IOFF:.*]] = yul.mul %{{.*}}, %[[ISTRIDE]]
  // CHECK:           %[[ISRC:.*]] = yul.add %arg0, %[[IOFF]]
  // CHECK:           %[[IP:.*]] = yul.mload
  // CHECK-NOT:       yul.for
  // CHECK:           yul.calldatacopy %[[IP]], %[[ISRC]], %{{.*}}
  // CHECK:           yul.mstore %{{.*}}, %[[IP]]
  // CHECK:         yul.func_return %[[P]] : i256
  // CHECK-LABEL: yul.func @cd2m_stat2d : (i256) -> i256
  // CHECK:         %[[R:.*]] = yul.func_call @__sol.clone_array.calldata.memory.array$_2_array$_3_ui256_$_CallData_$_$_CallData_$(%arg0)
  // CHECK:         yul.func_return %[[R]] : i256
  sol.func @cd2m_stat2d(%c: !sol.array<2 x !sol.array<3 x ui256, CallData>, CallData>) -> !sol.array<2 x !sol.array<3 x ui256, Memory>, Memory> {
    %0 = sol.data_loc_cast %c : !sol.array<2 x !sol.array<3 x ui256, CallData>, CallData>, !sol.array<2 x !sol.array<3 x ui256, Memory>, Memory>
    sol.return %0 : !sol.array<2 x !sol.array<3 x ui256, Memory>, Memory>
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // Each inner calldata array is located by its offset, validated, then
  // bulk-copied into a fresh memory array.
  // CHECK-LABEL: yul.func @__sol.clone_array.calldata.memory.array$_dyn_array$_dyn_ui256_$_CallData_$_$_CallData_$ : (!llvm.struct<(i256, i256)>) -> i256
  // CHECK:         %[[LEN:.*]] = llvm.extractvalue %arg0[1]
  // CHECK:         %[[BASE:.*]] = llvm.extractvalue %arg0[0]
  // CHECK:         %[[P:.*]] = yul.func_call @__sol.alloc
  // CHECK:         yul.mstore %[[P]], %[[LEN]]
  // CHECK:         yul.for
  // CHECK:           %[[REL:.*]] = yul.calldataload
  // CHECK:           yul.cmp sge, %[[REL]], %{{.*}}
  // CHECK:           %[[INNER:.*]] = yul.add %[[BASE]], %[[REL]]
  // CHECK:           yul.calldataload %[[INNER]]
  // CHECK:           %[[IP:.*]] = yul.func_call @__sol.alloc
  // CHECK:           yul.mstore %[[IP]], %{{.*}}
  // CHECK-NOT:       yul.for
  // CHECK:           yul.calldatacopy
  // CHECK:           yul.mstore %{{.*}}, %[[IP]]
  // CHECK:         yul.func_return %[[P]] : i256
  // CHECK-LABEL: yul.func @cd2m_dyn2d : (!llvm.struct<(i256, i256)>) -> i256
  // CHECK:         %[[R:.*]] = yul.func_call @__sol.clone_array.calldata.memory.array$_dyn_array$_dyn_ui256_$_CallData_$_$_CallData_$(%arg0)
  // CHECK:         yul.func_return %[[R]] : i256
  sol.func @cd2m_dyn2d(%c: !sol.array<? x !sol.array<? x ui256, CallData>, CallData>) -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory> {
    %0 = sol.data_loc_cast %c : !sol.array<? x !sol.array<? x ui256, CallData>, CallData>, !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
    sol.return %0 : !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // CHECK-LABEL: yul.func @cd2m_str : (!llvm.struct<(i256, i256)>) -> i256
  // CHECK:         %[[LEN:.*]] = llvm.extractvalue %arg0[1]
  // CHECK:         %[[P:.*]] = yul.func_call @__sol.alloc
  // CHECK:         yul.mstore %[[P]], %[[LEN]]
  // CHECK:         %[[SRC:.*]] = llvm.extractvalue %arg0[0]
  // CHECK:         yul.calldatacopy %{{.*}}, %[[SRC]], %[[LEN]]
  // CHECK:         yul.func_return %[[P]] : i256
  sol.func @cd2m_str(%c: !sol.string<CallData>) -> !sol.string<Memory> {
    %0 = sol.data_loc_cast %c : !sol.string<CallData>, !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // A dirty calldata element reverts; the clean value fills its own slot, so it
  // is stored unmasked.
  // CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.array$_2_address_$_CallData_$.array$_2_address_$_Storage_$ : (i256, i256) -> ()
  // CHECK:         yul.for
  // CHECK:           %[[SRC:.*]] = yul.add %arg0, %{{.*}}
  // CHECK:           %[[DST:.*]] = yul.add %arg1, %{{.*}}
  // CHECK:           %[[V:.*]] = yul.calldataload %[[SRC]]
  // CHECK:           %[[M:.*]] = yul.constant 1461501637330902918203684832716283019655932542975
  // CHECK:           %[[C:.*]] = yul.and %[[V]], %[[M]]
  // CHECK:           %[[BAD:.*]] = yul.cmp ne, %[[V]], %[[C]]
  // CHECK:           yul.if %[[BAD]] {
  // CHECK:             yul.revert
  // CHECK:           yul.sstore %[[DST]], %[[C]]
  // CHECK-LABEL: yul.func @cd2s_addr : (i256, i256) -> ()
  // CHECK:         yul.func_call @__sol.copy_array.calldata.storage.array$_2_address_$_CallData_$.array$_2_address_$_Storage_$(%arg0, %arg1)
  sol.func @cd2s_addr(%c: !sol.array<2 x !sol.address, CallData>, %s: !sol.array<2 x !sol.address, Storage>) {
    sol.copy %c, %s : !sol.array<2 x !sol.address, CallData>, !sol.array<2 x !sol.address, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}
