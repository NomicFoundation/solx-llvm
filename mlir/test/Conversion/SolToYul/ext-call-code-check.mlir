// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.func @call
// CHECK:         yul.cmp ugt, %arg1, %c1
// CHECK:         yul.extcodesize
// CHECK:         yul.call
sol.contract @ExtCall {
  sol.func @call(%target: !sol.address, %choice: !sol.enum<1>) attributes {orig_fn_type = (!sol.address, !sol.enum<1>) -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %gas = sol.gasleft : ui256
    %value = sol.constant 0 : ui256
    %selector = sol.constant 7 : ui256
    %status = sol.ext_call "take(uint8)"(%choice) at %target gas %gas value %value selector %selector {callee_type = (!sol.enum<1>) -> ()} : !sol.address, (!sol.enum<1>) -> (i1)
    sol.return
  }
} {kind = #Contract}
