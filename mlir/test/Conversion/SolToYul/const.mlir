// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @ui8 : () -> i256
    // CHECK:         yul.constant 42{{$}}
    // CHECK:         yul.func_return %{{.*}} : i256
    sol.func @ui8() -> ui256 attributes {state_mutability = #Pure} {
      %c42_ui8 = sol.constant 42 : ui8
      %0 = sol.cast %c42_ui8 : ui8 to ui256
      sol.return %0 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // 2^255 keeps its bit pattern; Yul constants print signed.
    // CHECK-LABEL: yul.func @ui256 : () -> i256
    // CHECK:         %[[C:.*]] = yul.constant -57896044618658097711785492504343953926634992332820282019728792003956564819968{{$}}
    // CHECK:         yul.func_return %[[C]] : i256
    sol.func @ui256() -> ui256 attributes {state_mutability = #Pure} {
      %c-57896044618658097711785492504343953926634992332820282019728792003956564819968_ui256 = sol.constant 57896044618658097711785492504343953926634992332820282019728792003956564819968 : ui256
      sol.return %c-57896044618658097711785492504343953926634992332820282019728792003956564819968_ui256 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @default_fn : () -> i256
    // CHECK:         %[[Z:.*]] = yul.constant 0{{$}}
    // CHECK:         yul.func_return %[[Z]] : i256
    sol.func @default_fn() -> !sol.func_ref<() -> ()> attributes {state_mutability = #Pure} {
      %0 = sol.default_func_constant : <() -> ()>
      sol.return %0 : !sol.func_ref<() -> ()>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
