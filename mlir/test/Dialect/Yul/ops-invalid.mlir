// RUN: mlir-opt %s -split-input-file -verify-diagnostics

// An object is lowered into the module holding it, so it nests nothing.
module {
  // expected-error @below {{'yul.object' op expects only functions and globals, found 'yul.object'}}
  yul.object @outer {
    yul.object @inner {
      yul.func @__entry : () -> () {
        yul.func_return
      }
    }
  }
}

// -----

// A module is lowered to the code of its one object.
module {
  // expected-error @below {{'yul.object' op expects no other yul.object in its module, found 'B'}}
  yul.object @A {
    yul.func @__entry : () -> () {
      yul.func_return
    }
  }
  // expected-error @below {{'yul.object' op expects no other yul.object in its module, found 'A'}}
  yul.object @B {
    yul.func @__entry : () -> () {
      yul.func_return
    }
  }
}

// -----

// The object's code is its `__entry` function.
module {
  // expected-error @below {{'yul.object' op expects only functions and globals, found 'yul.constant'}}
  yul.object @obj {
    %c0 = yul.constant 0
    yul.func @__entry : () -> () {
      yul.func_return
    }
  }
}

// -----

module {
  // expected-error @below {{'yul.object' op expects a function named '__entry'}}
  yul.object @obj {
    yul.func @f : () -> () {
      yul.func_return
    }
  }
}

// -----

// The LLVM IR translation emits each region of a Yul region op as one block.
yul.func @if_then : (i256) -> () {
^bb0(%c: i256):
  // expected-error @below {{'yul.if' op region #0 ('thenRegion') failed to verify constraint: region with 1 blocks}}
  yul.if %c {
    yul.yield
  ^bb1:
    yul.yield
  } else {
  }
  yul.func_return
}

// -----

yul.func @if_else : (i256) -> () {
^bb0(%c: i256):
  // expected-error @below {{'yul.if' op region #1 ('elseRegion') failed to verify constraint: region with at most 1 blocks}}
  yul.if %c {
    yul.yield
  } else {
    yul.yield
  ^bb1:
    yul.yield
  }
  yul.func_return
}

// -----

yul.func @switch_case : (i256) -> () {
^bb0(%c: i256):
  // expected-error @below {{'yul.switch' op region #1 ('caseRegions') failed to verify constraint: region with 1 blocks}}
  yul.switch %c : i256
  case 1 {
    yul.yield
  ^bb1:
    yul.yield
  }
  default {
    yul.yield
  }
  yul.func_return
}

// -----

yul.func @scope : () -> () {
  // expected-error @below {{'yul.scope' op region #0 ('bodyRegion') failed to verify constraint: region with 1 blocks}}
  yul.scope {
    yul.yield
  ^bb1:
    yul.yield
  }
  yul.func_return
}

// -----

yul.func @while_body : (i256) -> () {
^bb0(%c: i256):
  // expected-error @below {{'yul.while' op region #1 ('body') failed to verify constraint: region with 1 blocks}}
  yul.while {
    yul.condition %c
  } do {
    yul.yield
  ^bb1:
    yul.yield
  }
  yul.func_return
}

// -----

yul.func @do_body : (i256) -> () {
^bb0(%c: i256):
  // expected-error @below {{'yul.do' op region #0 ('body') failed to verify constraint: region with 1 blocks}}
  yul.do {
    yul.yield
  ^bb1:
    yul.yield
  } while {
    yul.condition %c
  }
  yul.func_return
}

// -----

yul.func @for_body : (i256) -> () {
^bb0(%c: i256):
  // expected-error @below {{'yul.for' op region #1 ('body') failed to verify constraint: region with 1 blocks}}
  yul.for cond {
    yul.condition %c
  } body {
    yul.yield
  ^bb1:
    yul.yield
  } step {
    yul.yield
  }
  yul.func_return
}
