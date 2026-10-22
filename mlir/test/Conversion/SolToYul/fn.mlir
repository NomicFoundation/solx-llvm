// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
#Pure = #sol<StateMutability Pure>

// Each case decodes its argument tuple and encodes its result tuple through
// the helper of its types; the argument validation lives in the decoders.
// No route is payable, so the call value is tested once above the switch.
// CHECK-LABEL: yul.object @C_deployed {

// CHECK-LABEL:   yul.func @__sol.abi_encode_tuple.padded.tail.ui256.ui256 : (i256, i256, i256) -> i256
// CHECK:           yul.mstore %arg2, %arg0
// CHECK:           %[[P:.*]] = yul.add %arg2, %{{.*}}
// CHECK:           yul.mstore %[[P]], %arg1

// A bytes1 is validated against its mask.
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.fixedbytes$_1_$ : (i256, i256) -> i256
// CHECK:           %[[A:.*]] = yul.calldataload
// CHECK:           %[[M:.*]] = yul.constant -452312848583266388373324160190187140051835877600158453279131187530910662656
// CHECK:           %[[V:.*]] = yul.and %[[A]], %[[M]]
// CHECK:           %[[BAD:.*]] = yul.cmp ne, %[[A]], %[[V]]
// CHECK:           yul.if %[[BAD]] {
// CHECK:           yul.func_return %[[V]]

// An enum is validated against its maximum.
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.enum$_2_$ : (i256, i256) -> i256
// CHECK:           %[[A:.*]] = yul.calldataload
// CHECK:           %[[MAX:.*]] = yul.constant 2
// CHECK:           %[[BAD:.*]] = yul.cmp ugt, %[[A]], %[[MAX]]
// CHECK:           yul.if %[[BAD]] {
// CHECK:           yul.func_return %[[A]]

// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.ui256 : (i256, i256) -> i256
// CHECK:           %[[A:.*]] = yul.calldataload
// CHECK:           yul.func_return %[[A]]

// A uint64 is validated against its mask.
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.ui64 : (i256, i256) -> i256
// CHECK:           %[[A:.*]] = yul.calldataload
// CHECK:           %[[M:.*]] = yul.constant 18446744073709551615
// CHECK:           %[[V:.*]] = yul.and %[[A]], %[[M]]
// CHECK:           %[[BAD:.*]] = yul.cmp ne, %[[A]], %[[V]]
// CHECK:           yul.if %[[BAD]] {
// CHECK:           yul.func_return %[[V]]

// A bool is validated to be 0 or 1.
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.calldata.i1 : (i256, i256) -> i256
// CHECK:           %[[A:.*]] = yul.calldataload
// CHECK:           %[[B:.*]] = yul.cmp ne, %[[A]], %{{.*}}
// CHECK:           %[[BAD:.*]] = yul.cmp ne, %[[A]], %[[B]]
// CHECK:           yul.if %[[BAD]] {
// CHECK:           yul.func_return %[[B]]

// CHECK-LABEL:   yul.func @empty : () -> ()
// CHECK-NEXT:      yul.func_return

// CHECK-LABEL:   yul.func @tuple_internal : () -> (i256, i256)
// CHECK:           yul.func_return %{{.*}}, %{{.*}} : i256, i256

// CHECK-LABEL:   yul.func @tuple : () -> (i256, i256)
// CHECK:           %[[T:.*]]:2 = yul.func_call @tuple_internal() : () -> (i256, i256)
// CHECK:           yul.func_return %[[T]]#0, %[[T]]#1 : i256, i256

// CHECK-LABEL:   yul.func @ui256 : (i256) -> i256
// CHECK:           %[[R:.*]] = yul.func_call @ui256_internal(%arg0) : (i256) -> i256
// CHECK:           yul.func_return %[[R]] : i256

