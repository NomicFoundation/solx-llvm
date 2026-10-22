// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.object @C_deployed

// Decoding into memory allocates first, so an oversized length panics 0x41
// before the span check against the end of the tuple.
// CHECK-LABEL: yul.func @__sol.abi_decode_tuple.calldata.string$_Memory_$.array$_dyn_ui256_$_Memory_$ : (i256, i256) -> (i256, i256)
// CHECK:         yul.cmp sge, %{{.*}}, %arg1
// CHECK:         %[[BLEN:.*]] = yul.calldataload
// CHECK:         yul.cmp ugt, %[[BLEN]], %{{.*}}
// CHECK:         %[[PANIC:.*]] = yul.constant 65
// CHECK-NEXT:    yul.func_call @__sol.panic(%[[PANIC]])
// CHECK:         %[[B:.*]] = yul.func_call @__sol.alloc
// CHECK-NEXT:    yul.mstore %[[B]], %[[BLEN]]
// CHECK:         %[[BEND:.*]] = yul.add %{{.*}}, %[[BLEN]]
// CHECK-NEXT:    yul.cmp ugt, %[[BEND]], %arg1
// CHECK:         yul.calldatacopy
// CHECK:         yul.cmp sge, %{{.*}}, %arg1
// CHECK:         %[[ALEN:.*]] = yul.calldataload
// CHECK:         yul.cmp ugt, %[[ALEN]], %{{.*}}
// CHECK:         %[[PANIC:.*]] = yul.constant 65
// CHECK-NEXT:    yul.func_call @__sol.panic(%[[PANIC]])
// CHECK:         %[[A:.*]] = yul.func_call @__sol.alloc
// CHECK-NEXT:    yul.mstore %[[A]], %[[ALEN]]
// CHECK-NEXT:    yul.constant 32
// CHECK-NEXT:    %[[ASPAN:.*]] = yul.mul %[[ALEN]]
// CHECK-NEXT:    %[[AEND:.*]] = yul.add %{{.*}}, %[[ASPAN]]
// CHECK-NEXT:    yul.cmp ugt, %[[AEND]], %arg1
// CHECK-NOT:     yul.for
// CHECK:         yul.calldatacopy
// CHECK:         yul.func_return %[[B]], %[[A]]

// CHECK-LABEL: yul.func @__sol.abi_decode.calldata.memory.array$_dyn_string$_Memory_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:         %[[LEN:.*]] = yul.calldataload %arg0
// CHECK:         yul.cmp ugt, %[[LEN]], %{{.*}}
// CHECK:         %[[PANIC:.*]] = yul.constant 65
// CHECK-NEXT:    yul.func_call @__sol.panic(%[[PANIC]])
// CHECK:         %[[P:.*]] = yul.func_call @__sol.alloc
// CHECK-NEXT:    yul.mstore %[[P]], %[[LEN]]
// CHECK:         %[[SPAN:.*]] = yul.mul %[[LEN]]
// CHECK-NEXT:    %[[END:.*]] = yul.add %{{.*}}, %[[SPAN]]
// CHECK-NEXT:    yul.cmp ugt, %[[END]], %arg1
// CHECK:         yul.for
// CHECK:           %[[OFF:.*]] = yul.calldataload
// CHECK-NEXT:      yul.constant 18446744073709551615
// CHECK-NEXT:      yul.cmp ugt, %[[OFF]]
// CHECK:           yul.revert
// CHECK:         yul.func_return %[[P]]

// `new bytes(n)` panics 0x41 on a length beyond 2^64 - 1 before allocating.
// CHECK-LABEL: yul.func @new_bytes
// CHECK:         %[[MAX:.*]] = yul.constant 18446744073709551615
// CHECK-NEXT:    yul.cmp ugt, %arg0, %[[MAX]]
// CHECK:         %[[PANIC:.*]] = yul.constant 65
// CHECK-NEXT:    yul.func_call @__sol.panic(%[[PANIC]])
// CHECK:         %[[P:.*]] = yul.func_call @__sol.alloc
// CHECK-NEXT:    yul.mstore %[[P]], %arg0

// A calldata array of statically encoded elements stays a raw copy.
// CHECK-LABEL: yul.func @uint_array_cd2m
// CHECK-NOT:     yul.calldatasize
// CHECK:         yul.calldatacopy
// CHECK-NOT:     yul.calldatasize
// CHECK:         yul.func_return

