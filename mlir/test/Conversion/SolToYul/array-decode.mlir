// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// uint8[] calldata is decoded into memory element by element, each
// validated against the uint8 mask. The dispatcher decodes the tuple through
// a helper per argument list, which decodes the array through a helper per
// type.
// CHECK:         case 2364674588 {
// CHECK:           %[[MEM:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.array$_dyn_ui8_$_Memory_$(
// CHECK:           yul.func_call @decode(%[[MEM]])
// CHECK-LABEL:   yul.func @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
// CHECK:           %[[LEN:.*]] = yul.calldataload %arg0
// CHECK:           %[[P:.*]] = yul.func_call @__sol.alloc
// CHECK:           yul.mstore %[[P]], %[[LEN]]
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.calldataload
// CHECK:             %[[M:.*]] = yul.constant 255
// CHECK:             %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK:             %[[BAD:.*]] = yul.cmp ne, %[[V]], %[[C]]
// CHECK:             yul.if %[[BAD]] {
// CHECK:             yul.mstore %{{.*}}, %[[C]]
// CHECK:           yul.func_return %[[P]]
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.array$_dyn_ui8_$_Memory_$ : (i256, i256) -> i256
// CHECK:           %[[OFF:.*]] = yul.calldataload %arg0
// CHECK:           %[[TAIL:.*]] = yul.add %arg0, %[[OFF]]
// CHECK:           %[[R:.*]] = yul.func_call @__sol.abi_decode.calldata.memory.array$_dyn_ui8_$_Memory_$(%[[TAIL]], %arg1)
// CHECK:           yul.func_return %[[R]]
module {
  sol.contract @C {
    sol.func @decode(%arg0: !sol.array<? x ui8, Memory>) attributes {orig_fn_type = (!sol.array<? x ui8, Memory>) -> (), selector = -1930292708 : i32, state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// A dynamic calldata array is not copied: its length word must be in bounds,
// the length fit in 64 bits and the elements fit in calldata; the argument is
// the {data, length} pair.
// CHECK:         case 286331153 {
// CHECK:           %[[FP:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.array$_dyn_ui256_$_CallData_$(
// CHECK:           yul.func_call @cdyn(%[[FP]])
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.array$_dyn_ui256_$_CallData_$ : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK-NEXT:    ^bb0(%[[HEAD:.*]]: i256, %[[END:.*]]: i256):
// CHECK:           %[[OFF:.*]] = yul.calldataload %[[HEAD]]
// CHECK:           %[[TAIL:.*]] = yul.add %[[HEAD]], %[[OFF]]
// CHECK:           %[[C31:.*]] = yul.constant 31
// CHECK:           %[[LAST:.*]] = yul.add %[[TAIL]], %[[C31]]
// CHECK:           %[[BADOFF:.*]] = yul.cmp sge, %[[LAST]], %[[END]]
// CHECK:           yul.if %[[BADOFF]] {
// CHECK:           %[[LEN:.*]] = yul.calldataload %[[TAIL]]
// CHECK:           %[[DATA:.*]] = yul.add %[[TAIL]], %{{.*}}
// CHECK:           %[[U64:.*]] = yul.constant 18446744073709551615
// CHECK:           %[[BADLEN:.*]] = yul.cmp ugt, %[[LEN]], %[[U64]]
// CHECK:           yul.if %[[BADLEN]] {
// CHECK:           %[[SPAN:.*]] = yul.mul %[[LEN]], %{{.*}}
// CHECK:           %[[DEND:.*]] = yul.add %[[DATA]], %[[SPAN]]
// CHECK:           %[[BADSPAN:.*]] = yul.cmp ugt, %[[DEND]], %[[END]]
// CHECK:           yul.if %[[BADSPAN]] {
// CHECK-NOT:       yul.for
// CHECK:           %[[FP0:.*]] = llvm.insertvalue %[[DATA]], %{{.*}}[0]
// CHECK:           %[[FP:.*]] = llvm.insertvalue %[[LEN]], %[[FP0]][1]
// CHECK:           yul.func_return %[[FP]]
module {
  sol.contract @C {
    sol.func @cdyn(%arg0: !sol.array<? x ui256, CallData>) attributes {orig_fn_type = (!sol.array<? x ui256, CallData>) -> (), selector = 286331153 : i32, state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// A static calldata array only needs its whole span in calldata; the argument
// is its head address.
// CHECK:         case 572662306 {
// CHECK:           %[[C4:.*]] = yul.constant 4{{$}}
// CHECK:           %[[A:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.array$_2_ui256_$_CallData_$(%[[C4]], %{{.*}})
// CHECK:           yul.func_call @cfix(%[[A]])
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.array$_2_ui256_$_CallData_$ : (i256, i256) -> i256
// CHECK-NEXT:    ^bb0(%[[HEAD:.*]]: i256, %[[END:.*]]: i256):
// CHECK:           yul.sub %[[END]], %[[HEAD]]
// CHECK:           %[[AEND:.*]] = yul.add %[[HEAD]], %{{.*}}
// CHECK:           %[[BADSPAN:.*]] = yul.cmp ugt, %[[AEND]], %[[END]]
// CHECK:           yul.if %[[BADSPAN]] {
// CHECK-NOT:       yul.calldataload
// CHECK:           yul.func_return %[[HEAD]]
module {
  sol.contract @C {
    sol.func @cfix(%arg0: !sol.array<2 x ui256, CallData>) attributes {orig_fn_type = (!sol.array<2 x ui256, CallData>) -> (), selector = 572662306 : i32, state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// Dynamic types are decoded behind an offset (32-byte head); every
// nested string is validated and copied with mcopy.
// CHECK-LABEL: yul.func @__sol.abi_decode.memory.memory.array$_dyn_string$_Memory_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:         yul.for
// CHECK:           yul.cmp sge
// CHECK:           yul.mcopy
// CHECK-NOT:     yul.for
// CHECK:         yul.func_return
// CHECK-LABEL: yul.func @__sol.abi_decode_tuple.memory.array$_dyn_string$_Memory_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:         %[[HEAD:.*]] = yul.constant 32{{$}}
// CHECK:         yul.cmp slt, %{{.*}}, %[[HEAD]]
// CHECK:         yul.func_call @__sol.abi_decode.memory.memory.array$_dyn_string$_Memory_$_$_Memory_$(
// CHECK-LABEL: yul.func @string_dyn : (i256) -> ()
// CHECK:         yul.func_call @__sol.abi_decode_tuple.memory.array$_dyn_string$_Memory_$_$_Memory_$(
// CHECK:         yul.func_return
module {
  sol.contract @C {
    sol.func @string_dyn(%arg0: !sol.string<Memory>) attributes {state_mutability = #Pure} {
      %0 = sol.decode %arg0 : !sol.string<Memory> -> !sol.array<? x !sol.string<Memory>, Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// CHECK-LABEL: yul.func @__sol.abi_decode.memory.memory.array$_2_string$_Memory_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:         yul.for
// CHECK:           yul.mcopy
// CHECK-NOT:     yul.for
// CHECK:         yul.func_return
// CHECK-LABEL: yul.func @__sol.abi_decode_tuple.memory.array$_2_string$_Memory_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:         %[[HEAD:.*]] = yul.constant 32{{$}}
// CHECK:         yul.cmp slt, %{{.*}}, %[[HEAD]]
// CHECK:         yul.func_call @__sol.abi_decode.memory.memory.array$_2_string$_Memory_$_$_Memory_$(
// CHECK-LABEL: yul.func @string_fixed : (i256) -> ()
// CHECK:         yul.func_call @__sol.abi_decode_tuple.memory.array$_2_string$_Memory_$_$_Memory_$(
// CHECK:         yul.func_return
module {
  sol.contract @C {
    sol.func @string_fixed(%arg0: !sol.string<Memory>) attributes {state_mutability = #Pure} {
      %0 = sol.decode %arg0 : !sol.string<Memory> -> !sol.array<2 x !sol.string<Memory>, Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// A static uint256[2][2] has a 128-byte head and no offsets. Each row of
// words is one bulk copy into its fresh allocation.
// CHECK-LABEL: yul.func @__sol.abi_decode.memory.memory.array$_2_array$_2_ui256_$_Memory_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:         %[[P:.*]] = yul.mload %c64_i256
// CHECK:         yul.for
// CHECK:           %[[ROW:.*]] = yul.mload %c64_i256
// CHECK:           %[[C2:.*]] = yul.constant 2{{$}}
// CHECK:           %[[SZ:.*]] = yul.mul %[[C2]], %{{.*}}
// CHECK:           yul.mcopy %[[ROW]], %arg4, %[[SZ]]
// CHECK:           yul.mstore %arg3, %[[ROW]]
// CHECK:           %[[C64:.*]] = yul.constant 64{{$}}
// CHECK:           yul.add %arg4, %[[C64]]
// CHECK-NOT:     yul.for
// CHECK:         yul.func_return %[[P]]
// CHECK-LABEL: yul.func @__sol.abi_decode_tuple.memory.array$_2_array$_2_ui256_$_Memory_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:         %[[HEAD:.*]] = yul.constant 128{{$}}
// CHECK:         yul.cmp slt, %{{.*}}, %[[HEAD]]
// CHECK:         yul.func_call @__sol.abi_decode.memory.memory.array$_2_array$_2_ui256_$_Memory_$_$_Memory_$(%arg0, %arg1)
// CHECK-LABEL: yul.func @array_fixed_fixed : (i256) -> ()
// CHECK:         yul.func_call @__sol.abi_decode_tuple.memory.array$_2_array$_2_ui256_$_Memory_$_$_Memory_$(
module {
  sol.contract @C {
    sol.func @array_fixed_fixed(%arg0: !sol.string<Memory>) attributes {state_mutability = #Pure} {
      %0 = sol.decode %arg0 : !sol.string<Memory> -> !sol.array<2 x !sol.array<2 x ui256, Memory>, Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// A dynamic array of words is one bulk copy after its length.
// CHECK-LABEL: yul.func @__sol.abi_decode_tuple.memory.array$_dyn_ui256_$_Memory_$ : (i256, i256) -> i256
// CHECK:         yul.cmp slt
// CHECK:         %[[OFF:.*]] = yul.mload %[[SRC:.*]]
// CHECK:         yul.cmp ugt, %[[OFF]], %{{.*}}
// CHECK:         %[[ARR:.*]] = yul.add %[[SRC]], %[[OFF]]
// CHECK:         %[[LEN:.*]] = yul.mload %[[ARR]]
// CHECK:         %[[P:.*]] = yul.func_call @__sol.alloc
// CHECK:         yul.mstore %[[P]], %[[LEN]]
// CHECK-NEXT:    %[[C32:.*]] = yul.constant 32
// CHECK-NEXT:    %[[SPAN:.*]] = yul.mul %[[LEN]], %[[C32]]
// CHECK-NEXT:    %[[END:.*]] = yul.add %{{.*}}, %[[SPAN]]
// CHECK-NEXT:    yul.cmp ugt, %[[END]], %arg1
// CHECK-NOT:     yul.for
// CHECK:         %[[SZ:.*]] = yul.mul %[[LEN]], %{{.*}}
// CHECK-NEXT:    yul.mcopy %{{.*}}, %{{.*}}, %[[SZ]]
// CHECK:         yul.func_return %[[P]]
// CHECK-LABEL: yul.func @array_dyn : (i256) -> ()
// CHECK:         yul.func_call @__sol.abi_decode_tuple.memory.array$_dyn_ui256_$_Memory_$(
module {
  sol.contract @C {
    sol.func @array_dyn(%arg0: !sol.string<Memory>) attributes {state_mutability = #Pure} {
      %0 = sol.decode %arg0 : !sol.string<Memory> -> !sol.array<? x ui256, Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// CHECK-LABEL: yul.func @__sol.abi_decode_tuple.memory.array$_2_ui256_$_Memory_$ : (i256, i256) -> i256
// CHECK:         %[[HEAD:.*]] = yul.constant 64{{$}}
// CHECK:         yul.cmp slt, %{{.*}}, %[[HEAD]]
// CHECK:         %[[P:.*]] = yul.mload %c64_i256
// CHECK:         %[[N:.*]] = yul.constant 2{{$}}
// CHECK-NOT:     yul.for
// CHECK:         %[[SZ:.*]] = yul.mul %[[N]], %{{.*}}
// CHECK-NEXT:    yul.mcopy %[[P]], %arg0, %[[SZ]]
// CHECK:         yul.func_return %[[P]]
// CHECK-LABEL: yul.func @array_fixed : (i256) -> ()
// CHECK:         yul.func_call @__sol.abi_decode_tuple.memory.array$_2_ui256_$_Memory_$(
module {
  sol.contract @C {
    sol.func @array_fixed(%arg0: !sol.string<Memory>) attributes {state_mutability = #Pure} {
      %0 = sol.decode %arg0 : !sol.string<Memory> -> !sol.array<2 x ui256, Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}
