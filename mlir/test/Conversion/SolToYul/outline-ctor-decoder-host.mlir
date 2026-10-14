// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck --strict-whitespace %s

// The constructor's arguments are decoded by code emitted directly into the
// creation object's entry block, which the contract does not enclose. A helper
// requested from there is hosted by the module's one contract and moves into
// the object with the constructor. Nothing lands at module scope, outside the
// object that calls it.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    // The constructor's parameter tuple is decoded by the outlined
    // `__sol.abi_decode_tuple.*`, requested from the creation object's entry.
    sol.func @ctor(%arg0: !sol.array<? x ui8, Memory>) attributes {kind = #Constructor, orig_fn_type = (!sol.array<? x ui8, Memory>) -> (), state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract}
}

// The entry function calls the helper, which is defined in the object, one
// level below the module, after the entry function and before the
// constructor. No function sits at module scope.
// CHECK-NOT:  {{^}}  yul.func
// CHECK:      {{^}}  yul.object @C {
// CHECK:      {{^}}    yul.func @__entry
// CHECK:      {{^}}      %{{.*}} = yul.func_call @__sol.abi_decode_tuple.memory.array$_dyn_ui8_$_Memory_$(
// CHECK:      {{^}}    yul.func @__sol.abi_decode_tuple.memory.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256 {
// CHECK:      {{^}}    yul.func @ctor
// CHECK:      {{^}}  }
// CHECK-NOT:  {{^}}  yul.func
