// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// bytes20 is cleaned to its top 20 bytes and the uint8 amount to 8 bits
// before the shift.

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @l : (i256, i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[X:.*]]: i256, %[[Y:.*]]: i256):
    // CHECK:         %[[XC:.*]] = yul.and %[[X]], %c-79228162514264337593543950336_i256
    // CHECK:         %[[YC:.*]] = yul.and %[[Y]], %c255_i256
    // CHECK:         %[[V:.*]] = yul.shl %[[YC]], %[[XC]]
    // CHECK:         yul.func_return %[[V]] : i256
    sol.func @l(%arg0: !sol.fixedbytes<20>, %arg1: ui8) -> !sol.fixedbytes<20> attributes {state_mutability = #Pure} {
      %0 = sol.shl %arg0, %arg1 : !sol.fixedbytes<20>, ui8
      sol.return %0 : !sol.fixedbytes<20>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @r : (i256, i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[X:.*]]: i256, %[[Y:.*]]: i256):
    // CHECK:         %[[XC:.*]] = yul.and %[[X]], %c-79228162514264337593543950336_i256
    // CHECK:         %[[YC:.*]] = yul.and %[[Y]], %c255_i256
    // CHECK:         %[[V:.*]] = yul.shr %[[YC]], %[[XC]]
    // CHECK:         yul.func_return %[[V]] : i256
    sol.func @r(%arg0: !sol.fixedbytes<20>, %arg1: ui8) -> !sol.fixedbytes<20> attributes {state_mutability = #Pure} {
      %0 = sol.shr %arg0, %arg1 : !sol.fixedbytes<20>, ui8
      sol.return %0 : !sol.fixedbytes<20>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
