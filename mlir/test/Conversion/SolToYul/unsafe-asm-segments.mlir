// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul --convert-yul-to-std | FileCheck %s

// A module keeps its memoryguard iff its contract holds no unsafe assembly, so
// the creation and the runtime code are judged apart, and the creation code
// reserves the immutables' memory ahead of its free pointer either way. A
// memory_safe block is trusted, not checked.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: module @CtorOnly {
// CHECK:         func.func @__entry
// CHECK-NEXT:      arith.constant 160
module {
  sol.contract @CtorOnly {
    sol.immutable @x : ui256
    sol.func @_5() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.mstore %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: module @CtorOnly_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
module {
  sol.contract @CtorOnly {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: module @RuntimeOnly_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      arith.constant 128
module {
  sol.contract @RuntimeOnly {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.mstore %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: module @MemorySafe_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
module {
  sol.contract @MemorySafe {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm attributes {memory_safe} {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.mstore %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: module @Mixed_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      arith.constant 128
module {
  sol.contract @Mixed {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm attributes {memory_safe} {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.mstore %c0_i256, %c0_i256_0
      }
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.mstore %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}
