// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// uint8[] calldata is decoded into memory element by element, each
// validated against the uint8 mask.
// CHECK:         case 2364674588 {
// CHECK:           %[[LEN:.*]] = yul.calldataload
// CHECK:           %[[MEM:.*]] = yul.mload
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.calldataload
// CHECK:             %[[M:.*]] = yul.constant 255
// CHECK:             %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK:             %[[BAD:.*]] = yul.cmp ne, %[[V]], %[[C]]
// CHECK:             yul.if %[[BAD]] {
// CHECK:             yul.mstore %{{.*}}, %[[C]]
// CHECK:           yul.func_call @decode(%[[MEM]])

// A dynamic calldata array is not copied: its length word must be in bounds,
// the length fit in 64 bits and the elements fit in calldata; the argument is
// the {data, length} pair.
// CHECK:         case 286331153 {
// CHECK:           %[[OFF:.*]] = yul.calldataload %[[HEAD:.*]]
// CHECK:           %[[TAIL:.*]] = yul.add %[[HEAD]], %[[OFF]]
// CHECK:           %[[C31:.*]] = yul.constant 31
// CHECK:           %[[LAST:.*]] = yul.add %[[TAIL]], %[[C31]]
// CHECK:           %[[BADOFF:.*]] = yul.cmp sge, %[[LAST]], %[[END:.*]]
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
// CHECK:           yul.func_call @cdyn(%[[FP]])

// A static calldata array only needs its whole span in calldata; the argument
// is its head address.
// CHECK:         case 572662306 {
// CHECK:           %[[HEAD:.*]] = yul.constant 4{{$}}
// CHECK:           yul.sub %[[END:.*]], %[[HEAD]]
// CHECK:           %[[AEND:.*]] = yul.add %[[HEAD]], %{{.*}}
// CHECK:           %[[BADSPAN:.*]] = yul.cmp ugt, %[[AEND]], %[[END]]
// CHECK:           yul.if %[[BADSPAN]] {
// CHECK-NOT:       yul.calldataload
// CHECK:           yul.func_call @cfix(%[[HEAD]])

// Dynamic types are decoded behind an offset (32-byte head); every
// nested string is validated and copied with mcopy.
// CHECK-LABEL: yul.func @string_dyn : (i256) -> ()
// CHECK:         %[[HEAD:.*]] = yul.constant 32{{$}}
// CHECK:         yul.cmp slt, %{{.*}}, %[[HEAD]]
// CHECK:         yul.for
// CHECK:           yul.cmp sge
// CHECK:           yul.mcopy
// CHECK-NOT:     yul.for
// CHECK:         yul.func_return

// CHECK-LABEL: yul.func @string_fixed : (i256) -> ()
// CHECK:         %[[HEAD:.*]] = yul.constant 32{{$}}
// CHECK:         yul.cmp slt, %{{.*}}, %[[HEAD]]
// CHECK:         yul.for
// CHECK:           yul.mcopy
// CHECK-NOT:     yul.for
// CHECK:         yul.func_return

// A static uint256[2][2] has a 128-byte head and no offsets.
// CHECK-LABEL: yul.func @array_fixed_fixed : (i256) -> ()
// CHECK-NOT:     yul.mcopy
// CHECK:         %[[HEAD:.*]] = yul.constant 128{{$}}
// CHECK:         yul.cmp slt, %{{.*}}, %[[HEAD]]
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.mload
// CHECK:             yul.mstore %{{.*}}, %[[V]]
// CHECK:           %[[C64:.*]] = yul.constant 64{{$}}
// CHECK:           yul.add %{{.*}}, %[[C64]]

// CHECK-LABEL: yul.func @array_dyn : (i256) -> ()
// CHECK:         yul.cmp slt
// CHECK:         %[[OFF:.*]] = yul.mload %[[SRC:.*]]
// CHECK:         yul.cmp ugt, %[[OFF]], %{{.*}}
// CHECK:         %[[ARR:.*]] = yul.add %[[SRC]], %[[OFF]]
// CHECK:         %[[LEN:.*]] = yul.mload %[[ARR]]
// CHECK:         yul.for
// CHECK:           yul.cmp ult, %{{.*}}, %[[LEN]]
// CHECK:           %[[V:.*]] = yul.mload
// CHECK:           yul.mstore %{{.*}}, %[[V]]

// CHECK-LABEL: yul.func @array_fixed : (i256) -> ()
// CHECK:         %[[HEAD:.*]] = yul.constant 64{{$}}
// CHECK:         yul.cmp slt, %{{.*}}, %[[HEAD]]
// CHECK:         %[[N:.*]] = yul.constant 2{{$}}
// CHECK:         yul.for
// CHECK:           yul.cmp ult, %{{.*}}, %[[N]]
// CHECK:           %[[V:.*]] = yul.mload
// CHECK:           yul.mstore %{{.*}}, %[[V]]

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @decode(%arg0: !sol.array<? x ui8, Memory>) attributes {orig_fn_type = (!sol.array<? x ui8, Memory>) -> (), selector = -1930292708 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @cdyn(%arg0: !sol.array<? x ui256, CallData>) attributes {orig_fn_type = (!sol.array<? x ui256, CallData>) -> (), selector = 286331153 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @cfix(%arg0: !sol.array<2 x ui256, CallData>) attributes {orig_fn_type = (!sol.array<2 x ui256, CallData>) -> (), selector = 572662306 : i32, state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @array_fixed(%arg0: !sol.string<Memory>) attributes {state_mutability = #Pure} {
      %0 = sol.decode %arg0 : !sol.string<Memory> -> !sol.array<2 x ui256, Memory>
      sol.return
    }
    sol.func @array_dyn(%arg0: !sol.string<Memory>) attributes {state_mutability = #Pure} {
      %0 = sol.decode %arg0 : !sol.string<Memory> -> !sol.array<? x ui256, Memory>
      sol.return
    }
    sol.func @array_fixed_fixed(%arg0: !sol.string<Memory>) attributes {state_mutability = #Pure} {
      %0 = sol.decode %arg0 : !sol.string<Memory> -> !sol.array<2 x !sol.array<2 x ui256, Memory>, Memory>
      sol.return
    }
    sol.func @string_fixed(%arg0: !sol.string<Memory>) attributes {state_mutability = #Pure} {
      %0 = sol.decode %arg0 : !sol.string<Memory> -> !sol.array<2 x !sol.string<Memory>, Memory>
      sol.return
    }
    sol.func @string_dyn(%arg0: !sol.string<Memory>) attributes {state_mutability = #Pure} {
      %0 = sol.decode %arg0 : !sol.string<Memory> -> !sol.array<? x !sol.string<Memory>, Memory>
      sol.return
    }
  } {kind = #Contract}
}
