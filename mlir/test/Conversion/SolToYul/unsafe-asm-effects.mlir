// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// An inline assembly body marks its function unsafe_asm iff it holds an op
// with a memory effect. Assigning an externally referenced solidity memory
// variable counts as one.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>

// CHECK-LABEL: yul.object @Mload_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Mload {
    sol.func @f() attributes {id = 5 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %0 = yul.mload %c0_i256
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Mstore_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Mstore {
    sol.func @f() attributes {id = 11 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
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

// CHECK-LABEL: yul.object @Mstore8_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Mstore8 {
    sol.func @f() attributes {id = 17 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.mstore8 %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Mcopy_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Mcopy {
    sol.func @f() attributes {id = 23 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        yul.mcopy %c0_i256, %c0_i256_0, %c0_i256_1
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Msize_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Msize {
    sol.func @f() attributes {id = 29 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %0 = yul.msize
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @CallDataCopy_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @CallDataCopy {
    sol.func @f() attributes {id = 35 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        yul.calldatacopy %c0_i256, %c0_i256_0, %c0_i256_1
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @CodeCopy_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @CodeCopy {
    sol.func @f() attributes {id = 41 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        yul.codecopy %c0_i256, %c0_i256_0, %c0_i256_1
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @ExtCodeCopy_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @ExtCodeCopy {
    sol.func @f() attributes {id = 47 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        %c0_i256_2 = yul.constant 0
        yul.extcodecopy %c0_i256, %c0_i256_0, %c0_i256_1, %c0_i256_2
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @ReturnDataCopy_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @ReturnDataCopy {
    sol.func @f() attributes {id = 53 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        yul.returndatacopy %c0_i256, %c0_i256_0, %c0_i256_1
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Keccak256_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Keccak256 {
    sol.func @f() attributes {id = 59 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %0 = yul.keccak256 %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Call_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Call {
    sol.func @f() attributes {id = 65 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        %c0_i256_2 = yul.constant 0
        %c0_i256_3 = yul.constant 0
        %c0_i256_4 = yul.constant 0
        %c0_i256_5 = yul.constant 0
        %0 = yul.call %c0_i256, %c0_i256_0, %c0_i256_1, %c0_i256_2, %c0_i256_3, %c0_i256_4, %c0_i256_5
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @CallCode_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @CallCode {
    sol.func @f() attributes {id = 71 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        %c0_i256_2 = yul.constant 0
        %c0_i256_3 = yul.constant 0
        %c0_i256_4 = yul.constant 0
        %c0_i256_5 = yul.constant 0
        %0 = yul.callcode %c0_i256, %c0_i256_0, %c0_i256_1, %c0_i256_2, %c0_i256_3, %c0_i256_4, %c0_i256_5
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @StaticCall_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @StaticCall {
    sol.func @f() attributes {id = 77 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        %c0_i256_2 = yul.constant 0
        %c0_i256_3 = yul.constant 0
        %c0_i256_4 = yul.constant 0
        %0 = yul.static_call %c0_i256, %c0_i256_0, %c0_i256_1, %c0_i256_2, %c0_i256_3, %c0_i256_4
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @DelegateCall_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @DelegateCall {
    sol.func @f() attributes {id = 83 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        %c0_i256_2 = yul.constant 0
        %c0_i256_3 = yul.constant 0
        %c0_i256_4 = yul.constant 0
        %0 = yul.delegate_call %c0_i256, %c0_i256_0, %c0_i256_1, %c0_i256_2, %c0_i256_3, %c0_i256_4
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Return_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Return {
    sol.func @f() attributes {id = 89 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.return %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Revert_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Revert {
    sol.func @f() attributes {id = 95 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.revert %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Create_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Create {
    sol.func @f() attributes {id = 101 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        %0 = yul.create %c0_i256, %c0_i256_0, %c0_i256_1
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Create2_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Create2 {
    sol.func @f() attributes {id = 107 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        %c0_i256_2 = yul.constant 0
        %0 = yul.create2 %c0_i256, %c0_i256_0, %c0_i256_1, %c0_i256_2
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Log0_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Log0 {
    sol.func @f() attributes {id = 113 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.log %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Log1_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @Log1 {
    sol.func @f() attributes {id = 119 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        yul.log %c0_i256, %c0_i256_0 topics(%c0_i256_1)
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @YulFnCalled_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @YulFnCalled {
    sol.func @f() attributes {id = 125 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        yul.func @g : (i256) -> () {
        ^bb0(%arg0: i256):
          %0 = yul.alloca : !yul.ptr
          yul.store %arg0, %0 : i256, !yul.ptr
          %1 = yul.load %0 : !yul.ptr -> i256
          %2 = yul.load %0 : !yul.ptr -> i256
          yul.mstore %1, %2
          yul.func_return
        }
        %c0_i256 = yul.constant 0
        yul.func_call @g(%c0_i256) : (i256) -> ()
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @YulFnUncalled_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @YulFnUncalled {
    sol.func @f() attributes {id = 131 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        yul.func @g : (i256) -> () {
        ^bb0(%arg0: i256):
          %0 = yul.alloca : !yul.ptr
          yul.store %arg0, %0 : i256, !yul.ptr
          %1 = yul.load %0 : !yul.ptr -> i256
          %2 = yul.load %0 : !yul.ptr -> i256
          yul.mstore %1, %2
          yul.func_return
        }
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @MemoryLvalue_deployed {
// CHECK:         } {{{.*}}unsafe_asm}
module {
  sol.contract @MemoryLvalue {
    sol.func @f() attributes {id = 143 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      %0 = sol.alloca : !sol.ptr<!sol.array<? x ui256, Memory>, Stack>
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %2 = sol.yul_ptr_cast %0 : !sol.ptr<!sol.array<? x ui256, Memory>, Stack> -> !yul.ptr
        yul.store %c0_i256, %2 : i256, !yul.ptr
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @MemoryRvalue_deployed {
// CHECK-NOT:     unsafe_asm
module {
  sol.contract @MemoryRvalue {
    sol.func @f() attributes {id = 146 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      %0 = sol.alloca : !sol.ptr<!sol.array<? x ui256, Memory>, Stack>
      sol.inline_asm {
        %2 = sol.yul_ptr_cast %0 : !sol.ptr<!sol.array<? x ui256, Memory>, Stack> -> !yul.ptr
        %3 = yul.load %2 : !yul.ptr -> i256
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @SLoad_deployed {
// CHECK-NOT:     unsafe_asm
module {
  sol.contract @SLoad {
    sol.func @f() attributes {id = 149 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %0 = yul.sload %c0_i256
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @SStore_deployed {
// CHECK-NOT:     unsafe_asm
module {
  sol.contract @SStore {
    sol.func @f() attributes {id = 155 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.sstore %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @TLoad_deployed {
// CHECK-NOT:     unsafe_asm
module {
  sol.contract @TLoad {
    sol.func @f() attributes {id = 161 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %0 = yul.tload %c0_i256
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @TStore_deployed {
// CHECK-NOT:     unsafe_asm
module {
  sol.contract @TStore {
    sol.func @f() attributes {id = 167 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.tstore %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @CallDataLoad_deployed {
// CHECK-NOT:     unsafe_asm
module {
  sol.contract @CallDataLoad {
    sol.func @f() attributes {id = 173 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %0 = yul.calldataload %c0_i256
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Caller_deployed {
// CHECK-NOT:     unsafe_asm
module {
  sol.contract @Caller {
    sol.func @f() attributes {id = 179 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %0 = yul.caller
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @Add_deployed {
// CHECK-NOT:     unsafe_asm
module {
  sol.contract @Add {
    sol.func @f() attributes {id = 185 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c1_i256 = yul.constant 1
        %c2_i256 = yul.constant 2
        %0 = yul.add %c1_i256, %c2_i256
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @SelfDestruct_deployed {
// CHECK-NOT:     unsafe_asm
module {
  sol.contract @SelfDestruct {
    sol.func @f() attributes {id = 191 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        yul.selfdestruct %c0_i256
      }
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @StackLvalue_deployed {
// CHECK-NOT:     unsafe_asm
module {
  sol.contract @StackLvalue {
    sol.func @f() -> ui256 attributes {id = 205 : i64, orig_fn_type = () -> ui256, selector = 638722032 : i32, state_mutability = #NonPayable} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      %c0_ui256 = sol.constant 0 : ui256
      sol.store %c0_ui256, %0 : ui256, !sol.ptr<ui256, Stack>
      sol.inline_asm {
        %c1_i256 = yul.constant 1
        %2 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
        yul.store %c1_i256, %2 : i256, !yul.ptr
      }
      %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      sol.return %1 : ui256
    }
  } {kind = #Contract, runtime}
}
