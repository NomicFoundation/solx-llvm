// RUN: mlir-opt %s --split-input-file --symbol-dce --convert-sol-to-yul --symbol-dce --convert-yul-to-std | FileCheck %s

// A module keeps its memoryguard iff no function with unsafe assembly is
// left in it once symbol-dce has dropped what its entry points do not
// reach. Calls and function pointers keep a function alive alike. A
// memory_safe block is trusted, not checked.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>

// CHECK-LABEL: module @CtorOnly {
// CHECK:         func.func @__entry
// CHECK-NEXT:      arith.constant 128
// CHECK-LABEL: module @CtorOnly_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
sol.contract @CtorOnly {
  sol.func @_5() attributes {id = 5 : i64, kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
    sol.inline_asm {
      %c0_i256 = yul.constant 0
      %c0_i256_0 = yul.constant 0
      yul.mstore %c0_i256, %c0_i256_0
    }
    sol.return
  }
  sol.func @f() attributes {id = 9 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
    sol.return
  }
} {kind = #Contract}

// -----

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>

// CHECK-LABEL: module @RuntimeOnly {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
// CHECK-LABEL: module @RuntimeOnly_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      arith.constant 128
sol.contract @RuntimeOnly {
  sol.func @RuntimeOnly() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
    sol.return
  }
  sol.func @f() attributes {id = 15 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
    sol.inline_asm {
      %c0_i256 = yul.constant 0
      %c0_i256_0 = yul.constant 0
      yul.mstore %c0_i256, %c0_i256_0
    }
    sol.return
  }
} {kind = #Contract}

// -----

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>

// CHECK-LABEL: module @Shared {
// CHECK:         func.func @__entry
// CHECK-NEXT:      arith.constant 128
// CHECK-LABEL: module @Shared_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      arith.constant 128
sol.contract @Shared {
  sol.func @_28() attributes {id = 28 : i64, kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
    sol.call @g() : () -> ()
    sol.return
  }
  sol.func private @g() attributes {id = 21 : i64, state_mutability = #NonPayable} {
    sol.inline_asm {
      %c0_i256 = yul.constant 0
      %c0_i256_0 = yul.constant 0
      yul.mstore %c0_i256, %c0_i256_0
    }
    sol.return
  }
  sol.func @f() attributes {id = 35 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
    sol.call @g() : () -> ()
    sol.return
  }
} {kind = #Contract}

// -----

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>

// CHECK-LABEL: module @Dead {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
// CHECK-LABEL: module @Dead_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
sol.contract @Dead {
  sol.func @Dead() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
    sol.return
  }
  sol.func private @unused() attributes {id = 41 : i64, state_mutability = #NonPayable} {
    sol.inline_asm {
      %c0_i256 = yul.constant 0
      %c0_i256_0 = yul.constant 0
      yul.mstore %c0_i256, %c0_i256_0
    }
    sol.return
  }
  sol.func @f() attributes {id = 45 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
    sol.return
  }
} {kind = #Contract}

// -----

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>

// CHECK-LABEL: module @FuncPtr {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
// CHECK-LABEL: module @FuncPtr_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      arith.constant 128
sol.contract @FuncPtr {
  sol.func @FuncPtr() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
    sol.return
  }
  sol.func private @g() attributes {id = 51 : i64, state_mutability = #NonPayable} {
    sol.inline_asm {
      %c0_i256 = yul.constant 0
      %c0_i256_0 = yul.constant 0
      yul.mstore %c0_i256, %c0_i256_0
    }
    sol.return
  }
  sol.func @f() attributes {id = 64 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
    %0 = sol.func_constant @g : !sol.func_ref<() -> ()>
    %1 = sol.alloca : !sol.ptr<!sol.func_ref<() -> ()>, Stack>
    sol.store %0, %1 : !sol.func_ref<() -> ()>, !sol.ptr<!sol.func_ref<() -> ()>, Stack>
    %2 = sol.load %1 : !sol.ptr<!sol.func_ref<() -> ()>, Stack>, !sol.func_ref<() -> ()>
    sol.icall %2() : !sol.func_ref<() -> ()>, () -> ()
    sol.return
  }
} {kind = #Contract}

// -----

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>

// CHECK-LABEL: module @MemorySafe {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
// CHECK-LABEL: module @MemorySafe_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
sol.contract @MemorySafe {
  sol.func @MemorySafe() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
    sol.return
  }
  sol.func @f() attributes {id = 70 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
    sol.inline_asm attributes {memory_safe} {
      %c0_i256 = yul.constant 0
      %c0_i256_0 = yul.constant 0
      yul.mstore %c0_i256, %c0_i256_0
    }
    sol.return
  }
} {kind = #Contract}

// -----

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>

// CHECK-LABEL: module @NatSpecMemorySafe {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
// CHECK-LABEL: module @NatSpecMemorySafe_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
sol.contract @NatSpecMemorySafe {
  sol.func @NatSpecMemorySafe() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
    sol.return
  }
  sol.func @f() attributes {id = 76 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
    sol.inline_asm attributes {memory_safe} {
      %c0_i256 = yul.constant 0
      %c0_i256_0 = yul.constant 0
      yul.mstore %c0_i256, %c0_i256_0
    }
    sol.return
  }
} {kind = #Contract}

// -----

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>

// CHECK-LABEL: module @Mixed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
// CHECK-LABEL: module @Mixed_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      arith.constant 128
sol.contract @Mixed {
  sol.func @Mixed() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
    sol.return
  }
  sol.func @f() attributes {id = 83 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
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
} {kind = #Contract}

// -----

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>

// CHECK-LABEL: module @SafeCallsUnsafe {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
// CHECK-LABEL: module @SafeCallsUnsafe_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      arith.constant 128
sol.contract @SafeCallsUnsafe {
  sol.func @SafeCallsUnsafe() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
    sol.return
  }
  sol.func private @g() attributes {id = 89 : i64, state_mutability = #NonPayable} {
    sol.inline_asm {
      %c0_i256 = yul.constant 0
      %c0_i256_0 = yul.constant 0
      yul.mstore %c0_i256, %c0_i256_0
    }
    sol.return
  }
  sol.func @f() attributes {id = 97 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
    sol.inline_asm attributes {memory_safe} {
      %c0_i256 = yul.constant 0
      %c0_i256_0 = yul.constant 0
      yul.mstore %c0_i256, %c0_i256_0
    }
    sol.call @g() : () -> ()
    sol.return
  }
} {kind = #Contract}

// -----

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>

// The helper is cloned into the creation object for the constructor; its
// runtime copy has no caller and goes.
// CHECK-LABEL: module @CtorHelper {
// CHECK:         func.func @__entry
// CHECK-NEXT:      arith.constant 128
// CHECK-LABEL: module @CtorHelper_deployed {
// CHECK:         func.func @__entry
// CHECK-NEXT:      "evm.memoryguard"
sol.contract @CtorHelper {
  sol.func @_103() attributes {id = 103 : i64, kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
    sol.call @g() : () -> ()
    sol.return
  }
  sol.func private @g() attributes {id = 107 : i64, state_mutability = #NonPayable} {
    sol.inline_asm {
      %c0_i256 = yul.constant 0
      %c0_i256_0 = yul.constant 0
      yul.mstore %c0_i256, %c0_i256_0
    }
    sol.return
  }
  sol.func @f() attributes {id = 111 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
    sol.return
  }
} {kind = #Contract}
