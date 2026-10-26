// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // The argument is encoded by the tuple helper after the selector.
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.ui256 : (i256, i256) -> i256
    // CHECK:         yul.mstore %arg1, %arg0
    // CHECK-LABEL: yul.func @f : (i256, i256, i256, i256) -> i256
    // CHECK:       ^bb0(%[[A:.*]]: i256, %[[X:.*]]: i256, %[[GAS:.*]]: i256, %[[V:.*]]: i256):
    // CHECK:         %[[SEL:.*]] = yul.constant 3017696395
    // CHECK:         %[[ADDR:.*]] = yul.and %[[A]], %{{.*}}
    // CHECK:         %[[BUF:.*]] = yul.mload
    // CHECK:         %[[SEL_W:.*]] = yul.arith_shl %[[SEL]], %{{.*}}
    // CHECK:         yul.mstore %[[BUF]], %[[SEL_W]]
    // CHECK:         %[[ARGS:.*]] = yul.add %[[BUF]], %{{.*}}
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(%[[X]], %[[ARGS]])
    // CHECK:         %[[OK:.*]] = yul.call %[[GAS]], %[[ADDR]], %[[V]], %[[BUF]], %{{.*}}, %[[BUF]], %{{.*}}
    // CHECK:         %[[FAIL:.*]] = yul.cmp eq, %[[OK]], %{{.*}}
    // CHECK:         yul.if %[[FAIL]] {
    // CHECK:           yul.returndatacopy
    // CHECK:           yul.revert
    // CHECK:         yul.returndatasize
    // CHECK-NOT:     yul.mstore %c64_i256
    // CHECK:         yul.func_call @__sol.abi_decode_tuple.memory.ui256(%[[BUF]], %{{.*}})
    sol.func @f(%a: !sol.address, %x: ui256, %gas: ui256, %v: ui256) -> ui256 attributes {state_mutability = #NonPayable} {
      %sel = sol.constant 3017696395 : ui256
      %status, %outs = sol.ext_call "g"(%x) at %a gas %gas value %v selector %sel {callee_type = (ui256) -> ui256} : !sol.address, (ui256) -> (i1, ui256)
      sol.return %outs : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // A view caller uses staticcall with a 96-byte return buffer, then decodes
    // three words from it through the tuple helper.
    // CHECK-LABEL: yul.func @__sol.abi_decode_tuple.memory.ui256.ui256.ui256 : (i256, i256) -> (i256, i256, i256)
    // CHECK:       ^bb0(%[[HEAD:.*]]: i256, %[[END:.*]]: i256):
    // CHECK:         %[[SIZE:.*]] = yul.sub %[[END]], %[[HEAD]]
    // CHECK:         yul.cmp slt, %[[SIZE]], %{{.*}}
    // CHECK:         %[[A:.*]] = yul.mload %[[HEAD]]
    // CHECK:         %[[P1:.*]] = yul.add %[[HEAD]], %{{.*}}
    // CHECK:         %[[B:.*]] = yul.mload %[[P1]]
    // CHECK:         %[[P2:.*]] = yul.add %[[P1]], %{{.*}}
    // CHECK:         %[[C:.*]] = yul.mload %[[P2]]
    // CHECK:         yul.func_return %[[A]], %[[B]], %[[C]] : i256, i256, i256
    // CHECK-LABEL: yul.func @multiResult : (i256) -> (i256, i256, i256)
    // CHECK:         %[[GAS:.*]] = yul.gas
    // CHECK:         %[[BUF:.*]] = yul.mload
    // CHECK:         %[[C96:.*]] = yul.constant 96
    // CHECK:         %[[OK:.*]] = yul.static_call %[[GAS]], %{{.*}}, %[[BUF]], %{{.*}}, %[[BUF]], %[[C96]]
    // CHECK:         %[[FAIL:.*]] = yul.cmp eq, %[[OK]], %{{.*}}
    // CHECK:         yul.if %[[FAIL]] {
    // CHECK:           yul.returndatacopy
    // CHECK:         %[[R:.*]]:3 = yul.if %{{.*}} -> i256, i256, i256 {
    // CHECK:           yul.returndatasize
    // CHECK:           %[[D:.*]]:3 = yul.func_call @__sol.abi_decode_tuple.memory.ui256.ui256.ui256(%[[BUF]], %{{.*}})
    // CHECK:           yul.yield %[[D]]#0, %[[D]]#1, %[[D]]#2 : i256, i256, i256
    // CHECK:         yul.func_return %[[R]]#0, %[[R]]#1, %[[R]]#2 : i256, i256, i256
    sol.func @multiResult(%arg0: !sol.address) -> (ui256, ui256, ui256) {
      %c3017696395_ui256 = sol.constant 3017696395 : ui256
      %0 = sol.gasleft : ui256
      %c0_ui256 = sol.constant 0 : ui256
      %status, %outs:3 = sol.ext_call "f"() at %arg0 gas %0 value %c0_ui256 selector %c3017696395_ui256 {callee_type = () -> (ui256, ui256, ui256), static_call} : !sol.address, () -> (i1, ui256, ui256, ui256)
      sol.return %outs#0, %outs#1, %outs#2 : ui256, ui256, ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

// Dynamic results are not sized at the call: staticcall reserves no output,
// then the whole returndata is copied into the buffer and decoded.

#View = #sol<StateMutability View>
module {
  sol.contract @C {
    // uint8[] calldata is re-encoded element-wise by the tuple helper,
    // validating each element.
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.array$_dyn_ui8_$_CallData_$ : (!llvm.struct<(i256, i256)>, i256) -> i256
    // CHECK:         yul.for
    // CHECK:         } body {
    // CHECK:           %[[E:.*]] = yul.calldataload
    // CHECK:           %[[C255:.*]] = yul.constant 255
    // CHECK:           %[[CLEAN:.*]] = yul.and %[[E]], %[[C255]]
    // CHECK:           %[[BAD:.*]] = yul.cmp ne, %[[E]], %[[CLEAN]]
    // CHECK:           yul.if %[[BAD]] {
    // CHECK:             yul.revert
    // CHECK:           yul.mstore %{{.*}}, %[[CLEAN]]
    // CHECK-LABEL: yul.func @calldataArray : (i256, !llvm.struct<(i256, i256)>) -> i256
    // CHECK:         yul.constant 2225455406
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.array$_dyn_ui8_$_CallData_$(%arg1, %{{.*}})
    // CHECK:         yul.static_call
    sol.func @calldataArray(%arg0: !sol.address, %arg1: !sol.array<? x ui8, CallData>) -> !sol.string<Memory> attributes {state_mutability = #View} {
      %sel = sol.constant 2225455406 : ui256
      %gas = sol.gasleft : ui256
      %c0 = sol.constant 0 : ui256
      %status, %outs = sol.ext_call "h"(%arg1) at %arg0 gas %gas value %c0 selector %sel {callee_type = (!sol.array<? x ui8, Memory>) -> !sol.string<Memory>, static_call} : !sol.address, (!sol.array<? x ui8, CallData>) -> (i1, !sol.string<Memory>)
      sol.return %outs : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#View = #sol<StateMutability View>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.string$_Storage_$ : (i256, i256) -> i256
    // CHECK:       ^bb0(%[[SLOT:.*]]: i256, %[[HEAD:.*]]: i256):
    // CHECK:         %[[DATA:.*]] = yul.sload %[[SLOT]]
    // CHECK:         %[[LEN:.*]] = yul.func_call @__sol.storage_string_length(%[[DATA]])
    // CHECK:         yul.func_call @__sol.copy_string_bytes.storage.memory(%[[SLOT]], %[[DATA]], %[[LEN]], %{{.*}})
    // CHECK-LABEL: yul.func @storageString : (i256, i256) -> i256
    // CHECK:         yul.constant 4119168343
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.string$_Storage_$(%arg1, %{{.*}})
    // CHECK:         yul.static_call
    sol.func @storageString(%arg0: !sol.address, %arg1: !sol.string<Storage>) -> !sol.string<Memory> attributes {state_mutability = #View} {
      %sel = sol.constant 4119168343 : ui256
      %gas = sol.gasleft : ui256
      %c0 = sol.constant 0 : ui256
      %status, %outs = sol.ext_call "h"(%arg1) at %arg0 gas %gas value %c0 selector %sel {callee_type = (!sol.string<Memory>) -> !sol.string<Memory>, static_call} : !sol.address, (!sol.string<Storage>) -> (i1, !sol.string<Memory>)
      sol.return %outs : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#View = #sol<StateMutability View>
module {
  sol.contract @C {
    // The decoder allocates the struct and its array and copies the words in
    // bulk instead of looping over them.
    // CHECK-LABEL: yul.func @__sol.abi_decode_tuple.memory.struct$_$_array$_dyn_ui256_$_Memory_$_$_$_Memory_$ : (i256, i256) -> i256
    // CHECK:         %[[STRUCT:.*]] = yul.mload %c64
    // CHECK:         %[[ARR:.*]] = yul.func_call @__sol.alloc(
    // CHECK:         yul.mstore %[[ARR]], %[[ALEN:.*]]
    // CHECK-NOT:     yul.for
    // CHECK:         yul.mcopy
    // CHECK:         yul.mstore %[[STRUCT]], %[[ARR]]
    // CHECK:         yul.func_return %[[STRUCT]] : i256
    // CHECK-LABEL: yul.func @structRet : (i256) -> i256
    // CHECK:         yul.constant 1481905832
    // CHECK:         %[[BUF:.*]] = yul.mload
    // CHECK:         yul.static_call %{{.*}}, %{{.*}}, %[[BUF]], %{{.*}}, %[[BUF]], %c0_i256{{(_[0-9]+)?$}}
    // CHECK:         %[[R:.*]] = yul.if %{{.*}} -> i256 {
    // CHECK:           %[[RDS:.*]] = yul.returndatasize
    // CHECK:           yul.returndatacopy %[[BUF]], %{{.*}}, %[[RDS]]
    // CHECK:           %[[S:.*]] = yul.func_call @__sol.abi_decode_tuple.memory.struct$_$_array$_dyn_ui256_$_Memory_$_$_$_Memory_$(%[[BUF]], %{{.*}})
    // CHECK:           yul.yield %[[S]] : i256
    // CHECK:         } else {
    // CHECK:         %[[DATA:.*]] = yul.mload
    // CHECK:         %[[LEN:.*]] = yul.mload %[[DATA]]
    // CHECK:         yul.func_return %[[LEN]] : i256
    sol.func @structRet(%arg0: !sol.address) -> ui256 attributes {state_mutability = #View} {
      %c0_ui64 = sol.constant 0 : ui64
      %sel = sol.constant 1481905832 : ui256
      %gas = sol.gasleft : ui256
      %c0 = sol.constant 0 : ui256
      %status, %outs = sol.ext_call "h"() at %arg0 gas %gas value %c0 selector %sel {callee_type = () -> !sol.struct<(!sol.array<? x ui256, Memory>), Memory>, static_call} : !sol.address, () -> (i1, !sol.struct<(!sol.array<? x ui256, Memory>), Memory>)
      %0 = sol.gep %outs, %c0_ui64 : !sol.struct<(!sol.array<? x ui256, Memory>), Memory>, ui64, !sol.ptr<!sol.array<? x ui256, Memory>, Memory>
      %1 = sol.load %0 : !sol.ptr<!sol.array<? x ui256, Memory>, Memory>, !sol.array<? x ui256, Memory>
      %2 = sol.length %1 : !sol.array<? x ui256, Memory>
      sol.return %2 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#View = #sol<StateMutability View>
module {
  sol.contract @C {
    // A static array result is decoded from the return data in memory, which
    // the call reserves.
    // CHECK-LABEL: yul.func @fixedArrayRet : (i256) -> i256
    // CHECK:         %[[BUF:.*]] = yul.mload
    // CHECK:         yul.static_call
    // CHECK:         yul.revert
    // CHECK:         yul.returndatasize
    // CHECK:         yul.mstore %c64_i256{{[_0-9]*}}, %{{.*}}
    // CHECK:         yul.mstore %c64_i256{{[_0-9]*}}, %{{.*}}
    // CHECK:         yul.func_call @__sol.abi_decode_tuple.memory.array$_2_ui256_$_Memory_$(%[[BUF]], %{{.*}})
    sol.func @fixedArrayRet(%arg0: !sol.address) -> !sol.array<2 x ui256, Memory> attributes {state_mutability = #View} {
      %sel = sol.constant 1481905832 : ui256
      %gas = sol.gasleft : ui256
      %c0 = sol.constant 0 : ui256
      %status, %outs = sol.ext_call "h"() at %arg0 gas %gas value %c0 selector %sel {callee_type = () -> !sol.array<2 x ui256, Memory>, static_call} : !sol.address, () -> (i1, !sol.array<2 x ui256, Memory>)
      sol.return %outs : !sol.array<2 x ui256, Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#View = #sol<StateMutability View>
module {
  sol.contract @C {
    // A scalar beside a static array does not spare the reservation the array
    // is decoded from.
    // CHECK-LABEL: yul.func @mixedRet : (i256) -> (i256, i256)
    // CHECK:         %[[BUF:.*]] = yul.mload
    // CHECK:         yul.static_call
    // CHECK:         yul.revert
    // CHECK:         yul.returndatasize
    // CHECK:         yul.mstore %c64_i256{{[_0-9]*}}, %{{.*}}
    // CHECK:         yul.mstore %c64_i256{{[_0-9]*}}, %{{.*}}
    // CHECK:         yul.func_call @__sol.abi_decode_tuple.memory.ui256.array$_2_ui256_$_Memory_$(%[[BUF]], %{{.*}})
    sol.func @mixedRet(%arg0: !sol.address) -> (ui256, !sol.array<2 x ui256, Memory>) attributes {state_mutability = #View} {
      %sel = sol.constant 1481905832 : ui256
      %gas = sol.gasleft : ui256
      %c0 = sol.constant 0 : ui256
      %status, %a, %b = sol.ext_call "h"() at %arg0 gas %gas value %c0 selector %sel {callee_type = () -> (ui256, !sol.array<2 x ui256, Memory>), static_call} : !sol.address, () -> (i1, ui256, !sol.array<2 x ui256, Memory>)
      sol.return %a, %b : ui256, !sol.array<2 x ui256, Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#View = #sol<StateMutability View>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_decode_tuple.memory.string$_Memory_$ : (i256, i256) -> i256
    // CHECK:         %[[STR:.*]] = yul.func_call @__sol.alloc(
    // CHECK:         yul.mcopy
    // CHECK:         yul.func_return %[[STR]] : i256
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.string$_CallData_$ : (!llvm.struct<(i256, i256)>, i256) -> i256
    // CHECK:         yul.calldatacopy
    // CHECK-LABEL: yul.func @calldataString : (i256, !llvm.struct<(i256, i256)>) -> i256
    // CHECK:         %[[SEL:.*]] = yul.constant 151743695
    // CHECK:         %[[BUF:.*]] = yul.mload
    // CHECK:         yul.arith_shl %[[SEL]], %{{.*}}
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.string$_CallData_$(%arg1, %{{.*}})
    // CHECK:         yul.static_call %{{.*}}, %{{.*}}, %[[BUF]], %{{.*}}, %[[BUF]], %c0_i256{{(_[0-9]+)?$}}
    // CHECK:         %[[R:.*]] = yul.if %{{.*}} -> i256 {
    // CHECK:           %[[RDS:.*]] = yul.returndatasize
    // CHECK:           yul.returndatacopy %[[BUF]], %{{.*}}, %[[RDS]]
    // CHECK:           %[[S:.*]] = yul.func_call @__sol.abi_decode_tuple.memory.string$_Memory_$(%[[BUF]], %{{.*}})
    // CHECK:           yul.yield %[[S]] : i256
    // CHECK:         yul.func_return %[[R]] : i256
    sol.func @calldataString(%arg0: !sol.address, %arg1: !sol.string<CallData>) -> !sol.string<Memory> attributes {state_mutability = #View} {
      %sel = sol.constant 151743695 : ui256
      %gas = sol.gasleft : ui256
      %c0 = sol.constant 0 : ui256
      %status, %outs = sol.ext_call "h"(%arg1) at %arg0 gas %gas value %c0 selector %sel {callee_type = (!sol.string<Memory>) -> !sol.string<Memory>, static_call} : !sol.address, (!sol.string<CallData>) -> (i1, !sol.string<Memory>)
      sol.return %outs : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // Through an external function pointer, the target and selector come from the
    // {address, selector} pair; a non-view pointer lowers to call with zero value.
    // CHECK-LABEL: yul.func @callNonPure
    // CHECK:         %[[SEL:.*]] = yul.constant 2850645687
    // CHECK:         %[[REF:.*]] = llvm.insertvalue %[[SEL]], %{{.*}}[1]
    // CHECK:         %[[GAS:.*]] = yul.gas
    // CHECK:         %[[ZERO:.*]] = yul.constant 0
    // CHECK:         %[[C224:.*]] = yul.constant 224
    // CHECK:         yul.arith_shl %{{.*}}, %[[C224]]
    // CHECK:         %[[OK:.*]] = yul.call %[[GAS]], %{{.*}}, %[[ZERO]], %{{.*}}, %{{.*}}, %{{.*}}, %{{.*}}
    // CHECK:         %[[FAIL:.*]] = yul.cmp eq, %[[OK]], %{{.*}}
    // CHECK:         yul.if %[[FAIL]] {
    // CHECK:           yul.returndatacopy
    // CHECK:           yul.revert
    sol.func @callNonPure(%a: !sol.address, %x: ui256) -> ui256 {
      %0 = sol.ext_func_constant %a {selector = -1444321609 : i32} : !sol.address -> !sol.ext_func_ref<(ui256) -> ui256>
      %1 = sol.gasleft : ui256
      %c0 = sol.constant 0 : ui256
      %2:2 = sol.ext_icall %0(%x) gas %1 value %c0 : <(ui256) -> ui256>, (ui256) -> (i1, ui256)
      sol.return %2#1 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    sol.func @g(%x: ui256) {
      sol.return
    }

    // A try call branches on success instead of bubbling the revert.
    // CHECK-LABEL: yul.func @tryCall
    // CHECK:         %[[GAS:.*]] = yul.gas
    // CHECK:         %[[OK:.*]] = yul.static_call %[[GAS]],
    // CHECK-NOT:     yul.returndatacopy
    // CHECK:         %[[SUCC:.*]] = yul.cmp ne, %[[OK]], %{{.*}}
    // CHECK:         %[[RES:.*]] = yul.if %[[SUCC]] -> i256 {
    // CHECK:           yul.returndatasize
    // CHECK:         yul.if %[[SUCC]] {
    // CHECK-NEXT:      yul.func_call @g(%[[RES]])
    // CHECK:         } else {
    // CHECK:         yul.func_return
    sol.func @tryCall(%a: !sol.address, %x: ui256) {
      %0 = sol.ext_func_constant %a {selector = -879277782 : i32} : !sol.address -> !sol.ext_func_ref<(ui256) -> ui256>
      %1 = sol.gasleft : ui256
      %c0 = sol.constant 0 : ui256
      %2:2 = sol.ext_icall %0(%x) gas %1 value %c0 {static_call, try_call} : <(ui256) -> ui256>, (ui256) -> (i1, ui256)
      sol.try %2#0 {
        sol.call @g(%2#1) : (ui256) -> ()
        sol.yield
      } panic {
      } error {
      } fallback {
        sol.yield
      }
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @call :
    // CHECK:         %[[SEL:.*]] = yul.constant 3415689514
    // CHECK:         llvm.insertvalue %[[SEL]], %{{.*}}[1]
    // CHECK:         %[[GAS:.*]] = yul.gas
    // CHECK:         %[[OK:.*]] = yul.static_call %[[GAS]],
    // CHECK:         yul.cmp eq, %[[OK]], %{{.*}}
    // CHECK:         yul.returndatacopy
    sol.func @call(%a: !sol.address, %x: ui256) -> ui256 {
      %0 = sol.ext_func_constant %a {selector = -879277782 : i32} : !sol.address -> !sol.ext_func_ref<(ui256) -> ui256>
      %1 = sol.gasleft : ui256
      %c0 = sol.constant 0 : ui256
      %2:2 = sol.ext_icall %0(%x) gas %1 value %c0 {static_call} : <(ui256) -> ui256>, (ui256) -> (i1, ui256)
      sol.return %2#1 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