// CHECK:         yul.callvalue
// CHECK:         %[[W:.*]] = yul.calldataload
// CHECK:         %[[C224:.*]] = yul.constant 224{{$}}
// CHECK:         %[[SEL:.*]] = yul.arith_shr %[[W]], %[[C224]]
// CHECK:         yul.switch %[[SEL]] : i256
// CHECK-NEXT:    case 3346476778 {
// CHECK:           %[[B:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.i1(
// CHECK:           %[[R:.*]] = yul.func_call @i1(%[[B]]) : (i256) -> i256
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.i1(%[[R]],
// CHECK:         case 1090974155 {
// CHECK:           %[[V:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.ui64(
// CHECK:           %[[R:.*]] = yul.func_call @ui64(%[[V]]) : (i256) -> i256
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.ui64(%[[R]],
// CHECK:         case 2427338207 {
// CHECK:           %[[A:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.ui256(
// CHECK:           %[[R:.*]] = yul.func_call @ui256(%[[A]]) : (i256) -> i256
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(%[[R]],
// CHECK:         case 2749301445 {
// CHECK:           %[[A:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.enum$_2_$(
// CHECK:           %[[R:.*]] = yul.func_call @e(%[[A]]) : (i256) -> i256
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.enum$_2_$(%[[R]],
// CHECK:         case 3200940114 {
// CHECK:           %[[V:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.fixedbytes$_1_$(
// CHECK:           %[[R:.*]] = yul.func_call @b1(%[[V]]) : (i256) -> i256
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.fixedbytes$_1_$(%[[R]],
// CHECK:         case 829795042 {
// CHECK:           %[[T:.*]]:2 = yul.func_call @tuple() : () -> (i256, i256)
// CHECK:           yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256.ui256(%[[T]]#0, %[[T]]#1,
// CHECK:         case 638722032 {
// CHECK-NOT:       yul.callvalue
// CHECK:           yul.func_call @empty() : () -> ()
// CHECK:           %[[MEM:.*]] = yul.mload
// CHECK:           %[[Z:.*]] = yul.constant 0{{$}}
// CHECK:           yul.return %[[MEM]], %[[Z]]
// CHECK:         default {
module {
  sol.contract @C {
    sol.func @i1(%arg0: i1) -> i1 attributes {orig_fn_type = (i1) -> i1, selector = -948490518 : i32, state_mutability = #NonPayable} {
      sol.return %arg0 : i1
    }
    sol.func @ui64(%arg0: ui64) -> ui64 attributes {orig_fn_type = (ui64) -> ui64, selector = 1090974155 : i32, state_mutability = #NonPayable} {
      sol.return %arg0 : ui64
    }
    sol.func @ui256(%arg0: ui256) -> ui256 attributes {orig_fn_type = (ui256) -> ui256, selector = -1867629089 : i32, state_mutability = #NonPayable} {
      %0 = sol.call @ui256_internal(%arg0) : (ui256) -> ui256
      sol.return %0 : ui256
    }
    sol.func @ui256_internal(%arg0: ui256) -> ui256 {
      sol.return %arg0 : ui256
    }
    sol.func @e(%arg0: !sol.enum<2>) -> !sol.enum<2> attributes {orig_fn_type = (!sol.enum<2>) -> !sol.enum<2>, selector = -1545665851 : i32, state_mutability = #NonPayable} {
      sol.return %arg0 : !sol.enum<2>
    }
    sol.func @b1(%arg0: !sol.fixedbytes<1>) -> !sol.fixedbytes<1> attributes {orig_fn_type = (!sol.fixedbytes<1>) -> !sol.fixedbytes<1>, selector = -1094027182 : i32, state_mutability = #NonPayable} {
      sol.return %arg0 : !sol.fixedbytes<1>
    }
    sol.func @tuple() -> (ui256, ui256) attributes {orig_fn_type = () -> (ui256, ui256), selector = 829795042 : i32, state_mutability = #NonPayable} {
      %0:2 = sol.call @tuple_internal() : () -> (ui256, ui256)
      sol.return %0#0, %0#1 : ui256, ui256
    }
    sol.func @tuple_internal() -> (ui256, ui256) {
      %c1 = sol.constant 1 : ui256
      %c2 = sol.constant 2 : ui256
      sol.return %c1, %c2 : ui256, ui256
    }
    sol.func @empty() attributes {orig_fn_type = () -> (), selector = 638722032 : i32, state_mutability = #Pure} {
      sol.return
    }
  } {kind = #Contract, runtime}
}
