// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.ui256.ui8.si32 : (i256, i256, i256, i256) -> i256
    // CHECK:         yul.mstore %arg3, %arg0
    // CHECK:         %[[BC:.*]] = yul.and %arg1, %c255_i256
    // CHECK:         yul.mstore %{{.*}}, %[[BC]]
    // CHECK:         %[[CC:.*]] = yul.signextend %c3_i256, %arg2
    // CHECK:         yul.mstore %{{.*}}, %[[CC]]
    // CHECK-LABEL: yul.func @encode : (i256, i256, i256) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256.ui8.si32(%arg0, %arg1, %arg2,
    sol.func @encode(%arg0: ui256, %arg1: ui8, %arg2: si32) -> !sol.string<Memory> {
      %0 = sol.encode %arg0, %arg1, %arg2 : (ui256, ui8, si32) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_decode_tuple.memory.ui256.ui8.si32 : (i256, i256) -> (i256, i256, i256)
    // CHECK:         yul.cmp slt, %{{.*}}, %c96_i256
    // CHECK:         %[[A:.*]] = yul.mload
    // CHECK:         %[[B:.*]] = yul.mload
    // CHECK:         %[[BC:.*]] = yul.and %[[B]], %c255_i256
    // CHECK:         yul.cmp ne, %[[B]], %[[BC]]
    // CHECK:         %[[C:.*]] = yul.mload
    // CHECK:         %[[CC:.*]] = yul.signextend %c3_i256, %[[C]]
    // CHECK:         yul.cmp ne, %[[C]], %[[CC]]
    // CHECK:         yul.func_return %[[A]], %[[BC]], %[[CC]] : i256, i256, i256
    // CHECK-LABEL: yul.func @decode : (i256) -> (i256, i256, i256)
    // CHECK:         %[[R:.*]]:3 = yul.func_call @__sol.abi_decode_tuple.memory.ui256.ui8.si32(
    // CHECK:         yul.func_return %[[R]]#0, %[[R]]#1, %[[R]]#2 : i256, i256, i256
    sol.func @decode(%arg0: !sol.string<Memory>) -> (ui256, ui8, si32) {
      %0:3 = sol.decode %arg0 : !sol.string<Memory> -> ui256, ui8, si32
      sol.return %0#0, %0#1, %0#2 : ui256, ui8, si32
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_decode_tuple.calldata.ui256.ui8.si32 : (i256, i256) -> (i256, i256, i256)
    // CHECK:         yul.cmp slt, %{{.*}}, %c96_i256
    // CHECK:         %[[A:.*]] = yul.calldataload
    // CHECK:         %[[B:.*]] = yul.calldataload
    // CHECK:         %[[BC:.*]] = yul.and %[[B]], %c255_i256
    // CHECK:         yul.cmp ne, %[[B]], %[[BC]]
    // CHECK:         %[[C:.*]] = yul.calldataload
    // CHECK:         %[[CC:.*]] = yul.signextend %c3_i256, %[[C]]
    // CHECK:         yul.cmp ne, %[[C]], %[[CC]]
    // CHECK:         yul.func_return %[[A]], %[[BC]], %[[CC]] : i256, i256, i256
    // CHECK-LABEL: yul.func @decode_calldata : (!llvm.struct<(i256, i256)>) -> (i256, i256, i256)
    // CHECK:         %[[PTR:.*]] = llvm.extractvalue %arg0[0]
    // CHECK:         %[[LEN:.*]] = llvm.extractvalue %arg0[1]
    // CHECK:         %[[R:.*]]:3 = yul.func_call @__sol.abi_decode_tuple.calldata.ui256.ui8.si32(%[[PTR]],
    // CHECK:         yul.func_return %[[R]]#0, %[[R]]#1, %[[R]]#2 : i256, i256, i256
    sol.func @decode_calldata(%arg0: !sol.string<CallData>) -> (ui256, ui8, si32) {
      %0:3 = sol.decode %arg0 : !sol.string<CallData> -> ui256, ui8, si32
      sol.return %0#0, %0#1, %0#2 : ui256, ui8, si32
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.packed.inplace.ui24.ui96 : (i256, i256, i256) -> i256
    // CHECK:         %[[X:.*]] = yul.and %arg0, %c16777215_i256
    // CHECK:         %[[XS:.*]] = yul.arith_shl %[[X]], %c232_i256
    // CHECK:         yul.mstore %arg2, %[[XS]]
    // CHECK:         %[[P1:.*]] = yul.add %arg2, %c3_i256
    // CHECK:         %[[Y:.*]] = yul.and %arg1, %c79228162514264337593543950335_i256
    // CHECK:         %[[YS:.*]] = yul.arith_shl %[[Y]], %c160_i256
    // CHECK:         yul.mstore %[[P1]], %[[YS]]
    // CHECK:         %[[END:.*]] = yul.add %[[P1]], %c12_i256
    // CHECK:         yul.func_return %[[END]] : i256
    // CHECK-LABEL: yul.func @encode_packed : (i256, i256) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.packed.inplace.ui24.ui96(%arg0, %arg1,
    sol.func @encode_packed(%arg0: ui24, %arg1: ui96) -> !sol.string<Memory> {
      %0 = sol.encode %arg0, %arg1 : (ui24, ui96) -> !sol.string<Memory> {packed}
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.address : (i256, i256) -> i256
    // CHECK:         %[[C:.*]] = yul.and %arg0, %c1461501637330902918203684832716283019655932542975_i256
    // CHECK:         yul.mstore %arg1, %[[C]]
    // CHECK-LABEL: yul.func @encode_addr : (i256) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.address(%arg0,
    sol.func @encode_addr(%arg0: !sol.address) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.address) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_decode_tuple.memory.address$_payable_$ : (i256, i256) -> i256
    // CHECK:         yul.cmp slt, %{{.*}}, %c32_i256
    // CHECK:         %[[V:.*]] = yul.mload
    // CHECK:         %[[C:.*]] = yul.and %[[V]], %c1461501637330902918203684832716283019655932542975_i256
    // CHECK:         yul.cmp ne, %[[V]], %[[C]]
    // CHECK:         yul.func_return %[[C]] : i256
    // CHECK-LABEL: yul.func @decode_addr : (i256) -> i256
    // CHECK:         %[[R:.*]] = yul.func_call @__sol.abi_decode_tuple.memory.address$_payable_$(
    // CHECK:         yul.func_return %[[R]] : i256
    sol.func @decode_addr(%arg0: !sol.string<Memory>) -> !sol.address<payable> {
      %0 = sol.decode %arg0 : !sol.string<Memory> -> !sol.address<payable>
      sol.return %0 : !sol.address<payable>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.i1 : (i256, i256) -> i256
    // CHECK:         %[[C:.*]] = yul.cmp ne, %arg0, %c0_i256
    // CHECK:         yul.mstore %arg1, %[[C]]
    // CHECK-LABEL: yul.func @encode_bool : (i256) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.i1(%arg0,
    sol.func @encode_bool(%arg0: i1) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (i1) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.enum$_2_$ : (i256, i256) -> i256
    // CHECK:         %[[OOR:.*]] = yul.cmp ugt, %arg0, %c2_i256
    // CHECK:         yul.if %[[OOR]] {
    // CHECK:           yul.func_call @__sol.panic(%c33_i256)
    // CHECK:         yul.mstore %arg1, %arg0
    // CHECK-LABEL: yul.func @encode_enum : (i256) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.enum$_2_$(%arg0,
    sol.func @encode_enum(%arg0: !sol.enum<2>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.enum<2>) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.fixedbytes$_5_$ : (i256, i256) -> i256
    // CHECK:         %[[C:.*]] = yul.and %arg0, %c-105312291668557186697918027683670432318895095400549111254310977536_i256
    // CHECK:         yul.mstore %arg1, %[[C]]
    // CHECK-LABEL: yul.func @encode_bytes5 : (i256) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.fixedbytes$_5_$(%arg0,
    sol.func @encode_bytes5(%arg0: !sol.fixedbytes<5>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.fixedbytes<5>) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.ui256 : (i256, i256) -> i256
    // CHECK:         yul.mstore %arg1, %arg0
    // CHECK-LABEL: yul.func @encode_selector : (i256, i256) -> i256
    // CHECK:         yul.mstore %[[P:.*]], %arg0
    // CHECK:         %[[ARGS:.*]] = yul.add %[[P]], %c4_i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(%arg1, %[[ARGS]])
    sol.func @encode_selector(%arg0: !sol.fixedbytes<4>, %arg1: ui256) -> !sol.string<Memory> {
      %0 = sol.encode selector(%arg0 : !sol.fixedbytes<4>) %arg1 : (ui256) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @encode_selector_literal : () -> i256
    // CHECK:         %[[SEL:.*]] = yul.arith_shl %c69443890_i256, %c224_i256
    // CHECK:         yul.mstore %{{.*}}, %[[SEL]]
    sol.func @encode_selector_literal() -> !sol.string<Memory> {
      %c69443890_ui32 = sol.constant 69443890 : ui32
      %0 = sol.bytes_cast %c69443890_ui32 : ui32 to !sol.fixedbytes<4>
      %1 = sol.encode selector(%0 : !sol.fixedbytes<4>) : () -> !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.ext_func_ref$_$_ui256_$returnsui256_$ : (!llvm.struct<(i256, i256)>, i256) -> i256
    // CHECK:         %[[F:.*]] = yul.or
    // CHECK:         %[[W:.*]] = yul.arith_shl %[[F]], %c64_i256
    // CHECK:         yul.mstore %arg1, %[[W]]
    // CHECK:         yul.add %arg1, %c32_i256
    // CHECK-LABEL: yul.func @encode_fnptr : (!llvm.struct<(i256, i256)>) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.ext_func_ref$_$_ui256_$returnsui256_$(%arg0,
    sol.func @encode_fnptr(%arg0: !sol.ext_func_ref<(ui256) -> ui256>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.ext_func_ref<(ui256) -> ui256>) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.packed.inplace.ext_func_ref$_$_ui256_$returnsui256_$ : (!llvm.struct<(i256, i256)>, i256) -> i256
    // CHECK:         %[[A:.*]] = llvm.extractvalue %arg0[0]
    // CHECK:         %[[S:.*]] = llvm.extractvalue %arg0[1]
    // CHECK:         %[[SEL:.*]] = yul.and %[[S]], %c4294967295_i256
    // CHECK:         %[[AS:.*]] = yul.arith_shl %[[A]], %c32_i256
    // CHECK:         %[[F:.*]] = yul.or %[[AS]], %[[SEL]]
    // CHECK:         %[[W:.*]] = yul.arith_shl %[[F]], %c64_i256
    // CHECK:         yul.mstore %arg1, %[[W]]
    // CHECK:         %[[END:.*]] = yul.add %arg1, %c24_i256
    // CHECK:         yul.func_return %[[END]] : i256
    // CHECK-LABEL: yul.func @encode_packed_fnptr : (!llvm.struct<(i256, i256)>) -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.packed.inplace.ext_func_ref$_$_ui256_$returnsui256_$(%arg0,
    sol.func @encode_packed_fnptr(%arg0: !sol.ext_func_ref<(ui256) -> ui256>) -> !sol.string<Memory> {
      %0 = sol.encode %arg0 : (!sol.ext_func_ref<(ui256) -> ui256>) -> !sol.string<Memory> {packed}
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.string$_Storage_$ : (i256, i256) -> i256
// CHECK:         %[[STR:.*]] = yul.sload %arg0
// CHECK:         %[[LEN:.*]] = yul.func_call @__sol.storage_string_length(%[[STR]])
// CHECK:         yul.func_call @__sol.copy_string_bytes.storage.memory(%arg0, %[[STR]], %[[LEN]],
// CHECK-LABEL: yul.func @encode_selector_storage : (i256) -> i256
// CHECK:         yul.mstore %[[P:.*]], %arg0
// CHECK:         %[[ARGS:.*]] = yul.add %[[P]], %c4_i256
// CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.string$_Storage_$(%c0_i256{{.*}}, %[[ARGS]])
module {
  sol.contract @C {
    sol.state_var @str slot 0 offset 0 : !sol.string<Storage>
    sol.func @encode_selector_storage(%arg0: !sol.fixedbytes<4>) -> !sol.string<Memory> {
      %0 = sol.addr_of @str : !sol.string<Storage>
      %1 = sol.encode selector(%arg0 : !sol.fixedbytes<4>) %0 : (!sol.string<Storage>) -> !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>

// CHECK-LABEL: yul.func @__sol.abi_encode_tuple.packed.inplace.string$_Storage_$.string$_Storage_$ : (i256, i256, i256) -> i256
// CHECK:         %[[S0:.*]] = yul.sload %arg0
// CHECK:         %[[L0:.*]] = yul.func_call @__sol.storage_string_length(%[[S0]])
// CHECK:         yul.func_call @__sol.copy_string_bytes.storage.memory(%arg0, %[[S0]], %[[L0]], %arg2)
// CHECK:         %[[NEXT:.*]] = yul.add %arg2, %[[L0]]
// CHECK:         %[[S1:.*]] = yul.sload %arg1
// CHECK:         %[[L1:.*]] = yul.func_call @__sol.storage_string_length(%[[S1]])
// CHECK:         yul.func_call @__sol.copy_string_bytes.storage.memory(%arg1, %[[S1]], %[[L1]], %[[NEXT]])
// CHECK-LABEL: yul.func @encode_packed_storage : () -> i256
// CHECK:         yul.func_call @__sol.abi_encode_tuple.packed.inplace.string$_Storage_$.string$_Storage_$(%c0_i256{{.*}}, %c1_i256{{.*}},
module {
  sol.contract @C {
    sol.state_var @str slot 0 offset 0 : !sol.string<Storage>
    sol.state_var @str2 slot 1 offset 0 : !sol.string<Storage>
    sol.func @encode_packed_storage() -> !sol.string<Memory> {
      %0 = sol.addr_of @str : !sol.string<Storage>
      %1 = sol.addr_of @str2 : !sol.string<Storage>
      %2 = sol.encode %0, %1 : (!sol.string<Storage>, !sol.string<Storage>) -> !sol.string<Memory> {packed}
      sol.return %2 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}
