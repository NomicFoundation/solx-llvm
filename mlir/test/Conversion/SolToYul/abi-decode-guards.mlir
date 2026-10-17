// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Decoding into memory allocates first, so an oversized length panics 0x41
// before the span check against the end of the tuple.
// CHECK-LABEL: yul.object @C_deployed
// CHECK:         %[[CDS:.*]] = yul.calldatasize
// CHECK:         case 1 {
// CHECK:           yul.cmp sge, %{{.*}}, %[[CDS]]
// CHECK:           %[[BLEN:.*]] = yul.calldataload
// CHECK:           yul.cmp ugt, %[[BLEN]], %{{.*}}
// CHECK:           yul.constant 65
// CHECK:           yul.mstore %{{.*}}, %[[BLEN]]
// CHECK:           %[[BEND:.*]] = yul.add %{{.*}}, %[[BLEN]]
// CHECK-NEXT:      yul.cmp ugt, %[[BEND]], %[[CDS]]
// CHECK:           yul.calldatacopy
// CHECK:           yul.cmp sge, %{{.*}}, %[[CDS]]
// CHECK:           %[[ALEN:.*]] = yul.calldataload
// CHECK:           yul.cmp ugt, %[[ALEN]], %{{.*}}
// CHECK:           yul.constant 65
// CHECK:           yul.mstore %{{.*}}, %[[ALEN]]
// CHECK-NEXT:      yul.constant 32
// CHECK-NEXT:      %[[ASPAN:.*]] = yul.mul %[[ALEN]]
// CHECK-NEXT:      %[[AEND:.*]] = yul.add %{{.*}}, %[[ASPAN]]
// CHECK-NEXT:      yul.cmp ugt, %[[AEND]], %[[CDS]]
// CHECK:           yul.for

// `new bytes(n)` panics 0x41 on a length beyond 2^64 - 1 before touching the
// free pointer.
// CHECK-LABEL: yul.func @new_bytes
// CHECK:         %[[MAX:.*]] = yul.constant 18446744073709551615
// CHECK-NEXT:    yul.cmp ugt, %arg0, %[[MAX]]
// CHECK:         yul.constant 65
// CHECK:         yul.mload
// CHECK:         yul.mstore %{{.*}}, %arg0

// A calldata array of statically encoded elements stays a raw copy.
// CHECK-LABEL: yul.func @uint_array_cd2m
// CHECK-NOT:     yul.calldatasize
// CHECK:         yul.calldatacopy
// CHECK-NOT:     yul.calldatasize
// CHECK:         yul.func_return

// A calldata array of dynamically encoded elements is decoded from its length
// word against the end of calldata: the element offsets are range checked.
// CHECK-LABEL: yul.func @bytes_array_cd2m
// CHECK:         %[[DATA:.*]] = llvm.extractvalue %arg0[0]
// CHECK-NEXT:    %[[C32:.*]] = yul.constant 32
// CHECK-NEXT:    %[[HEAD:.*]] = yul.sub %[[DATA]], %[[C32]]
// CHECK-NEXT:    %[[CDS:.*]] = yul.calldatasize
// CHECK:         %[[LEN:.*]] = yul.calldataload %[[HEAD]]
// CHECK:         yul.cmp ugt, %[[LEN]], %{{.*}}
// CHECK:         yul.constant 65
// CHECK:         yul.mstore %{{.*}}, %[[LEN]]
// CHECK:         %[[SPAN:.*]] = yul.mul %[[LEN]]
// CHECK-NEXT:    %[[END:.*]] = yul.add %{{.*}}, %[[SPAN]]
// CHECK-NEXT:    yul.cmp ugt, %[[END]], %[[CDS]]
// CHECK:         yul.for
// CHECK:           %[[OFF:.*]] = yul.calldataload
// CHECK-NEXT:      yul.constant 18446744073709551615
// CHECK-NEXT:      yul.cmp ugt, %[[OFF]]
// CHECK:           yul.revert

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
// CHECK:         yul.constant 65
// CHECK:         yul.mstore %{{.*}}, %[[LEN]]
// CHECK:         %[[END:.*]] = yul.add %{{.*}}, %[[LEN]]
// CHECK-NEXT:    yul.cmp ugt, %[[END]], %[[CDS]]
// CHECK:         yul.calldatacopy
// CHECK:         yul.func_return %[[MEM]]

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
