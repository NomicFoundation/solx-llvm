// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
#Initializer = #sol<FunctionKind Initializer>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C {
// CHECK:         yul.func @init
// CHECK:         yul.object @C_deployed {
// CHECK:           yul.func @g
// CHECK:         yul.func @g
sol.contract @C {
  sol.func @init() attributes {kind = #Initializer, state_mutability = #NonPayable} {
    sol.call @g() : () -> ()
    sol.return
  }
  sol.func private @g() attributes {state_mutability = #NonPayable} {
    sol.return
  }
} {kind = #Contract}
