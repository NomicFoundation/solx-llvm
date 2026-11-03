// RUN: mlir-translate --mlir-to-llvmir --split-input-file %s | FileCheck %s

// A runtime object is recorded on the LLVM module as the 'evm.runtime' named
// metadata, with no value: its presence is the marker.

// CHECK-LABEL: define void @__entry
// CHECK: !evm.runtime = !{}
module {
  yul.object @C_deployed {
    yul.func @__entry : () -> () {
      yul.stop
    }
  } {runtime}
}

// -----

// A deploy object carries no marker.

// CHECK-LABEL: define void @__entry
// CHECK-NOT: !evm.runtime
module {
  yul.object @C {
    yul.func @__entry : () -> () {
      yul.stop
    }
  }
}
