// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// The creation code reserves a memory cell for each immutable and stores it
// into the runtime code it returns, at the offsets the runtime code loads it
// from. A library's creation code stores its own address the same way.

#Contract = #sol<ContractKind Contract>

// CHECK-LABEL: yul.object @C {
// CHECK:         yul.memoryguard 160
// CHECK:         yul.setimmutable %{{.*}}, "x", %{{.*}}

module {
  sol.contract @C {
    sol.immutable @x : ui256
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         yul.loadimmutable "x"

module {
  sol.contract @C {
    sol.immutable @x : ui256
    sol.func @get() -> ui256 attributes {orig_fn_type = () -> ui256, selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.load_immutable @x : ui256
      sol.return %0 : ui256
    }
  } {kind = #Contract, runtime}
}

// -----

#Library = #sol<ContractKind Library>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @L {
// CHECK:         yul.setimmutable %{{.*}}, "library_deploy_address", %{{.*}}

module {
  sol.contract @L {
    sol.func private @h() attributes {state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Library}
}
