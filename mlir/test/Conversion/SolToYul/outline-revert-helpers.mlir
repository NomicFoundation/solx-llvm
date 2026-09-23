// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A `revert` or `require` with a custom error is emitted once per error as
// `__sol.revert.<selector>`, which takes the argument values, so sites that
// raise the same error with different values share it. Every panic goes
// through the contract's one `__sol.panic`, which takes the code.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Osaka = #sol<EvmVersion Osaka>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @one(%arg0: ui256) attributes {orig_fn_type = (ui256) -> (), selector = 1 : i32, state_mutability = #Pure} {
      sol.revert "E(uint256)" %arg0 : ui256 {call}
      sol.return
    }
    sol.func @two(%arg0: ui256) attributes {orig_fn_type = (ui256) -> (), selector = 2 : i32, state_mutability = #Pure} {
      %c7_ui256 = sol.constant 7 : ui256
      sol.revert "E(uint256)" %c7_ui256 : ui256 {call}
      sol.return
    }
    sol.func @three(%arg0: i1) attributes {orig_fn_type = (i1) -> (), selector = 3 : i32, state_mutability = #Pure} {
      sol.require %arg0, "F()" () {call}
      sol.revert "F()" {call}
      sol.return
    }
    sol.func @panic(%arg0: ui256) -> !sol.array<? x ui256, Memory> attributes {orig_fn_type = (ui256) -> !sol.array<? x ui256, Memory>, selector = 4 : i32, state_mutability = #Pure} {
      %0 = sol.malloc %arg0 zero_init : ui256 !sol.array<? x ui256, Memory>
      sol.return %0 : !sol.array<? x ui256, Memory>
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @C_deployed
// CHECK-LABEL:   yul.func @__sol.panic : (i256) -> ()
// CHECK:           yul.mstore %c0{{.*}}, %c35408467139433450592217433187231851964531694900788300625387963629091585785856
// CHECK:           yul.mstore %c4{{.*}}, %arg0
// CHECK:           yul.revert %c0{{.*}}, %c36
// CHECK-LABEL:   yul.func @__sol.revert.28811f59 : () -> ()
// CHECK:           %[[F:.*]] = yul.mload %c64
// CHECK:           yul.mstore %[[F]], %c18320653568259070997333563987999395423151336464787283864857095557675424415744
// CHECK:           yul.revert %[[F]],
// CHECK-LABEL:   yul.func @__sol.revert.002ff067 : (i256) -> ()
// CHECK:           %[[E:.*]] = yul.mload %c64
// CHECK:           yul.mstore %[[E]], %c84701008042320515315298174644417619374439393932350505483920050946320629760
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(%arg0
// CHECK:           yul.revert %[[E]]
// CHECK-LABEL:   yul.func @panic
// CHECK:           yul.func_call @__sol.panic(%c65
// CHECK-LABEL:   yul.func @three
// CHECK:           yul.func_call @__sol.revert.28811f59() : () -> ()
// CHECK:           yul.func_call @__sol.revert.28811f59() : () -> ()
// CHECK-LABEL:   yul.func @two
// CHECK:           yul.func_call @__sol.revert.002ff067(%c7
// CHECK-LABEL:   yul.func @one
// CHECK:           yul.func_call @__sol.revert.002ff067(%arg0) : (i256) -> ()
