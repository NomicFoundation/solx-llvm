// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// An asm body ending in a halt leaves the Solidity code after it unreachable,
// so the lowering drops it.

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.func @f : (i256) -> i256 {
// CHECK:         yul.revert
// CHECK-NEXT:  }
module {
  sol.contract @C {
    sol.func @f(%c: i1) -> ui256 attributes {state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        yul.revert %c0_i256, %c0_i256
      }
      %c1 = sol.constant 1 : ui256
      sol.if %c {
        sol.yield
      } else {
      }
      sol.return %c1 : ui256
    }
  } {kind = #Contract, runtime}
}

// -----

// A halt nested in the body's control flow leaves the code after the asm
// reachable, so it stays.

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.func @f : () -> i256 {
// CHECK:         yul.if
// CHECK-NEXT:      %{{.*}} = yul.constant 0
// CHECK-NEXT:      yul.revert
// CHECK-NEXT:    } else {
// CHECK-NEXT:    }
// CHECK-NEXT:    %[[ONE:.*]] = yul.constant 1
// CHECK-NEXT:    yul.func_return %[[ONE]] : i256
module {
  sol.contract @C {
    sol.func @f() -> ui256 attributes {state_mutability = #NonPayable} {
      sol.inline_asm {
        %c1_i256 = yul.constant 1
        yul.if %c1_i256 {
          %c0_i256 = yul.constant 0
          yul.revert %c0_i256, %c0_i256
        } else {
        }
      }
      %c1 = sol.constant 1 : ui256
      sol.return %c1 : ui256
    }
  } {kind = #Contract, runtime}
}
