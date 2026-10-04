// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Assembly functions are hoisted to object scope; same-named ones from
// different blocks are uniqued and their calls retargeted.

// CHECK-LABEL: yul.object @C {
// CHECK-LABEL: yul.func @C : () -> ()
// CHECK:         %[[C41:.*]] = yul.constant 41
// CHECK:         %[[V:.*]] = yul.func_call @cf(%[[C41]]) : (i256) -> i256
// CHECK:         yul.sstore %{{.*}}, %[[V]]

// CHECK-LABEL: yul.func @cf : (i256) -> i256
// CHECK:         yul.add

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    sol.func @C() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.inline_asm {
        yul.func @cf : (i256) -> i256 {
        ^bb0(%arg0: i256):
          %c1_i256 = yul.constant 1
          %1 = yul.add %arg0, %c1_i256
          yul.func_return %1 : i256
        }
        %c0_i256 = yul.constant 0
        %c41_i256 = yul.constant 41
        %0 = yul.func_call @cf(%c41_i256) : (i256) -> i256
        yul.sstore %c0_i256, %0
      }
      sol.return
    }
  } {kind = #Contract}
}

// -----

// CHECK-LABEL: yul.object @C_deployed {
// CHECK-LABEL: yul.func @h : () -> ()
// CHECK:         yul.func_call @g_0(
// CHECK-LABEL: yul.func @f : () -> ()
// CHECK:         yul.func_call @g(

// CHECK-LABEL: yul.func @g : (i256) -> i256
// CHECK:         yul.mul %{{.*}}, %c2_i256
// CHECK-LABEL: yul.func @g_0 : (i256) -> i256
// CHECK:         yul.mul %{{.*}}, %c3_i256

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    sol.func @f() attributes {state_mutability = #NonPayable} {
      sol.inline_asm {
        yul.func @g : (i256) -> i256 {
        ^bb0(%arg0: i256):
          %c2_i256 = yul.constant 2
          %1 = yul.mul %arg0, %c2_i256
          yul.func_return %1 : i256
        }
        %c0_i256 = yul.constant 0
        %0 = yul.func_call @g(%c0_i256) : (i256) -> i256
        yul.sstore %c0_i256, %0
      }
      sol.return
    }
    sol.func @h() attributes {state_mutability = #NonPayable} {
      sol.inline_asm {
        yul.func @g : (i256) -> i256 {
        ^bb0(%arg0: i256):
          %c3_i256 = yul.constant 3
          %1 = yul.mul %arg0, %c3_i256
          yul.func_return %1 : i256
        }
        %c0_i256 = yul.constant 0
        %0 = yul.func_call @g(%c0_i256) : (i256) -> i256
        yul.sstore %c0_i256, %0
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}
