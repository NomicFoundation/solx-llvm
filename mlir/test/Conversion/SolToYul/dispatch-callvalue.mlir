// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck %s

// The dispatcher tests the call value once, above the selector switch, when
// no route reachable from the switch accepts value: every interface function
// and the fallback, which the switch's default falls through to, are
// non-payable. With a payable interface function or a payable fallback the
// test stays inside each non-payable case. A receive function does not
// count, it is only reached with empty calldata, outside the switch. A
// library tests nothing, its functions cannot be payable.

#Contract = #sol<ContractKind Contract>
#Library = #sol<ContractKind Library>
#Default = #sol<RevertStrings Default>
#Fallback = #sol<FunctionKind Fallback>
#Receive = #sol<FunctionKind Receive>
#NonPayable = #sol<StateMutability NonPayable>
#Payable = #sol<StateMutability Payable>
#Pure = #sol<StateMutability Pure>
#Osaka = #sol<EvmVersion Osaka>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
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
  } {kind = #Contract}
  // A payable function among them: the test stays in the non-payable case.
  sol.contract @Mixed {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @g() attributes {orig_fn_type = () -> (), selector = 2 : i32, state_mutability = #Payable} {
      sol.return
    }
  } {kind = #Contract}
  // A payable fallback behind the switch's default: the tests stay in the
  // cases.
  sol.contract @PayableFallback {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @fallback() attributes {kind = #Fallback, orig_fn_type = () -> (), state_mutability = #Payable} {
      sol.return
    }
  } {kind = #Contract}
  // A non-payable fallback keeps its own test: it is also reached with less
  // than four bytes of calldata, below the hoisted test.
  sol.contract @NonPayableFallback {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @fallback() attributes {kind = #Fallback, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract}
  sol.contract @Lib {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #Pure} {
      sol.return
    }
  } {kind = #Library}
}

// CHECK-LABEL: yul.object @AllNonPayable_deployed {
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
// CHECK:         yul.func @receive

// CHECK-LABEL: yul.object @Mixed_deployed {
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.switch
// CHECK:         case 1 {
// CHECK:         yul.callvalue
// CHECK:         yul.func_call @f()
// CHECK:         case 2 {
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func_call @g()
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func @g

// CHECK-LABEL: yul.object @PayableFallback_deployed {
// CHECK-NOT:     yul.callvalue
// CHECK:         case 1 {
// CHECK:         yul.callvalue
// CHECK:         yul.func_call @f()
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func_call @fallback()
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func @fallback

// CHECK-LABEL: yul.object @NonPayableFallback_deployed {
// CHECK:         yul.calldatasize
// CHECK:         yul.callvalue
// CHECK:         yul.switch
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func_call @f()
// CHECK:         yul.callvalue
// CHECK:         yul.func_call @fallback()

// CHECK-LABEL: yul.object @Lib_deployed {
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func_call @f()
// CHECK-NOT:     yul.callvalue
// CHECK:         yul.func @f
