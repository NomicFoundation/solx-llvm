// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// The deployed library rejects non-delegate calls to state-mutating public
// functions by comparing its deploy address against the current address.
// CHECK-LABEL: yul.object @L {
// CHECK:         %[[ADDR:.*]] = yul.address
// CHECK:         yul.setimmutable %{{.*}}, "library_deploy_address", %[[ADDR]]

#Library = #sol<ContractKind Library>
module {
  sol.contract @L {
  } {kind = #Library}
}

// -----

// CHECK-LABEL: yul.object @L_deployed {
// CHECK:         %[[DEP:.*]] = yul.loadimmutable "library_deploy_address"
// CHECK:         %[[CUR:.*]] = yul.address
// CHECK:         %[[DIRECT:.*]] = yul.cmp eq, %[[DEP]], %[[CUR]]
// CHECK:         case 3827312202 {
// CHECK:           yul.if %[[DIRECT]] {
// CHECK:             yul.revert
// CHECK:           yul.func_call @g(

#Library = #sol<ContractKind Library>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @L {
    sol.func @g(%arg0: ui256) -> ui256 attributes {orig_fn_type = (ui256) -> ui256, selector = -467655094 : i32, state_mutability = #NonPayable} {
      sol.return %arg0 : ui256
    }
  } {kind = #Library, runtime}
}

// -----

// A public library function is reached by delegatecall to the linked address.
// CHECK-LABEL: yul.func @h : (i256) -> i256
// CHECK:         %[[SEL:.*]] = yul.constant 3827312202
// CHECK:         %[[GAS:.*]] = yul.gas
// CHECK:         %[[LIB:.*]] = yul.linkersymbol "library.sol:L"
// CHECK:         %[[LIBA:.*]] = yul.and %[[LIB]], %{{.*}}
// CHECK:         %[[C224:.*]] = yul.constant 224
// CHECK:         yul.arith_shl %[[SEL]], %[[C224]]
// CHECK:         %[[OK:.*]] = yul.delegate_call %[[GAS]], %[[LIBA]], %{{.*}}, %{{.*}}, %{{.*}}, %{{.*}}
// CHECK:         yul.cmp eq, %[[OK]], %{{.*}}

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    sol.func @h(%arg0: ui256) -> ui256 attributes {state_mutability = #NonPayable} {
      %c3827312202_ui256 = sol.constant 3827312202 : ui256
      %0 = sol.gasleft : ui256
      %c0_ui256 = sol.constant 0 : ui256
      %1 = sol.lib_addr "library.sol:L" : !sol.address
      %status, %outs = sol.ext_call "g"(%arg0) at %1 gas %0 value %c0_ui256 selector %c3827312202_ui256 {callee_type = (ui256) -> ui256, delegate_call, library_call} : !sol.address, (ui256) -> (i1, ui256)
      sol.return %outs : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
