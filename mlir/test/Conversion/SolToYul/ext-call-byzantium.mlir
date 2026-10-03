// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// sol.ext_call needs at least Byzantium.

// CHECK-LABEL: yul.func @f
// CHECK:         yul.call
module attributes {sol.evm_version = #sol<EvmVersion Byzantium>} {
  sol.contract @C {
    sol.func @f(%a: !sol.address, %gas: ui256, %v: ui256) {
      %sel = sol.constant 3017696395 : ui256
      %status = sol.ext_call "g"() at %a gas %gas value %v selector %sel {callee_type = () -> ()} : !sol.address, () -> i1
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
