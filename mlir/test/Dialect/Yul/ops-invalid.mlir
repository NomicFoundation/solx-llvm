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
