// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @keccak
    // CHECK:         ^bb0(%[[PTR:.*]]: i256):
    // CHECK:         %[[LEN:.*]] = yul.mload %[[PTR]]
    // CHECK:         %[[C32:.*]] = yul.constant 32
    // CHECK:         %[[DATA:.*]] = yul.add %[[PTR]], %[[C32]]
    // CHECK:         %[[H:.*]] = yul.keccak256 %[[DATA]], %[[LEN]]
    // CHECK:         yul.func_return %[[H]]
    sol.func @keccak(%arg0: !sol.string<Memory>) -> !sol.fixedbytes<32> attributes {state_mutability = #Pure} {
      %0 = "sol.keccak256"(%arg0) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
      sol.return %0 : !sol.fixedbytes<32>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @sha
    // CHECK-NEXT:    ^bb0(%[[PTR:.*]]: i256):
    // CHECK:         %[[ZERO:.*]] = yul.constant 0{{$}}
    // CHECK:         %[[OUTSZ:.*]] = yul.constant 32{{$}}
    // CHECK:         %[[LEN:.*]] = yul.mload %[[PTR]]
    // CHECK:         %[[DATA:.*]] = yul.add %[[PTR]], %{{.*}}
    // CHECK:         %[[C2:.*]] = yul.constant 2{{$}}
    // CHECK:         %[[OK:.*]] = yul.static_call %{{.*}}, %[[C2]], %[[DATA]], %[[LEN]], %[[ZERO]], %[[OUTSZ]]
    // CHECK:         yul.cmp eq, %[[OK]], %[[ZERO]]
    // CHECK:         yul.revert
    // CHECK:         %[[H:.*]] = yul.mload %[[ZERO]]
    // CHECK:         yul.func_return %[[H]]
    sol.func @sha(%arg0: !sol.string<Memory>) -> !sol.fixedbytes<32> attributes {state_mutability = #Pure} {
      %0 = "sol.sha256"(%arg0) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
      sol.return %0 : !sol.fixedbytes<32>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // The 20-byte result is right-aligned in the output word.
    // CHECK-LABEL: yul.func @rip
    // CHECK-NEXT:    ^bb0(%[[PTR:.*]]: i256):
    // CHECK:         %[[ZERO:.*]] = yul.constant 0{{$}}
    // CHECK:         %[[OUTSZ:.*]] = yul.constant 32{{$}}
    // CHECK:         %[[LEN:.*]] = yul.mload %[[PTR]]
    // CHECK:         %[[DATA:.*]] = yul.add %[[PTR]], %{{.*}}
    // CHECK:         %[[C3:.*]] = yul.constant 3{{$}}
    // CHECK:         yul.static_call %{{.*}}, %[[C3]], %[[DATA]], %[[LEN]], %[[ZERO]], %[[OUTSZ]]
    // CHECK:         yul.revert
    // CHECK:         %[[W:.*]] = yul.mload %[[ZERO]]
    // CHECK:         %[[C96:.*]] = yul.constant 96
    // CHECK:         %[[H:.*]] = yul.shl %[[C96]], %[[W]]
    // CHECK:         yul.func_return %[[H]]
    sol.func @rip(%arg0: !sol.string<Memory>) -> !sol.fixedbytes<20> attributes {state_mutability = #Pure} {
      %0 = "sol.ripemd160"(%arg0) : (!sol.string<Memory>) -> !sol.fixedbytes<20>
      sol.return %0 : !sol.fixedbytes<20>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // The output word is cleared before the call: a failed recovery writes
    // nothing, and must read back as address(0).
    // CHECK-LABEL: yul.func @recover
    // CHECK-NEXT:    ^bb0(%[[HASH:.*]]: i256, %[[V:.*]]: i256, %[[R:.*]]: i256, %[[S:.*]]: i256):
    // CHECK:         %[[ZERO:.*]] = yul.constant 0{{$}}
    // CHECK:         %[[OUTSZ:.*]] = yul.constant 32{{$}}
    // CHECK:         %[[IN:.*]] = yul.mload
    // CHECK:         %[[INSZ:.*]] = yul.constant 128{{$}}
    // CHECK:         yul.mstore %[[IN]], %[[HASH]]
    // CHECK:         %[[C255:.*]] = yul.constant 255
    // CHECK:         %[[VC:.*]] = yul.and %[[V]], %[[C255]]
    // CHECK:         yul.mstore %{{.*}}, %[[VC]]
    // CHECK:         yul.mstore %{{.*}}, %[[R]]
    // CHECK:         yul.mstore %{{.*}}, %[[S]]
    // CHECK:         yul.mstore %[[ZERO]], %[[ZERO]]
    // CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
    // CHECK:         %[[OK:.*]] = yul.static_call %{{.*}}, %[[C1]], %[[IN]], %[[INSZ]], %[[ZERO]], %[[OUTSZ]]
    // CHECK:         yul.cmp eq, %[[OK]], %[[ZERO]]
    // CHECK:         yul.revert
    // CHECK:         %[[A:.*]] = yul.mload %[[ZERO]]
    // CHECK:         yul.func_return %[[A]]
    sol.func @recover(%arg0: !sol.fixedbytes<32>, %arg1: ui8, %arg2: !sol.fixedbytes<32>, %arg3: !sol.fixedbytes<32>) -> !sol.address attributes {state_mutability = #Pure} {
      %0 = "sol.ecrecover"(%arg0, %arg1, %arg2, %arg3) : (!sol.fixedbytes<32>, ui8, !sol.fixedbytes<32>, !sol.fixedbytes<32>) -> !sol.address
      sol.return %0 : !sol.address
    }
  } {kind = #Contract, runtime}
}
