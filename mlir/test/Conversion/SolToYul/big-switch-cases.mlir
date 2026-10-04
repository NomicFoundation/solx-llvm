// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Case values wider than 64 bits survive the inline asm lowering.
// CHECK-LABEL: yul.func @f : () -> ()
// CHECK:         %[[X:.*]] = yul.calldataload
// CHECK-NEXT:    yul.switch %[[X]] : i256
// CHECK-NEXT:    case 1 {
// CHECK:         case 100000000000000000000 {
// CHECK:         case 1000000000000000000000000000000 {
// CHECK:         default {

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    sol.func @f() attributes {state_mutability = #Pure} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %0 = yul.calldataload %c0_i256
        yul.switch %0 : i256
        case 1 {
          yul.yield
        }
        case 100000000000000000000 {
          yul.yield
        }
        case 1000000000000000000000000000000 {
          yul.yield
        }
        default {
          yul.yield
        }
      }
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
