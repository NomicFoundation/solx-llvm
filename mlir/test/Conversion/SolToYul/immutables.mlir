// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// The creation code reserves a memory cell for each immutable, a word apart in
// declaration order, writes one through its cell, and stores each into the
// runtime code it returns, at the offsets the runtime code loads it from. A
// library's creation code stores its own address the same way.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C {
// CHECK:         yul.func @ctor
// CHECK:           %[[CELL:.*]] = yul.constant 160
// CHECK:           yul.mstore %[[CELL]], %{{.*}}
// CHECK:         yul.memoryguard 192
// CHECK:         yul.func_call @ctor()
// CHECK:         %[[X:.*]] = yul.constant 128
// CHECK-NEXT:    %[[X_VALUE:.*]] = yul.mload %[[X]]
// CHECK-NEXT:    yul.setimmutable %{{.*}}, "x", %[[X_VALUE]]
// CHECK-NEXT:    %[[Y:.*]] = yul.constant 160
// CHECK-NEXT:    %[[Y_VALUE:.*]] = yul.mload %[[Y]]
// CHECK-NEXT:    yul.setimmutable %{{.*}}, "y", %[[Y_VALUE]]

module {
  sol.contract @C {
    sol.immutable @x index 0 : ui256
    sol.immutable @y index 1 : ui256
    sol.func @ctor() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      %0 = sol.addr_of @y : !sol.ptr<ui256, Immutable>
      %1 = sol.constant 7 : ui256
      sol.store %1, %0 : ui256, !sol.ptr<ui256, Immutable>
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         yul.func @get
// CHECK:           yul.loadimmutable "x"
// CHECK:         yul.memoryguard 128

module {
  sol.contract @C {
    sol.immutable @x index 0 : ui256
    sol.func @get() -> ui256 attributes {orig_fn_type = () -> ui256, selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.load_immutable @x : ui256
      sol.return %0 : ui256
    }
  } {kind = #Contract, runtime}
}

// -----

#Library = #sol<ContractKind Library>

// CHECK-LABEL: yul.object @L {
// CHECK:         yul.setimmutable %{{.*}}, "library_deploy_address", %{{.*}}

module {
  sol.contract @L {
  } {kind = #Library}
}