// A calldata array of dynamically encoded elements is decoded from its length
// word against the end of calldata.
// CHECK-LABEL: yul.func @bytes_array_cd2m
// CHECK:         %[[DATA:.*]] = llvm.extractvalue %arg0[0]
// CHECK-NEXT:    %[[C32:.*]] = yul.constant 32
// CHECK-NEXT:    %[[HEAD:.*]] = yul.sub %[[DATA]], %[[C32]]
// CHECK-NEXT:    %[[CDS:.*]] = yul.calldatasize
// CHECK-NEXT:    %[[P:.*]] = yul.func_call @__sol.abi_decode.calldata.memory.array$_dyn_string$_Memory_$_$_Memory_$(%[[HEAD]], %[[CDS]])
// CHECK-NEXT:    yul.func_return %[[P]]

// A calldata struct is decoded against the end of calldata: the head must fit,
// a member offset is range checked, and the member's allocation panics before
// its end check.
// CHECK-LABEL: yul.func @struct_cd2m
// CHECK:         %[[CDS:.*]] = yul.calldatasize
// CHECK-NEXT:    %[[C64:.*]] = yul.constant 64
// CHECK-NEXT:    %[[HEADEND:.*]] = yul.add %arg0, %[[C64]]
// CHECK-NEXT:    yul.cmp ugt, %[[HEADEND]], %[[CDS]]
// CHECK:         yul.revert
// CHECK:         %[[V0:.*]] = yul.calldataload %arg0
// CHECK-NEXT:    yul.mstore %[[MEM:.*]], %[[V0]]
// CHECK:         %[[OFF:.*]] = yul.calldataload
// CHECK-NEXT:    yul.constant 18446744073709551615
// CHECK-NEXT:    yul.cmp ugt, %[[OFF]]
// CHECK:         yul.revert
// CHECK:         %[[TAIL:.*]] = yul.add %arg0, %[[OFF]]
// CHECK:         %[[LEN:.*]] = yul.calldataload %[[TAIL]]
// CHECK:         yul.cmp ugt, %[[LEN]], %{{.*}}
// CHECK:         %[[PANIC:.*]] = yul.constant 65
// CHECK-NEXT:    yul.func_call @__sol.panic(%[[PANIC]])
// CHECK:         %[[P:.*]] = yul.func_call @__sol.alloc
// CHECK-NEXT:    yul.mstore %[[P]], %[[LEN]]
// CHECK:         %[[END:.*]] = yul.add %{{.*}}, %[[LEN]]
// CHECK-NEXT:    yul.cmp ugt, %[[END]], %[[CDS]]
// CHECK:         yul.calldatacopy
// CHECK:         yul.func_return %[[MEM]]

// CHECK:         %[[CDS:.*]] = yul.calldatasize
// CHECK:         case 1 {
// CHECK:           yul.func_call @__sol.abi_decode_tuple.calldata.string$_Memory_$.array$_dyn_ui256_$_Memory_$(%{{.*}}, %[[CDS]])

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @struct_cd2m(%arg0: !sol.struct<(ui256, !sol.string<CallData>), CallData>) -> !sol.struct<(ui256, !sol.string<Memory>), Memory> {
      %0 = sol.data_loc_cast %arg0 : !sol.struct<(ui256, !sol.string<CallData>), CallData>, !sol.struct<(ui256, !sol.string<Memory>), Memory>
      sol.return %0 : !sol.struct<(ui256, !sol.string<Memory>), Memory>
    }
    sol.func @bytes_array_cd2m(%arg0: !sol.array<? x !sol.string<CallData>, CallData>) -> !sol.array<? x !sol.string<Memory>, Memory> {
      %0 = sol.data_loc_cast %arg0 : !sol.array<? x !sol.string<CallData>, CallData>, !sol.array<? x !sol.string<Memory>, Memory>
      sol.return %0 : !sol.array<? x !sol.string<Memory>, Memory>
    }
    sol.func @uint_array_cd2m(%arg0: !sol.array<? x ui256, CallData>) -> !sol.array<? x ui256, Memory> {
      %0 = sol.data_loc_cast %arg0 : !sol.array<? x ui256, CallData>, !sol.array<? x ui256, Memory>
      sol.return %0 : !sol.array<? x ui256, Memory>
    }
    sol.func @new_bytes(%arg0: ui256) -> !sol.string<Memory> {
      %0 = sol.malloc %arg0 : (ui256) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
    sol.func @decode(%arg0: !sol.string<Memory>, %arg1: !sol.array<? x ui256, Memory>) attributes {orig_fn_type = (!sol.string<Memory>, !sol.array<? x ui256, Memory>) -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract, runtime}
}
