// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

sol.contract @C {
  // The 31 -> 32 byte push moves the data out of the length slot.
  // CHECK-LABEL: yul.func @p : (i256) -> ()
  // CHECK:         yul.constant 221
  // CHECK:         yul.constant 65
  // CHECK:         %[[C31:.*]] = yul.constant 31
  // CHECK:         %[[ISLONG:.*]] = yul.cmp ugt, %{{.*}}, %[[C31]]
  // CHECK:         yul.if %[[ISLONG]] {
  // CHECK:           yul.keccak256
  // CHECK:           yul.sstore
  // CHECK:         } else {
  // CHECK:           %[[TOLONG:.*]] = yul.cmp eq
  // CHECK:           yul.if %[[TOLONG]] {
  // CHECK:             %[[DATA:.*]] = yul.keccak256
  // CHECK:             yul.sstore %[[DATA]]
  // CHECK:             %[[C65:.*]] = yul.constant 65
  // CHECK:             yul.sstore %arg0, %[[C65]]
  sol.func @p(%s: !sol.string<Storage>) {
    %c = sol.constant 221 : ui8
    %b = sol.bytes_cast %c : ui8 to !sol.fixedbytes<1>
    sol.push_string %s, %b : <Storage>, !sol.fixedbytes<1>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // push() yields the new element's (slot, offset); the store goes through it.
  // CHECK-LABEL: yul.func @p2 : (i256) -> ()
  // CHECK:         %[[B:.*]] = yul.constant 101
  // CHECK:         yul.constant 65
  // CHECK:         %[[REF:.*]] = yul.if %{{.*}} -> !llvm.struct<(i256, i256)> {
  // CHECK:         yul.arith_shl %[[B]], %{{.*}}
  // CHECK:         %[[SLOT:.*]] = llvm.extractvalue %[[REF]][0]
  // CHECK:         yul.sstore %[[SLOT]], %{{.*}}
  sol.func @p2(%s: !sol.string<Storage>) {
    %c = sol.constant 101 : ui8
    %0 = sol.push %s : !sol.string<Storage> -> !sol.ptr<!sol.byte, Storage>
    %1 = sol.bytes_cast %c : ui8 to !sol.byte
    sol.store %1, %0 : !sol.byte, !sol.ptr<!sol.byte, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // Popping the 32nd byte converts a long string back to short form.
  // CHECK-LABEL: yul.func @pop : (i256) -> ()
  // CHECK:         yul.constant 49
  // CHECK:         %[[C32:.*]] = yul.constant 32
  // CHECK:         %[[TOSHORT:.*]] = yul.cmp eq, %{{.*}}, %[[C32]]
  // CHECK:         yul.if %[[TOSHORT]] {
  // CHECK:           yul.constant 62
  // CHECK:         } else {
  // CHECK:           %[[C2:.*]] = yul.constant 2
  // CHECK:           yul.sub %{{.*}}, %[[C2]]
  sol.func @pop(%s: !sol.string<Storage>) {
    sol.pop %s : !sol.string<Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // Short strings keep 2 * length in the slot's low byte, long ones 2 * length + 1.
  // CHECK-LABEL: yul.func @len : (i256) -> i256
  // CHECK:         %[[W:.*]] = yul.sload %arg0
  // CHECK:         %[[HALF:.*]] = yul.arith_shr %[[W]], %{{.*}}
  // CHECK:         %[[LONG:.*]] = yul.and %[[W]], %{{.*}}
  // CHECK:         %[[SHORT:.*]] = yul.cmp eq, %[[LONG]], %{{.*}}
  // CHECK:         %[[C127:.*]] = yul.constant 127
  // CHECK:         %[[SLEN:.*]] = yul.and %[[HALF]], %[[C127]]
  // CHECK:         %[[LEN:.*]] = yul.arith_select %[[SHORT]], %[[SLEN]], %[[HALF]]
  // CHECK:         yul.constant 34
  // CHECK:         yul.func_return %[[LEN]] : i256
  sol.func @len(%s: !sol.string<Storage>) -> ui256 {
    %0 = sol.length %s : !sol.string<Storage>
    sol.return %0 : ui256
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // Storage slots of the old contents past the new length are zeroed.
  // CHECK-LABEL: yul.func @__sol.clear_string_tail : (i256, i256, i256) -> ()
  // CHECK:         yul.keccak256
  // CHECK:         yul.for
  // CHECK:         } body {
  // CHECK:           %[[Z:.*]] = yul.constant 0
  // CHECK:           yul.sstore %{{.*}}, %[[Z]]

  // Source bytes past the length are masked off before they reach storage,
  // both in the long form's last word and in the short form.
  // CHECK-LABEL: yul.func @__sol.copy.memory.storage.string : (i256, i256) -> ()
  // CHECK:         yul.func_call @__sol.clear_string_tail(
  // CHECK:         yul.for
  // CHECK:           %[[W:.*]] = yul.mload
  // CHECK:           yul.sstore %{{.*}}, %[[W]]
  // CHECK:         %[[W:.*]] = yul.mload
  // CHECK:         %[[BITS:.*]] = yul.sub
  // CHECK:         %[[ONES:.*]] = yul.constant -1
  // CHECK:         %[[M:.*]] = yul.arith_shl %[[ONES]], %[[BITS]]
  // CHECK:         %[[V:.*]] = yul.and %[[W]], %[[M]]
  // CHECK:         yul.sstore %{{.*}}, %[[V]]
  // CHECK:         %[[W:.*]] = yul.mload
  // CHECK:         %[[BITS:.*]] = yul.sub
  // CHECK:         %[[ONES:.*]] = yul.constant -1
  // CHECK:         %[[M:.*]] = yul.arith_shl %[[ONES]], %[[BITS]]
  // CHECK:         %[[V:.*]] = yul.and %[[W]], %[[M]]
  // CHECK:         %[[LEN:.*]] = yul.mul
  // CHECK:         %[[P:.*]] = yul.or %[[V]], %[[LEN]]
  // CHECK:         yul.sstore %arg1, %[[P]]

  // CHECK-LABEL: yul.func @m : (i256, i256) -> ()
  // CHECK:         yul.func_call @__sol.copy.memory.storage.string(%arg0, %arg1)
  sol.func @m(%m: !sol.string<Memory>, %s: !sol.string<Storage>) {
    sol.copy %m, %s : !sol.string<Memory>, !sol.string<Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // CHECK-LABEL: yul.func @__sol.copy.storage.storage.string : (i256, i256) -> ()
  // CHECK:         yul.func_call @__sol.clear_string_tail
  // CHECK:         yul.for
  // CHECK:           %[[W:.*]] = yul.sload
  // CHECK:           yul.sstore %{{.*}}, %[[W]]

  // Self-assignment is skipped.
  // CHECK-LABEL: yul.func @ss : (i256, i256) -> ()
  // CHECK:         %[[NE:.*]] = yul.cmp ne, %arg0, %arg1
  // CHECK:         yul.if %[[NE]] {
  // CHECK:           yul.func_call @__sol.copy.storage.storage.string(%arg0, %arg1)
  sol.func @ss(%a: !sol.string<Storage>, %b: !sol.string<Storage>) {
    sol.copy %a, %b : !sol.string<Storage>, !sol.string<Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // CHECK-LABEL: yul.func @__sol.copy.calldata.storage.string : (i256, i256, i256) -> ()
  // CHECK:         yul.func_call @__sol.clear_string_tail(
  // CHECK:         yul.for
  // CHECK:           %[[W:.*]] = yul.calldataload
  // CHECK:           yul.sstore %{{.*}}, %[[W]]
  // CHECK:         %[[W:.*]] = yul.calldataload
  // CHECK:         %[[BITS:.*]] = yul.sub
  // CHECK:         %[[ONES:.*]] = yul.constant -1
  // CHECK:         %[[M:.*]] = yul.arith_shl %[[ONES]], %[[BITS]]
  // CHECK:         %[[V:.*]] = yul.and %[[W]], %[[M]]
  // CHECK:         yul.sstore %{{.*}}, %[[V]]
  // CHECK:         %[[W:.*]] = yul.calldataload
  // CHECK:         %[[BITS:.*]] = yul.sub
  // CHECK:         %[[ONES:.*]] = yul.constant -1
  // CHECK:         %[[M:.*]] = yul.arith_shl %[[ONES]], %[[BITS]]
  // CHECK:         %[[V:.*]] = yul.and %[[W]], %[[M]]
  // CHECK:         %[[LEN:.*]] = yul.mul
  // CHECK:         %[[P:.*]] = yul.or %[[V]], %[[LEN]]
  // CHECK:         yul.sstore %arg2, %[[P]]

  // CHECK-LABEL: yul.func @cs : (!llvm.struct<(i256, i256)>, i256) -> ()
  // CHECK:         yul.func_call @__sol.copy.calldata.storage.string(%{{.*}}, %{{.*}}, %arg1)
  sol.func @cs(%c: !sol.string<CallData>, %s: !sol.string<Storage>) {
    sol.copy %c, %s : !sol.string<CallData>, !sol.string<Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // CHECK-LABEL: yul.func @__sol.copy_string_data.storage.memory : (i256, i256, i256, i256) -> ()
  // CHECK:         yul.keccak256
  // CHECK:         yul.for
  // CHECK:           %[[W:.*]] = yul.sload
  // CHECK:           yul.mstore %{{.*}}, %[[W]]

  // CHECK-LABEL: yul.func @m2 : (i256) -> i256
  // CHECK:         %[[W:.*]] = yul.sload %arg0
  // CHECK:         %[[P:.*]] = yul.mload
  // CHECK:         yul.func_call @__sol.copy_string_data.storage.memory(%arg0, %[[W]], %{{.*}}, %{{.*}})
  // CHECK:         yul.func_return %[[P]] : i256
  sol.func @m2(%s: !sol.string<Storage>) -> !sol.string<Memory> {
    %0 = sol.data_loc_cast %s : !sol.string<Storage>, !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // CHECK-LABEL: yul.func @ld : (i256, i256) -> i256
  // CHECK:         %[[OOB:.*]] = yul.cmp uge, %arg1
  // CHECK:         yul.if %[[OOB]] {
  // CHECK:           yul.constant 50
  // CHECK:         %[[W:.*]] = yul.sload
  // CHECK:         %[[B:.*]] = yul.arith_shr %[[W]]
  // CHECK:         %[[C248:.*]] = yul.constant 248
  // CHECK:         %[[R:.*]] = yul.arith_shl %[[B]], %[[C248]]
  // CHECK:         yul.func_return %[[R]] : i256
  sol.func @ld(%s: !sol.string<Storage>, %i: ui256) -> !sol.fixedbytes<1> {
    %0 = sol.gep %s, %i : !sol.string<Storage>, ui256, !sol.ptr<!sol.byte, Storage>
    %1 = sol.load %0 : !sol.ptr<!sol.byte, Storage>, !sol.byte
    %2 = sol.bytes_cast %1 : !sol.byte to !sol.fixedbytes<1>
    sol.return %2 : !sol.fixedbytes<1>
  }
} {kind = #sol<ContractKind Contract>, runtime}

// -----

sol.contract @C {
  // Out-of-bounds index panics with 0x32; the byte goes at offset 31 - i % 32.
  // CHECK-LABEL: yul.func @st : (i256, i256) -> ()
  // CHECK:         %[[OOB:.*]] = yul.cmp uge, %arg1
  // CHECK:         yul.if %[[OOB]] {
  // CHECK:           yul.constant 50
  // CHECK:         yul.arith_mod
  // CHECK:         %[[C31:.*]] = yul.constant 31
  // CHECK:         yul.sub %[[C31]], %{{.*}}
  // CHECK:         yul.sstore
  sol.func @st(%s: !sol.string<Storage>, %i: ui256) {
    %c = sol.constant 65 : ui8
    %0 = sol.gep %s, %i : !sol.string<Storage>, ui256, !sol.ptr<!sol.byte, Storage>
    %1 = sol.bytes_cast %c : ui8 to !sol.byte
    sol.store %1, %0 : !sol.byte, !sol.ptr<!sol.byte, Storage>
    sol.return
  }
} {kind = #sol<ContractKind Contract>, runtime}
