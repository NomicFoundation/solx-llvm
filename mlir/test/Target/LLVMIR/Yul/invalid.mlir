// RUN: mlir-translate --mlir-to-llvmir --verify-diagnostics --split-input-file %s

module {
  // expected-error @below {{LLVM Translation failed for operation: yul.object}}
  yul.object @Test {
    yul.func @__entry : () -> () {
      %c0 = yul.constant 0
      // expected-error @below {{cannot be translated to LLVM IR}}
      %0 = yul.upd_free_ptr %c0
      yul.stop
      yul.func_return
    }
  }
}

// -----

module {
  // expected-error @below {{LLVM Translation failed for operation: yul.object}}
  yul.object @Test {
    yul.func @__entry : () -> () {
      %c0 = yul.constant 0
      // expected-error @below {{expected single block regions}}
      yul.if %c0 {
        llvm.br ^bb1
      ^bb1:
        yul.yield
      } else {
      }
      yul.stop
      yul.func_return
    }
  }
}

// -----

module {
  // expected-error @below {{LLVM Translation failed for operation: yul.object}}
  yul.object @Test {
    yul.func @__entry : () -> () {
      %c0 = yul.constant 0
      // expected-error @below {{expected an else region yielding the results}}
      %0 = yul.if %c0 -> i256 {
        yul.yield %c0 : i256
      } else {
      }
      yul.stop
      yul.func_return
    }
  }
}
