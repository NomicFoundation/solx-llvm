// RUN: mlir-opt %s -split-input-file -verify-diagnostics

// Case values that do not fit the flag type are rejected instead of being
// silently truncated.
llvm.func @too_wide_case(%flag: i256) {
  llvm.switch %flag : i256, ^bb1 [
    // expected-error@below {{case value does not fit the flag type}}
    0x10000000000000000000000000000000000000000000000000000000000000000: ^bb1
  ]
^bb1:
  llvm.return
}

// -----

llvm.func @too_wide_negative_case(%flag: i8) {
  llvm.switch %flag : i8, ^bb1 [
    // expected-error@below {{case value does not fit the flag type}}
    -129: ^bb1
  ]
^bb1:
  llvm.return
}
