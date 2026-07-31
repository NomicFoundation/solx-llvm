// RUN: mlir-opt %s -split-input-file -verify-diagnostics

// Case values that do not fit the flag type are rejected instead of being
// silently truncated.
func.func @too_wide_case(%flag: i256) {
  cf.switch %flag : i256, [
    default: ^bb1,
    // expected-error@below {{case value does not fit the flag type}}
    0x10000000000000000000000000000000000000000000000000000000000000000: ^bb2
  ]
^bb1:
  return
^bb2:
  return
}

// -----

// The signed fit check applies to negative case values as well.
func.func @too_wide_negative_case(%flag: i32) {
  cf.switch %flag : i32, [
    default: ^bb1,
    // expected-error@below {{case value does not fit the flag type}}
    -4294967296: ^bb2
  ]
^bb1:
  return
^bb2:
  return
}
