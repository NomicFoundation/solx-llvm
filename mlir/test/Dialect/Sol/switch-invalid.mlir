// RUN: mlir-opt %s -split-input-file -verify-diagnostics

// Case values are unsigned words with no negative literals.
func.func @negative_case(%arg0: i256) {
  sol.switch %arg0 : i256
  // expected-error@below {{negative case values are not allowed}}
  case -1 {
    sol.yield
  }
  default {
    sol.yield
  }
  return
}

// -----

// A negative zero is rejected too: the minus sign itself is not allowed,
// even though the value it produces is not negative.
func.func @negative_zero_case(%arg0: i256) {
  sol.switch %arg0 : i256
  // expected-error@below {{negative case values are not allowed}}
  case -0 {
    sol.yield
  }
  default {
    sol.yield
  }
  return
}

// -----

// Case values that do not fit the switch argument are rejected instead of
// being silently truncated.
func.func @too_wide_case(%arg0: i256) {
  sol.switch %arg0 : i256
  // expected-error@below {{case value does not fit the switch argument type}}
  case 0x10000000000000000000000000000000000000000000000000000000000000000 {
    sol.yield
  }
  default {
    sol.yield
  }
  return
}
