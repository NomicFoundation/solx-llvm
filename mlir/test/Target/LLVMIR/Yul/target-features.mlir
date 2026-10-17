// RUN: mlir-translate --mlir-to-llvmir --split-input-file %s | FileCheck %s

// Every function carries the subtarget features of the module's evm version.

// CHECK: define void @__entry() #[[$CANCUN_ENTRY:[0-9]+]]
// CHECK: define private void @f() #[[$CANCUN_FN:[0-9]+]]
// CHECK: attributes #[[$CANCUN_ENTRY]] = { nofree null_pointer_is_valid "evm-entry-function" }
// CHECK: attributes #[[$CANCUN_FN]] = { nofree null_pointer_is_valid }
module attributes {sol.evm_version = #sol<EvmVersion Cancun>} {
  yul.object @Cancun {
    yul.func @__entry : () -> () {
      yul.stop
    }
    yul.func @f : () -> () {
      yul.func_return
    }
  }
}

// -----

// CHECK: define void @__entry() #[[$OSAKA_ENTRY:[0-9]+]]
// CHECK: define private void @f() #[[$OSAKA_FN:[0-9]+]]
// CHECK: attributes #[[$OSAKA_ENTRY]] = { nofree null_pointer_is_valid "evm-entry-function" "target-features"="+osaka" }
// CHECK: attributes #[[$OSAKA_FN]] = { nofree null_pointer_is_valid "target-features"="+osaka" }
module attributes {sol.evm_version = #sol<EvmVersion Osaka>} {
  yul.object @Osaka {
    yul.func @__entry : () -> () {
      yul.stop
    }
    yul.func @f : () -> () {
      yul.func_return
    }
  }
}
