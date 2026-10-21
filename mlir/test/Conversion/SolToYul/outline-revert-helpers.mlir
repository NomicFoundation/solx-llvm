// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A `revert` or `require` with a custom error is emitted once per error and
// argument type list as `__sol.revert.<selector>.<ty>...`, which takes the
// argument values, so sites that raise the same error with different values
// share it. The types are part of the key because the selector only covers
// the ABI types: the same `E(string)` raised with a memory, calldata or
// storage string encodes from a different location, and the calldata string
// lowers to two words, so each location gets its own helper. Every panic goes
// through the contract's one `__sol.panic`, which takes the code.
// A constant string argument is keyed as `constant_string_<keccak>`.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
#View = #sol<StateMutability View>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @one(%arg0: ui256) attributes {orig_fn_type = (ui256) -> (), selector = 1 : i32, state_mutability = #Pure} {
      sol.revert "E(uint256)"(%arg0 : ui256) {call}
      sol.return
    }
    sol.func @two(%arg0: ui256) attributes {orig_fn_type = (ui256) -> (), selector = 2 : i32, state_mutability = #Pure} {
      %c7_ui256 = sol.constant 7 : ui256
      sol.revert "E(uint256)"(%c7_ui256 : ui256) {call}
      sol.return
    }
    sol.func @three(%arg0: i1) attributes {orig_fn_type = (i1) -> (), selector = 3 : i32, state_mutability = #Pure} {
      sol.require %arg0, "F()" {call}
      sol.revert "F()" {call}
      sol.return
    }
    sol.func @panic(%arg0: ui256) -> !sol.array<? x ui256, Memory> attributes {orig_fn_type = (ui256) -> !sol.array<? x ui256, Memory>, selector = 4 : i32, state_mutability = #Pure} {
      %0 = sol.malloc %arg0 zero_init : (ui256) -> !sol.array<? x ui256, Memory>
      sol.return %0 : !sol.array<? x ui256, Memory>
    }
    sol.state_var @s slot 0 offset 0 : !sol.string<Storage>
    sol.func @mem(%arg0: !sol.string<Memory>) attributes {orig_fn_type = (!sol.string<Memory>) -> (), selector = 5 : i32, state_mutability = #Pure} {
      sol.revert "E(string)"(%arg0 : !sol.string<Memory>) {call}
      sol.return
    }
    sol.func @cd(%arg0: !sol.string<CallData>) attributes {orig_fn_type = (!sol.string<CallData>) -> (), selector = 6 : i32, state_mutability = #Pure} {
      sol.revert "E(string)"(%arg0 : !sol.string<CallData>) {call}
      sol.return
    }
    sol.func @st() attributes {orig_fn_type = () -> (), selector = 7 : i32, state_mutability = #View} {
      %0 = sol.addr_of @s : !sol.string<Storage>
      sol.revert "E(string)"(%0 : !sol.string<Storage>) {call}
      sol.return
    }
    sol.func @lit(%arg0: i1, %arg1: ui256) attributes {state_mutability = #Pure} {
      %0 = sol.constant_string "abc"
      sol.require %arg0, "E(string,uint256)"(%0, %arg1 : !sol.constant_string, ui256) {call}
      %1 = sol.constant_string "abc"
      sol.revert "E(string,uint256)" (%1, %arg1 : !sol.constant_string, ui256) {call}
      sol.return
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed
// A require and a revert of the same literal share one helper.
// CHECK-LABEL:   yul.func @__sol.revert.f2047230.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45.ui256 : (i256) -> ()
// CHECK-NEXT:    ^bb0(%[[X:.*]]: i256):
// CHECK:           %[[MEM:.*]] = yul.mload
// CHECK:           %[[START:.*]] = yul.add %[[MEM]]
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45.ui256(%[[X]], %[[START]]) : (i256, i256) -> i256
// CHECK:           yul.revert %[[MEM]]
// The same `E(string)` from three locations: three helpers, each with its
// own lowered argument type and its own encoder.
// CHECK-LABEL:   yul.func @__sol.revert.3e9992c9.string$_Storage_$ : (i256) -> ()
// CHECK:           yul.mstore %{{.*}}, %c28314737286989520401163906651831194152797252710407759610990861806076566700032
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.string$_Storage_$(%arg0
// CHECK:           yul.revert
// CHECK-LABEL:   yul.func @__sol.revert.3e9992c9.string$_CallData_$ : (!llvm.struct<(i256, i256)>) -> ()
// CHECK:           yul.mstore %{{.*}}, %c28314737286989520401163906651831194152797252710407759610990861806076566700032
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.string$_CallData_$(%arg0
// CHECK:           yul.revert
// CHECK-LABEL:   yul.func @__sol.revert.3e9992c9.string$_Memory_$ : (i256) -> ()
// CHECK:           yul.mstore %{{.*}}, %c28314737286989520401163906651831194152797252710407759610990861806076566700032
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.string$_Memory_$(%arg0
// CHECK:           yul.revert

// CHECK-LABEL:   yul.func @__sol.panic : (i256) -> ()
// CHECK:           yul.mstore %c0{{.*}}, %c35408467139433450592217433187231851964531694900788300625387963629091585785856
// CHECK:           yul.mstore %c4{{.*}}, %arg0
// CHECK:           yul.revert %c0{{.*}}, %c36
// CHECK-LABEL:   yul.func @__sol.revert.28811f59 : () -> ()
// CHECK:           %[[F:.*]] = yul.mload %c64
// CHECK:           yul.mstore %[[F]], %c18320653568259070997333563987999395423151336464787283864857095557675424415744
// CHECK:           yul.revert %[[F]],
// CHECK-LABEL:   yul.func @__sol.revert.002ff067.ui256 : (i256) -> ()
// CHECK:           %[[E:.*]] = yul.mload %c64
// CHECK:           yul.mstore %[[E]], %c84701008042320515315298174644417619374439393932350505483920050946320629760
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(%arg0
// CHECK:           yul.revert %[[E]]

// CHECK-LABEL:   yul.func @lit :
// CHECK:           yul.if
// CHECK-NEXT:        yul.func_call @__sol.revert.f2047230.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45.ui256(%arg1) : (i256) -> ()
// CHECK:           yul.func_call @__sol.revert.f2047230.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45.ui256(%arg1) : (i256) -> ()
// CHECK-LABEL:   yul.func @st
// CHECK:           yul.func_call @__sol.revert.3e9992c9.string$_Storage_$(%c0{{.*}}) : (i256) -> ()
// CHECK-LABEL:   yul.func @cd
// CHECK:           yul.func_call @__sol.revert.3e9992c9.string$_CallData_$(%arg0) : (!llvm.struct<(i256, i256)>) -> ()
// CHECK-LABEL:   yul.func @mem
// CHECK:           yul.func_call @__sol.revert.3e9992c9.string$_Memory_$(%arg0) : (i256) -> ()
// CHECK-LABEL:   yul.func @panic
// CHECK:           yul.func_call @__sol.panic(%c65
// CHECK-LABEL:   yul.func @three
// CHECK:           yul.func_call @__sol.revert.28811f59() : () -> ()
// CHECK:           yul.func_call @__sol.revert.28811f59() : () -> ()
// CHECK-LABEL:   yul.func @two
// CHECK:           yul.func_call @__sol.revert.002ff067.ui256(%c7
// CHECK-LABEL:   yul.func @one
// CHECK:           yul.func_call @__sol.revert.002ff067.ui256(%arg0) : (i256) -> ()
