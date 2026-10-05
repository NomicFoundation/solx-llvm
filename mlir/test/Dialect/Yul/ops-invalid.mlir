// RUN: mlir-opt %s -split-input-file -verify-diagnostics

// An object is lowered into the module holding it.
module {
  "yul.object"() ({
    // expected-error @below {{'yul.object' op expects parent op 'builtin.module'}}
    "yul.object"() ({
      %c0 = yul.constant 0
      yul.revert %c0, %c0
    }) {sym_name = "inner"} : () -> ()
  }) {sym_name = "outer"} : () -> ()
}

// -----

// A module is lowered to the code of its one object.
module {
  // expected-error @below {{'yul.object' op expects no other yul.object in its module, found 'B'}}
  "yul.object"() ({
    %c0 = yul.constant 0
    yul.revert %c0, %c0
  }) {sym_name = "A"} : () -> ()
  // expected-error @below {{'yul.object' op expects no other yul.object in its module, found 'A'}}
  "yul.object"() ({
    %c0 = yul.constant 0
    yul.revert %c0, %c0
  }) {sym_name = "B"} : () -> ()
}
