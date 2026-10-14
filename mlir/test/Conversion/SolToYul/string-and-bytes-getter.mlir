// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C {
// CHECK:         yul.func_call @_25()

// CHECK-LABEL: yul.func @__sol.clear_storage_string_tail : (i256, i256, i256) -> ()
// CHECK-LABEL: yul.func @__sol.copy_string.memory.storage : (i256, i256) -> ()
// CHECK:         yul.func_call @__sol.clear_storage_string_tail(%arg1,

// The literal is materialized in memory, then copied into its slot.
// CHECK-LABEL: yul.func @_25 : () -> ()
// CHECK:         %[[A:.*]] = yul.mload
// CHECK:         yul.constant 47219736118185034978131396930477889456522225816706544572588755557152609796096
// CHECK:         %[[ASLOT:.*]] = yul.constant 0{{$}}
// CHECK:         yul.func_call @__sol.copy_string.memory.storage(%[[A]], %[[ASLOT]])
module {
  sol.contract @C {
    sol.state_var @a slot 0 offset 0 : !sol.string<Storage>
    sol.func @_25() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      %0 = sol.string_lit "hello world" -> !sol.string<Memory>
      %1 = sol.addr_of @a : !sol.string<Storage>
      sol.copy %0, %1 : !sol.string<Memory>, !sol.string<Storage>
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// The getter's memory copy is ABI-encoded as a dynamic return by the tuple
// encoder helper.
// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         case 230582047 {
// CHECK:           %[[S:.*]] = yul.func_call @get_a() : () -> i256
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.string$_Memory_$(%[[S]],

// CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.string$_Memory_$ : (i256, i256) -> i256
// CHECK:         %[[LEN:.*]] = yul.mload %arg0
// CHECK:         %[[SRC:.*]] = yul.add %arg0, %{{.*}}
// CHECK:         yul.mcopy %{{.*}}, %[[SRC]], %[[LEN]]

// CHECK-LABEL: yul.func @__sol.copy_string_bytes.storage.memory : (i256, i256, i256, i256) -> ()

// The storage string is cloned into memory: its length is read from the slot,
// the memory string allocated and the bytes copied.
// CHECK-LABEL: yul.func @__sol.clone_string.storage.memory : (i256) -> i256
// CHECK:         %[[W:.*]] = yul.sload %arg0
// CHECK:         %[[LEN:.*]] = yul.func_call @__sol.storage_string_length(%[[W]])
// CHECK:         yul.func_call @__sol.alloc
// CHECK:         yul.func_call @__sol.copy_string_bytes.storage.memory(%arg0, %[[W]], %[[LEN]],

// CHECK-LABEL: yul.func @get_a : () -> i256
// CHECK:         %[[SLOT:.*]] = yul.constant 0
// CHECK:         yul.func_call @__sol.clone_string.storage.memory(%[[SLOT]])
module {
  sol.contract @C {
    sol.state_var @a slot 0 offset 0 : !sol.string<Storage>
    sol.func @get_a() -> !sol.string<Memory> attributes {orig_fn_type = () -> !sol.string<Memory>, selector = 230582047 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @a : !sol.string<Storage>
      %1 = sol.data_loc_cast %0 : !sol.string<Storage>, !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}
