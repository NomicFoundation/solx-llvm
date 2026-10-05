// RUN: mlir-opt %s -split-input-file --convert-sol-to-yul -verify-diagnostics

// The module is lowered to the object of its contract.
// expected-error @below {{'builtin.module' op expects one sol.contract and no nested module}}
module {
}

// -----

#Contract = #sol<ContractKind Contract>

// expected-error @below {{'builtin.module' op expects one sol.contract and no nested module}}
module {
  sol.contract @A {
  } {kind = #Contract, runtime}
  module {
    sol.contract @B {
    } {kind = #Contract, runtime}
  }
}
