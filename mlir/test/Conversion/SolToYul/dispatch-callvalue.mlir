// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// The dispatcher tests the call value once, above the selector switch, when
// no route reachable from the switch accepts value: every interface function
// and the fallback, which the switch's default falls through to, are
// non-payable. With a payable interface function or a payable fallback the
// test stays inside each non-payable case. A receive function does not
// count, it is only reached with empty calldata, outside the switch. A
// library tests nothing, its functions cannot be payable.

#Contract = #sol<ContractKind Contract>
#Library = #sol<ContractKind Library>
#Fallback = #sol<FunctionKind Fallback>
#Receive = #sol<FunctionKind Receive>
#NonPayable = #sol<StateMutability NonPayable>
#Payable = #sol<StateMutability Payable>
#Pure = #sol<StateMutability Pure>
module {
  // Two non-payable functions and a payable receive: one test, above the
  // switch.
  sol.contract @AllNonPayable {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @g() attributes {orig_fn_type = () -> (), selector = 2 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @receive() attributes {kind = #Receive, orig_fn_type = () -> (), state_mutability = #Payable} {
      sol.return
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @AllNonPayable_deployed {
// CHECK:         yul.func @f
// CHECK:         yul.calldatasize
// CHECK:         yul.callvalue
// CHECK:         yul.switch
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func_call @f()
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func_call @g()
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func_call @receive()
// CHECK-NOT:     yul.callvalue


// -----

#Contract = #sol<ContractKind Contract>
#Library = #sol<ContractKind Library>
#Fallback = #sol<FunctionKind Fallback>
#Receive = #sol<FunctionKind Receive>
#NonPayable = #sol<StateMutability NonPayable>
#Payable = #sol<StateMutability Payable>
#Pure = #sol<StateMutability Pure>
module {
  // A payable function among them: the test stays in the non-payable case.
  sol.contract @Mixed {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @g() attributes {orig_fn_type = () -> (), selector = 2 : i32, state_mutability = #Payable} {
      sol.return
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @Mixed_deployed {
// CHECK:         yul.func @f
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.switch
// CHECK:         case 1 {
// CHECK:         yul.callvalue
// CHECK:         yul.func_call @f()
// CHECK:         case 2 {
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func_call @g()
// CHECK-NOT:     yul.callvalue


// -----

#Contract = #sol<ContractKind Contract>
#Library = #sol<ContractKind Library>
#Fallback = #sol<FunctionKind Fallback>
#Receive = #sol<FunctionKind Receive>
#NonPayable = #sol<StateMutability NonPayable>
#Payable = #sol<StateMutability Payable>
#Pure = #sol<StateMutability Pure>
module {
  // A payable fallback behind the switch's default: the tests stay in the
  // cases.
  sol.contract @PayableFallback {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @fallback() attributes {kind = #Fallback, orig_fn_type = () -> (), state_mutability = #Payable} {
      sol.return
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @PayableFallback_deployed {
// CHECK:         yul.func @f
// CHECK-NOT:     yul.callvalue
// CHECK:         case 1 {
// CHECK:         yul.callvalue
// CHECK:         yul.func_call @f()
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func_call @fallback()
// CHECK-NOT:     yul.callvalue


// -----

#Contract = #sol<ContractKind Contract>
#Library = #sol<ContractKind Library>
#Fallback = #sol<FunctionKind Fallback>
#Receive = #sol<FunctionKind Receive>
#NonPayable = #sol<StateMutability NonPayable>
#Payable = #sol<StateMutability Payable>
#Pure = #sol<StateMutability Pure>
module {
  // A non-payable fallback keeps its own test: it is also reached with less
  // than four bytes of calldata, below the hoisted test.
  sol.contract @NonPayableFallback {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @fallback() attributes {kind = #Fallback, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @NonPayableFallback_deployed {
// CHECK:         yul.calldatasize
// CHECK:         yul.callvalue
// CHECK:         yul.switch
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func_call @f()
// CHECK:         yul.callvalue
// CHECK:         yul.func_call @fallback()


// -----

#Contract = #sol<ContractKind Contract>
#Library = #sol<ContractKind Library>
#Fallback = #sol<FunctionKind Fallback>
#Receive = #sol<FunctionKind Receive>
#NonPayable = #sol<StateMutability NonPayable>
#Payable = #sol<StateMutability Payable>
#Pure = #sol<StateMutability Pure>
module {
  // state_mutability is optional. A fallback without it is non-payable, the
  // same reading its own test takes, so the hoist still happens.
  sol.contract @FallbackWithoutMutability {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @fallback() attributes {kind = #Fallback, orig_fn_type = () -> ()} {
      sol.return
    }
  } {kind = #Contract, runtime}
}

// CHECK-LABEL: yul.object @FallbackWithoutMutability_deployed {
// CHECK:         yul.calldatasize
// CHECK:         yul.callvalue
// CHECK:         yul.switch
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func_call @f()
// CHECK:         yul.callvalue
// CHECK:         yul.func_call @fallback()


// -----

#Contract = #sol<ContractKind Contract>
#Library = #sol<ContractKind Library>
#Fallback = #sol<FunctionKind Fallback>
#Receive = #sol<FunctionKind Receive>
#NonPayable = #sol<StateMutability NonPayable>
#Payable = #sol<StateMutability Payable>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @Lib {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #Pure} {
      sol.return
    }
  } {kind = #Library, runtime}
}

// CHECK-LABEL: yul.object @Lib_deployed {
// CHECK:         yul.func @f
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func_call @f()
// CHECK-NOT:     yul.callvalue
