// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// A call without a gas operand forwards all the gas left, read right before
// the call, after the input is encoded. A gas operand is forwarded as given.

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @call :
    // CHECK:       ^bb0(%{{.*}}: i256, %[[X:.*]]: i256, %[[V:.*]]: i256):
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(%[[X]],
    // CHECK:         %[[GAS:.*]] = yul.gas
    // CHECK-NEXT:    yul.call %[[GAS]], %{{.*}}, %[[V]],
    sol.func @call(%a: !sol.address, %x: ui256, %v: ui256) -> ui256 {
      %sel = sol.constant 3017696395 : ui256
      %status, %outs = sol.ext_call "g"(%x) at %a value %v selector %sel {callee_type = (ui256) -> ui256} : !sol.address, (ui256) -> (i1, ui256)
      sol.return %outs : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @staticCall :
    // CHECK:       ^bb0(%{{.*}}: i256, %[[X:.*]]: i256):
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(%[[X]],
    // CHECK:         %[[GAS:.*]] = yul.gas
    // CHECK-NEXT:    yul.static_call %[[GAS]],
    sol.func @staticCall(%a: !sol.address, %x: ui256) -> ui256 {
      %sel = sol.constant 3017696395 : ui256
      %c0 = sol.constant 0 : ui256
      %status, %outs = sol.ext_call "g"(%x) at %a value %c0 selector %sel {callee_type = (ui256) -> ui256, static_call} : !sol.address, (ui256) -> (i1, ui256)
      sol.return %outs : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @libraryCall :
    // CHECK:       ^bb0(%[[X:.*]]: i256):
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(%[[X]],
    // CHECK:         %[[GAS:.*]] = yul.gas
    // CHECK-NEXT:    yul.delegate_call %[[GAS]],
    sol.func @libraryCall(%x: ui256) -> ui256 {
      %sel = sol.constant 3017696395 : ui256
      %c0 = sol.constant 0 : ui256
      %lib = sol.lib_addr "library.sol:L" : !sol.address
      %status, %outs = sol.ext_call "g"(%x) at %lib value %c0 selector %sel {callee_type = (ui256) -> ui256, delegate_call, library_call} : !sol.address, (ui256) -> (i1, ui256)
      sol.return %outs : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @pointerCall :
    // CHECK:       ^bb0(%{{.*}}: i256, %[[X:.*]]: i256, %[[V:.*]]: i256):
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(%[[X]],
    // CHECK:         %[[GAS:.*]] = yul.gas
    // CHECK-NEXT:    yul.call %[[GAS]], %{{.*}}, %[[V]],
    sol.func @pointerCall(%a: !sol.address, %x: ui256, %v: ui256) -> ui256 {
      %f = sol.ext_func_constant %a {selector = -1277270901 : i32} : !sol.address -> !sol.ext_func_ref<(ui256) -> ui256>
      %0:2 = sol.ext_icall %f(%x) value %v : <(ui256) -> ui256>, (ui256) -> (i1, ui256)
      sol.return %0#1 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @bareCall :
    // CHECK:       ^bb0(%{{.*}}: i256, %{{.*}}: i256, %[[V:.*]]: i256):
    // CHECK:         %[[GAS:.*]] = yul.gas
    // CHECK-NEXT:    yul.call %[[GAS]], %{{.*}}, %[[V]],
    sol.func @bareCall(%a: !sol.address, %d: !sol.string<Memory>, %v: ui256) -> i1 {
      %status, %ret = sol.bare_call %a value %v input %d : !sol.address, ui256, !sol.string<Memory> -> i1, !sol.string<Memory>
      sol.return %status : i1
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @bareDelegateCall :
    // CHECK:         %[[GAS:.*]] = yul.gas
    // CHECK-NEXT:    yul.delegate_call %[[GAS]],
    sol.func @bareDelegateCall(%a: !sol.address, %d: !sol.string<Memory>) -> i1 {
      %status, %ret = sol.bare_delegate_call %a input %d : !sol.address, !sol.string<Memory> -> i1, !sol.string<Memory>
      sol.return %status : i1
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @bareStaticCall :
    // CHECK:         %[[GAS:.*]] = yul.gas
    // CHECK-NEXT:    yul.static_call %[[GAS]],
    sol.func @bareStaticCall(%a: !sol.address, %d: !sol.string<Memory>) -> i1 {
      %status, %ret = sol.bare_static_call %a input %d : !sol.address, !sol.string<Memory> -> i1, !sol.string<Memory>
      sol.return %status : i1
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @callGas :
    // CHECK:       ^bb0(%{{.*}}: i256, %{{.*}}: i256, %[[G:.*]]: i256, %{{.*}}: i256):
    // CHECK-NOT:     yul.gas
    // CHECK:         yul.call %[[G]],
    sol.func @callGas(%a: !sol.address, %x: ui256, %g: ui256, %v: ui256) -> ui256 {
      %sel = sol.constant 3017696395 : ui256
      %status, %outs = sol.ext_call "g"(%x) at %a gas %g value %v selector %sel {callee_type = (ui256) -> ui256} : !sol.address, (ui256) -> (i1, ui256)
      sol.return %outs : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @pointerCallGas :
    // CHECK:       ^bb0(%{{.*}}: i256, %{{.*}}: i256, %[[G:.*]]: i256, %{{.*}}: i256):
    // CHECK-NOT:     yul.gas
    // CHECK:         yul.call %[[G]],
    sol.func @pointerCallGas(%a: !sol.address, %x: ui256, %g: ui256, %v: ui256) -> ui256 {
      %f = sol.ext_func_constant %a {selector = -1277270901 : i32} : !sol.address -> !sol.ext_func_ref<(ui256) -> ui256>
      %0:2 = sol.ext_icall %f(%x) gas %g value %v : <(ui256) -> ui256>, (ui256) -> (i1, ui256)
      sol.return %0#1 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @bareCallGas :
    // CHECK:       ^bb0(%{{.*}}: i256, %{{.*}}: i256, %[[G:.*]]: i256, %{{.*}}: i256):
    // CHECK-NOT:     yul.gas
    // CHECK:         yul.call %[[G]],
    sol.func @bareCallGas(%a: !sol.address, %d: !sol.string<Memory>, %g: ui256, %v: ui256) -> i1 {
      %status, %ret = sol.bare_call %a gas %g value %v input %d : !sol.address, ui256, !sol.string<Memory> -> i1, !sol.string<Memory>
      sol.return %status : i1
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
