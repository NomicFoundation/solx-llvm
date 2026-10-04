// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C {
// CHECK:         yul.func_call @_25()

// CHECK-LABEL: yul.func @__sol.clear_string_tail : (i256, i256, i256) -> ()
// CHECK-LABEL: yul.func @__sol.copy.memory.storage.string : (i256, i256) -> ()

// The literal is materialized in memory, then copied into its slot.
// CHECK-LABEL: yul.func @_25 : () -> ()
// CHECK:         %[[A:.*]] = yul.mload
// CHECK:         yul.constant 47219736118185034978131396930477889456522225816706544572588755557152609796096
// CHECK:         %[[ASLOT:.*]] = yul.constant 0{{$}}
// CHECK:         yul.func_call @__sol.copy.memory.storage.string(%[[A]], %[[ASLOT]])
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

// The getter's memory copy is ABI-encoded as a dynamic return.
// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         case 230582047 {
// CHECK:           %[[S:.*]] = yul.func_call @get_a() : () -> i256
// CHECK:           %[[LEN:.*]] = yul.mload %[[S]]
// CHECK:           %[[SRC:.*]] = yul.add %[[S]], %{{.*}}
// CHECK:           yul.mcopy %{{.*}}, %[[SRC]], %[[LEN]]

// CHECK-LABEL: yul.func @__sol.copy_string_data.storage.memory : (i256, i256, i256, i256) -> ()

// CHECK-LABEL: yul.func @get_a : () -> i256
// CHECK:         %[[SLOT:.*]] = yul.constant 0
// CHECK:         yul.sload %[[SLOT]]
// CHECK:         yul.func_call @__sol.copy_string_data.storage.memory(%[[SLOT]],
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
