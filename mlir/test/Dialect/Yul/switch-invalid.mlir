// RUN: mlir-opt %s -split-input-file -verify-diagnostics

// Yul integers are unsigned words with no negative literals.
func.func @negative_case(%arg0: i256) {
  yul.switch %arg0 : i256
  // expected-error@below {{negative case values are not allowed}}
  case -1 {
    yul.yield
  }
  default {
    yul.yield
  }
  return
}

// -----

// Case values that do not fit the switch argument are rejected instead of
// being silently truncated.
func.func @too_wide_case(%arg0: i256) {
  yul.switch %arg0 : i256
  // expected-error@below {{case value does not fit the switch argument type}}
  case 0x10000000000000000000000000000000000000000000000000000000000000000 {
    yul.yield
  }
  default {
    yul.yield
  }
  return
}
