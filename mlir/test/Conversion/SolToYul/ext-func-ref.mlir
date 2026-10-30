// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// An external function pointer is an {address, selector} pair in registers,
// one word (address << 32 | selector) << 64 in memory, and address << 32 |
// selector at its field offset in storage.

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// An ABI-decoded word must have its low 64 bits clear. The dispatcher decodes
// each argument tuple through its helper. A top-level argument is split into
// the pair; an array element is stored as the raw word.
// CHECK:         case 286331153 {
// CHECK:           %[[FP:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.ext_func_ref$_$_ui256_$returnsui256_$(
// CHECK:           yul.func_call @setExtFn(%[[FP]])
// CHECK:         case 572662306 {
// CHECK:           %[[ARR:.*]] = yul.func_call @__sol.abi_decode_tuple.calldata.array$_dyn_ext_func_ref$_$_ui256_$returnsui256_$_$_Memory_$(
// CHECK:           yul.func_call @setArr(%[[ARR]])

// CHECK-LABEL: yul.func @__sol.abi_decode.calldata.memory.array$_dyn_ext_func_ref$_$_ui256_$returnsui256_$_$_Memory_$ : (i256, i256) -> i256
// CHECK:         yul.for
// CHECK:           %[[EW:.*]] = yul.calldataload
// CHECK:           %[[EHI:.*]] = yul.constant -18446744073709551616
// CHECK:           %[[ECLEAN:.*]] = yul.and %[[EW]], %[[EHI]]
// CHECK:           %[[EBAD:.*]] = yul.cmp ne, %[[EW]], %[[ECLEAN]]
// CHECK:           yul.if %[[EBAD]] {
// CHECK-NOT:       yul.arith_shr
// CHECK:           yul.mstore %{{.*}}, %[[EW]]

// CHECK-LABEL: yul.func @__sol.abi_decode_tuple.calldata.ext_func_ref$_$_ui256_$returnsui256_$ : (i256, i256) -> !llvm.struct<(i256, i256)>
// CHECK:         %[[W:.*]] = yul.calldataload
// CHECK:         %[[HI:.*]] = yul.constant -18446744073709551616
// CHECK:         %[[CLEAN:.*]] = yul.and %[[W]], %[[HI]]
// CHECK:         %[[BAD:.*]] = yul.cmp ne, %[[W]], %[[CLEAN]]
// CHECK:         yul.if %[[BAD]] {
// CHECK:           yul.revert
// CHECK:         %[[A:.*]] = yul.arith_shr %[[W]], %c96_i256
// CHECK:         %[[S:.*]] = yul.arith_shr %[[W]], %c64_i256
// CHECK:         %[[SEL:.*]] = yul.and %[[S]], %c4294967295_i256
// CHECK:         %[[R0:.*]] = llvm.insertvalue %[[A]], %{{.*}}[0]
// CHECK:         %[[FP:.*]] = llvm.insertvalue %[[SEL]], %[[R0]][1]
// CHECK:         yul.func_return %[[FP]] : !llvm.struct<(i256, i256)>

