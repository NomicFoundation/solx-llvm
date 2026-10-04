// RUN: mlir-opt %s -split-input-file -verify-diagnostics

// Only a signed argument takes negative case values.
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

// -----

func.func @negative_unsigned(%arg0: ui8) {
  sol.switch %arg0 : ui8
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

func.func @too_wide_unsigned(%arg0: ui8) {
  sol.switch %arg0 : ui8
  // expected-error@below {{case value does not fit the switch argument type}}
  case 256 {
    sol.yield
  }
  default {
    sol.yield
  }
  return
}

// -----

func.func @too_wide_signed(%arg0: si8) {
  sol.switch %arg0 : si8
  // expected-error@below {{case value does not fit the switch argument type}}
  case 128 {
    sol.yield
  }
  default {
    sol.yield
  }
  return
}

// -----

func.func @too_narrow_signed(%arg0: si8) {
  sol.switch %arg0 : si8
  // expected-error@below {{case value does not fit the switch argument type}}
  case -129 {
    sol.yield
  }
  default {
    sol.yield
  }
  return
}

// -----

func.func @double_minus(%arg0: si8) {
  sol.switch %arg0 : si8
  // expected-error@below {{expected integer value}}
  case --5 {
    sol.yield
  }
  default {
    sol.yield
  }
  return
}

// -----

func.func @case_count(%arg0: ui256) {
  // expected-error@below {{expects case value count to match case region count}}
  "sol.switch"(%arg0) <{cases = dense<[1, 2, 3]> : tensor<3xui256>}> ({
    sol.yield
  }, {
    sol.yield
  }) : (ui256) -> ()
  return
}

// -----

func.func @case_type(%arg0: ui256) {
  // expected-error@below {{expects case value type to match switch argument type}}
  "sol.switch"(%arg0) <{cases = dense<1> : tensor<1xui8>}> ({
    sol.yield
  }, {
    sol.yield
  }) : (ui256) -> ()
  return
}
