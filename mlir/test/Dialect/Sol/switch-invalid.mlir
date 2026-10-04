// RUN: mlir-opt %s -split-input-file -verify-diagnostics

func.func @negative_unsigned(%arg0: ui8) {
  sol.switch %arg0 : ui8
  // expected-error@below {{case value does not fit the switch argument type}}
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