// CHECK-LABEL: yul.func @setExtFn : (!llvm.struct<(i256, i256)>) -> ()
// CHECK-NEXT:  ^bb0(%[[FP:.*]]: !llvm.struct<(i256, i256)>):
// CHECK:         llvm.insertvalue %c8_i256, %{{.*}}[1]
// CHECK:         %[[ADDR:.*]] = llvm.extractvalue %[[FP]][0]
// CHECK:         %[[SEL:.*]] = llvm.extractvalue %[[FP]][1]
// CHECK:         %[[SELC:.*]] = yul.and %[[SEL]], %c4294967295_i256
// CHECK:         %[[HI:.*]] = yul.arith_shl %[[ADDR]], %c32_i256
// CHECK:         %[[PACKED:.*]] = yul.or %[[HI]], %[[SELC]]
// CHECK:         %[[T:.*]] = yul.arith_shl %[[PACKED]], %c64_i256
// CHECK:         %[[V:.*]] = yul.arith_shr %[[T]], %c64_i256
// CHECK:         yul.arith_shl %c6277101735386680763835789423207666416102355444464034512895_i256, %{{.*}}
// CHECK:         %[[VS:.*]] = yul.arith_shl %[[V]], %{{.*}}
// CHECK:         %[[W:.*]] = yul.or %{{.*}}, %[[VS]]
// CHECK:         yul.sstore %{{.*}}, %[[W]]
module {
  sol.contract @C {
    sol.state_var @fn slot 0 offset 8 : !sol.ext_func_ref<(ui256) -> ui256>
    sol.func @setExtFn(%arg0: !sol.ext_func_ref<(ui256) -> ui256>) attributes {orig_fn_type = (!sol.ext_func_ref<(ui256) -> ui256>) -> (), selector = 286331153 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @fn : !sol.ptr<!sol.ext_func_ref<(ui256) -> ui256>, Storage>
      sol.store %arg0, %0 : !sol.ext_func_ref<(ui256) -> ui256>, !sol.ptr<!sol.ext_func_ref<(ui256) -> ui256>, Storage>
      sol.return
    }
    sol.func @setArr(%arg0: !sol.array<? x !sol.ext_func_ref<(ui256) -> ui256>, Memory>) attributes {orig_fn_type = (!sol.array<? x !sol.ext_func_ref<(ui256) -> ui256>, Memory>) -> (), selector = 572662306 : i32, state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>

// The selector lane is left-aligned as bytes4.
// CHECK-LABEL: yul.func @lanes : (i256) -> (i256, i256)
// CHECK-NEXT:  ^bb0(%[[A:.*]]: i256):
// CHECK:         %[[SEL:.*]] = yul.constant 230582047
// CHECK:         %[[R0:.*]] = llvm.insertvalue %[[A]], %{{.*}}[0]
// CHECK:         %[[REF:.*]] = llvm.insertvalue %[[SEL]], %[[R0]][1]
// CHECK:         %[[ADDR:.*]] = llvm.extractvalue %[[REF]][0]
// CHECK:         %[[S:.*]] = llvm.extractvalue %[[REF]][1]
// CHECK:         %[[C224:.*]] = yul.constant 224
// CHECK:         %[[B4:.*]] = yul.arith_shl %[[S]], %[[C224]]
// CHECK:         yul.func_return %[[ADDR]], %[[B4]] : i256, i256
module {
  sol.contract @C {
    sol.func @lanes(%a: !sol.address) -> (!sol.address, !sol.fixedbytes<4>) {
      %0 = sol.ext_func_constant %a {selector = 230582047 : i32} : !sol.address -> !sol.ext_func_ref<() -> ()>
      %1 = sol.ext_func_addr %0 : !sol.ext_func_ref<() -> ()> -> !sol.address
      %2 = sol.ext_func_selector %0 : !sol.ext_func_ref<() -> ()> -> !sol.fixedbytes<4>
      sol.return %1, %2 : !sol.address, !sol.fixedbytes<4>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>

// CHECK-LABEL: yul.func @structGet : (i256) -> !llvm.struct<(i256, i256)>
// CHECK:         %[[W:.*]] = yul.mload
// CHECK:         %[[A:.*]] = yul.arith_shr %[[W]], %c96_i256
// CHECK:         %[[S:.*]] = yul.arith_shr %[[W]], %c64_i256
// CHECK:         %[[SEL:.*]] = yul.and %[[S]], %c4294967295_i256
// CHECK:         %[[R0:.*]] = llvm.insertvalue %[[A]], %{{.*}}[0]
// CHECK:         %[[R:.*]] = llvm.insertvalue %[[SEL]], %[[R0]][1]
// CHECK:         yul.func_return %[[R]] : !llvm.struct<(i256, i256)>
module {
  sol.contract @C {
    sol.func @structGet(%arg0: !sol.struct<(!sol.ext_func_ref<(ui256) -> ui256>, ui256), Memory>) -> !sol.ext_func_ref<(ui256) -> ui256> {
      %c0_ui64 = sol.constant 0 : ui64
      %0 = sol.gep %arg0, %c0_ui64 : !sol.struct<(!sol.ext_func_ref<(ui256) -> ui256>, ui256), Memory>, ui64, !sol.ptr<!sol.ext_func_ref<(ui256) -> ui256>, Memory>
      %1 = sol.load %0 : !sol.ptr<!sol.ext_func_ref<(ui256) -> ui256>, Memory>, !sol.ext_func_ref<(ui256) -> ui256>
      sol.return %1 : !sol.ext_func_ref<(ui256) -> ui256>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>

// CHECK-LABEL: yul.func @structSet : (i256, !llvm.struct<(i256, i256)>) -> ()
// CHECK-NEXT:  ^bb0(%{{.*}}: i256, %[[FP:.*]]: !llvm.struct<(i256, i256)>):
// CHECK:         %[[P:.*]] = yul.add
// CHECK:         %[[A:.*]] = llvm.extractvalue %[[FP]][0]
// CHECK:         %[[S:.*]] = llvm.extractvalue %[[FP]][1]
// CHECK:         %[[SEL:.*]] = yul.and %[[S]], %c4294967295_i256
// CHECK:         %[[AS:.*]] = yul.arith_shl %[[A]], %c32_i256
// CHECK:         %[[F:.*]] = yul.or %[[AS]], %[[SEL]]
// CHECK:         %[[W:.*]] = yul.arith_shl %[[F]], %c64_i256
// CHECK:         yul.mstore %[[P]], %[[W]]
module {
  sol.contract @C {
    sol.func @structSet(%arg0: !sol.struct<(!sol.ext_func_ref<(ui256) -> ui256>, ui256), Memory>, %arg1: !sol.ext_func_ref<(ui256) -> ui256>) {
      %c0_ui64 = sol.constant 0 : ui64
      %0 = sol.gep %arg0, %c0_ui64 : !sol.struct<(!sol.ext_func_ref<(ui256) -> ui256>, ui256), Memory>, ui64, !sol.ptr<!sol.ext_func_ref<(ui256) -> ui256>, Memory>
      sol.store %arg1, %0 : !sol.ext_func_ref<(ui256) -> ui256>, !sol.ptr<!sol.ext_func_ref<(ui256) -> ui256>, Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>

// CHECK-LABEL: yul.func @getExtFn : () -> !llvm.struct<(i256, i256)>
// CHECK:         llvm.insertvalue %c8_i256, %{{.*}}[1]
// CHECK:         %[[V:.*]] = yul.arith_shr
// CHECK:         %[[SEL:.*]] = yul.and %[[V]], %c4294967295_i256
// CHECK:         %[[HI:.*]] = yul.arith_shr %[[V]], %c32_i256
// CHECK:         %[[ADDR:.*]] = yul.and %[[HI]], %c1461501637330902918203684832716283019655932542975_i256
// CHECK:         %[[R0:.*]] = llvm.insertvalue %[[ADDR]], %{{.*}}[0]
// CHECK:         %[[R1:.*]] = llvm.insertvalue %[[SEL]], %[[R0]][1]
// CHECK:         yul.func_return %[[R1]] : !llvm.struct<(i256, i256)>
module {
  sol.contract @C {
    sol.state_var @fn slot 0 offset 8 : !sol.ext_func_ref<(ui256) -> ui256>
    sol.func @getExtFn() -> !sol.ext_func_ref<(ui256) -> ui256> {
      %0 = sol.addr_of @fn : !sol.ptr<!sol.ext_func_ref<(ui256) -> ui256>, Storage>
      %1 = sol.load %0 : !sol.ptr<!sol.ext_func_ref<(ui256) -> ui256>, Storage>, !sol.ext_func_ref<(ui256) -> ui256>
      sol.return %1 : !sol.ext_func_ref<(ui256) -> ui256>
    }
  } {kind = #Contract, runtime}
}
