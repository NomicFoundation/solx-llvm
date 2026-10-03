// REQUIRES: asserts
// RUN: not --crash mlir-opt %s --convert-sol-to-yul

module attributes {sol.evm_version = #sol<EvmVersion Homestead>} {
  sol.contract @C {
    sol.func @f(%a: !sol.address, %gas: ui256, %v: ui256) {
      %sel = sol.constant 3017696395 : ui256
      %status = sol.ext_call "g"() at %a gas %gas value %v selector %sel {callee_type = () -> ()} : !sol.address, () -> i1
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
