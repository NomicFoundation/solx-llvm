// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// The uint8 is cleaned before the bytes32 cast, which shifts by 0.
// CHECK-LABEL: yul.func @g : (i256) -> i256
// CHECK-NEXT:  ^bb0(%[[V:.*]]: i256):
// CHECK:         %[[MASK:.*]] = yul.constant 255
// CHECK:         %[[C:.*]] = yul.and %[[V]], %[[MASK]]
// CHECK:         %[[SH:.*]] = yul.constant 0
// CHECK:         %[[R:.*]] = yul.arith_shl %[[C]], %[[SH]]
// CHECK:         yul.func_return %[[R]] : i256

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    sol.func @g(%arg0: ui8) -> !sol.fixedbytes<32> attributes {state_mutability = #Pure} {
      %0 = sol.cast %arg0 : ui8 to ui256
      %1 = sol.bytes_cast %0 : ui256 to !sol.fixedbytes<32>
      sol.return %1 : !sol.fixedbytes<32>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
