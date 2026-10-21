// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// A constant string holds its bytes in its attribute, escaped where they are
// not printable. The second mlir-opt proves the printed form is itself
// parseable.

// CHECK-LABEL: sol.func @f(
// CHECK-NEXT:    %[[SPACED:.*]] = sol.constant_string "a b"
// CHECK-NEXT:    %[[BINARY:.*]] = sol.constant_string "\FF\00"
// CHECK-NEXT:    %[[EMPTY:.*]] = sol.constant_string ""
// CHECK-NEXT:    sol.encode %[[SPACED]], %[[BINARY]], %[[EMPTY]] : (!sol.constant_string, !sol.constant_string, !sol.constant_string) -> !sol.string<Memory>
sol.contract @C {
  sol.func @f() -> !sol.string<Memory> {
    %0 = sol.constant_string "a b"
    %1 = sol.constant_string "\FF\00"
    %2 = sol.constant_string ""
    %3 = sol.encode %0, %1, %2 : (!sol.constant_string, !sol.constant_string, !sol.constant_string) -> !sol.string<Memory>
    sol.return %3 : !sol.string<Memory>
  }
} {kind = #sol<ContractKind Contract>, runtime}
