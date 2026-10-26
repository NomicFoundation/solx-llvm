// RUN: mlir-opt %s --split-input-file --convert-yul-to-std | FileCheck %s

// Every function carries the subtarget features of the module's evm version.

// CHECK-LABEL: module @Cancun
// CHECK:         func.func @__entry() attributes {llvm.linkage = #llvm.linkage<external>, passthrough = ["nofree", "null_pointer_is_valid", "evm-entry-function"]}
// CHECK:         func.func @f() attributes {llvm.linkage = #llvm.linkage<private>, passthrough = ["nofree", "null_pointer_is_valid"]}
module attributes {sol.evm_version = #sol<EvmVersion Cancun>} {
  yul.object @Cancun {
    yul.func @f : () -> () {
      yul.func_return
    }
  }
}

// -----

// CHECK-LABEL: module @Osaka
// CHECK:         func.func @__entry() attributes {llvm.linkage = #llvm.linkage<external>, passthrough = ["nofree", "null_pointer_is_valid", ["target-features", "+osaka"], "evm-entry-function"]}
// CHECK:         func.func @f() attributes {llvm.linkage = #llvm.linkage<private>, passthrough = ["nofree", "null_pointer_is_valid", ["target-features", "+osaka"]]}
module attributes {sol.evm_version = #sol<EvmVersion Osaka>} {
  yul.object @Osaka {
    yul.func @f : () -> () {
      yul.func_return
    }
  }
}
