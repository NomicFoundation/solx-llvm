// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// An inline assembly body marks its function unsafe_asm iff it holds an op
// with a memory effect. Assigning an externally referenced solidity memory
// variable counts as one.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
module {
  // CHECK-LABEL: yul.object @Mload {
  // CHECK:         yul.object @Mload_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Mload {
    sol.func @Mload() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 5 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %0 = yul.mload %c0_i256
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Mstore {
  // CHECK:         yul.object @Mstore_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Mstore {
    sol.func @Mstore() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 11 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.mstore %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Mstore8 {
  // CHECK:         yul.object @Mstore8_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Mstore8 {
    sol.func @Mstore8() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 17 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.mstore8 %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Mcopy {
  // CHECK:         yul.object @Mcopy_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Mcopy {
    sol.func @Mcopy() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 23 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        yul.mcopy %c0_i256, %c0_i256_0, %c0_i256_1
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Msize {
  // CHECK:         yul.object @Msize_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Msize {
    sol.func @Msize() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 29 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %0 = yul.msize
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @CallDataCopy {
  // CHECK:         yul.object @CallDataCopy_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @CallDataCopy {
    sol.func @CallDataCopy() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 35 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        yul.calldatacopy %c0_i256, %c0_i256_0, %c0_i256_1
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @CodeCopy {
  // CHECK:         yul.object @CodeCopy_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @CodeCopy {
    sol.func @CodeCopy() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 41 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        yul.codecopy %c0_i256, %c0_i256_0, %c0_i256_1
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @ExtCodeCopy {
  // CHECK:         yul.object @ExtCodeCopy_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @ExtCodeCopy {
    sol.func @ExtCodeCopy() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
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
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @ReturnDataCopy {
  // CHECK:         yul.object @ReturnDataCopy_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @ReturnDataCopy {
    sol.func @ReturnDataCopy() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 53 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        yul.returndatacopy %c0_i256, %c0_i256_0, %c0_i256_1
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Keccak256 {
  // CHECK:         yul.object @Keccak256_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Keccak256 {
    sol.func @Keccak256() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 59 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %0 = yul.keccak256 %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Call {
  // CHECK:         yul.object @Call_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Call {
    sol.func @Call() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
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
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @CallCode {
  // CHECK:         yul.object @CallCode_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @CallCode {
    sol.func @CallCode() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
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
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @StaticCall {
  // CHECK:         yul.object @StaticCall_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @StaticCall {
    sol.func @StaticCall() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
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
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @DelegateCall {
  // CHECK:         yul.object @DelegateCall_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @DelegateCall {
    sol.func @DelegateCall() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
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
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Return {
  // CHECK:         yul.object @Return_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Return {
    sol.func @Return() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 89 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.return %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Revert {
  // CHECK:         yul.object @Revert_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Revert {
    sol.func @Revert() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 95 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.revert %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Create {
  // CHECK:         yul.object @Create_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Create {
    sol.func @Create() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 101 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        %0 = yul.create %c0_i256, %c0_i256_0, %c0_i256_1
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Create2 {
  // CHECK:         yul.object @Create2_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Create2 {
    sol.func @Create2() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
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
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Log0 {
  // CHECK:         yul.object @Log0_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Log0 {
    sol.func @Log0() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 113 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.log %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Log1 {
  // CHECK:         yul.object @Log1_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @Log1 {
    sol.func @Log1() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 119 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        %c0_i256_1 = yul.constant 0
        yul.log %c0_i256, %c0_i256_0 topics(%c0_i256_1)
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @YulFnCalled {
  // CHECK:         yul.object @YulFnCalled_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @YulFnCalled {
    sol.func @YulFnCalled() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
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
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @YulFnUncalled {
  // CHECK:         yul.object @YulFnUncalled_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @YulFnUncalled {
    sol.func @YulFnUncalled() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
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
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @MemoryLvalue {
  // CHECK:         yul.object @MemoryLvalue_deployed {
  // CHECK:         } {{{.*}}unsafe_asm}
  sol.contract @MemoryLvalue {
    sol.func @MemoryLvalue() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 143 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      %0 = sol.alloca : !sol.ptr<!sol.array<? x ui256, Memory>, Stack>
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %2 = sol.yul_ptr_cast %0 : !sol.ptr<!sol.array<? x ui256, Memory>, Stack> -> !yul.ptr
        yul.store %c0_i256, %2 : i256, !yul.ptr
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @MemoryRvalue {
  // CHECK-NOT:     unsafe_asm
  sol.contract @MemoryRvalue {
    sol.func @MemoryRvalue() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 146 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      %0 = sol.alloca : !sol.ptr<!sol.array<? x ui256, Memory>, Stack>
      sol.inline_asm {
        %2 = sol.yul_ptr_cast %0 : !sol.ptr<!sol.array<? x ui256, Memory>, Stack> -> !yul.ptr
        %3 = yul.load %2 : !yul.ptr -> i256
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @SLoad {
  // CHECK-NOT:     unsafe_asm
  sol.contract @SLoad {
    sol.func @SLoad() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 149 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %0 = yul.sload %c0_i256
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @SStore {
  // CHECK-NOT:     unsafe_asm
  sol.contract @SStore {
    sol.func @SStore() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 155 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.sstore %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @TLoad {
  // CHECK-NOT:     unsafe_asm
  sol.contract @TLoad {
    sol.func @TLoad() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 161 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %0 = yul.tload %c0_i256
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @TStore {
  // CHECK-NOT:     unsafe_asm
  sol.contract @TStore {
    sol.func @TStore() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 167 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %c0_i256_0 = yul.constant 0
        yul.tstore %c0_i256, %c0_i256_0
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @CallDataLoad {
  // CHECK-NOT:     unsafe_asm
  sol.contract @CallDataLoad {
    sol.func @CallDataLoad() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 173 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        %0 = yul.calldataload %c0_i256
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Caller {
  // CHECK-NOT:     unsafe_asm
  sol.contract @Caller {
    sol.func @Caller() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 179 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %0 = yul.caller
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @Add {
  // CHECK-NOT:     unsafe_asm
  sol.contract @Add {
    sol.func @Add() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 185 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c1_i256 = yul.constant 1
        %c2_i256 = yul.constant 2
        %0 = yul.add %c1_i256, %c2_i256
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @SelfDestruct {
  // CHECK-NOT:     unsafe_asm
  sol.contract @SelfDestruct {
    sol.func @SelfDestruct() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @f() attributes {id = 191 : i64, orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #NonPayable} {
      sol.inline_asm {
        %c0_i256 = yul.constant 0
        yul.selfdestruct %c0_i256
      }
      sol.return
    }
  } {kind = #Contract}
  // CHECK-LABEL: yul.object @StackLvalue {
  // CHECK-NOT:     unsafe_asm
  sol.contract @StackLvalue {
    sol.func @StackLvalue() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
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
  } {kind = #Contract}
}
