// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Array elements are read and written as their own type on copy and encode.

// CHECK-LABEL: yul.func @m2s_i136
// CHECK:         yul.for
// CHECK:           %[[V:.*]] = yul.mload
// CHECK-NEXT:      %[[C16:.*]] = yul.constant 16
// CHECK-NEXT:      %[[S:.*]] = yul.signextend %[[C16]], %[[V]]
// CHECK-NEXT:      yul.sstore %{{.*}}, %[[S]]

// CHECK-LABEL: yul.func @m2s_bool
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.mload
// CHECK-NEXT:        %[[C0:.*]] = yul.constant 0
// CHECK-NEXT:        %[[B:.*]] = yul.cmp ne, %[[V]], %[[C0]]
// CHECK-NEXT:        %[[M:.*]] = yul.constant 255
// CHECK-NEXT:        yul.and %[[B]], %[[M]]

// CHECK-LABEL: yul.func @s2m_enum
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[M:.*]] = yul.constant 255
// CHECK-NEXT:        %[[V:.*]] = yul.and %{{.*}}, %[[M]]
// CHECK-NEXT:        %[[C2:.*]] = yul.constant 2
// CHECK-NEXT:        %[[BAD:.*]] = yul.cmp ugt, %[[V]], %[[C2]]
// CHECK-NEXT:        yul.if %[[BAD]]
// CHECK:               yul.revert
// CHECK:             yul.mstore %{{.*}}, %[[V]]

// CHECK-LABEL: yul.func @encode_b20
// CHECK:         yul.for
// CHECK:           %[[V:.*]] = yul.sload
// CHECK-NEXT:      %[[C96:.*]] = yul.constant 96
// CHECK-NEXT:      yul.arith_shl %[[V]], %[[C96]]

// CHECK-LABEL: yul.func @load_bool
// CHECK:         %[[M:.*]] = yul.constant 255
// CHECK-NEXT:    %[[V:.*]] = yul.and %{{.*}}, %[[M]]
// CHECK-NEXT:    yul.func_return %[[V]]

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @b slot 0 offset 0 : i1
    sol.state_var @b20 slot 1 offset 0 : !sol.array<? x !sol.fixedbytes<20>, Storage>
    sol.state_var @es slot 2 offset 0 : !sol.array<? x !sol.enum<2>, Storage>
    sol.state_var @bs slot 3 offset 0 : !sol.array<? x i1, Storage>
    sol.state_var @i136 slot 4 offset 0 : !sol.array<? x si136, Storage>
    sol.func @C() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
    sol.func @load_bool() -> i1 attributes {orig_fn_type = () -> i1, selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @b : !sol.ptr<i1, Storage>
      %1 = sol.load %0 : !sol.ptr<i1, Storage>, i1
      sol.return %1 : i1
    }
    sol.func @encode_b20() -> !sol.string<Memory> attributes {orig_fn_type = () -> !sol.string<Memory>, selector = 2 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @b20 : !sol.array<? x !sol.fixedbytes<20>, Storage>
      %1 = "sol.encode"(%0) <{operandSegmentSizes = array<i32: 1, 0>}> : (!sol.array<? x !sol.fixedbytes<20>, Storage>) -> !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
    sol.func @s2m_enum() -> !sol.array<? x !sol.enum<2>, Memory> attributes {orig_fn_type = () -> !sol.array<? x !sol.enum<2>, Memory>, selector = 3 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @es : !sol.array<? x !sol.enum<2>, Storage>
      %1 = sol.data_loc_cast %0 : !sol.array<? x !sol.enum<2>, Storage>, !sol.array<? x !sol.enum<2>, Memory>
      sol.return %1 : !sol.array<? x !sol.enum<2>, Memory>
    }
    sol.func @m2s_bool(%arg0: !sol.array<? x i1, Memory>) attributes {orig_fn_type = (!sol.array<? x i1, Memory>) -> (), selector = 4 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @bs : !sol.array<? x i1, Storage>
      sol.copy %arg0, %0 : !sol.array<? x i1, Memory>, !sol.array<? x i1, Storage>
      sol.return
    }
    sol.func @m2s_i136(%arg0: !sol.array<? x si136, Memory>) attributes {orig_fn_type = (!sol.array<? x si136, Memory>) -> (), selector = 5 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @i136 : !sol.array<? x si136, Storage>
      sol.copy %arg0, %0 : !sol.array<? x si136, Memory>, !sol.array<? x si136, Storage>
      sol.return
    }
  } {kind = #Contract}
}
