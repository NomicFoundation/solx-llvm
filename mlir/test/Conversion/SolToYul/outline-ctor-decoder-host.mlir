// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck --strict-whitespace %s
// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck --strict-whitespace --check-prefix=TOP %s

// The constructor's arguments are decoded by code emitted directly into the
// creation object's entry block. A helper requested from there must be hosted
// by that object, not at module scope: the object is a symbol table of its own
// and becomes its own module, so a module-level helper would end up outside
// the module that calls it.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    // The constructor's parameter tuple is decoded by the outlined
    // `__sol.abi_decode_tuple.*`, requested from the creation object's entry.
    sol.func @ctor(%arg0: !sol.array<? x ui8, Memory>) attributes {id = 1 : i64, kind = #Constructor, orig_fn_type = (!sol.array<? x ui8, Memory>) -> (), state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract}
}

// The helper is nested one level below the module, inside `yul.object @C`,
// and is defined after the deployed object that the creation object wraps.
// CHECK:      {{^}}  yul.object @C {
// CHECK:      {{^}}    yul.object @C_deployed {
// CHECK:      {{^}}    }
// CHECK:      {{^}}    yul.func @__sol.abi_decode_tuple.memory.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256 {
// CHECK:      {{^}}  }

// No helper at module scope.
// TOP-NOT: {{^}}  yul.func @__sol.
