// RUN: mlir-opt %s --sccp | FileCheck %s

// SCCP rebuilds equal constants of two blocks as one at the top of the entry
// block, through the dialect's materializeConstant.

// CHECK-LABEL: sol.func @f(
// CHECK-NEXT:    %[[LIT:.*]] = sol.constant_string "abc"
// CHECK-NEXT:    cf.cond_br
// CHECK-NOT:     sol.constant_string
// CHECK:         %[[ENC:.*]] = sol.encode %[[LIT]] : (!sol.constant_string) -> !sol.string<Memory>
// CHECK-NEXT:    sol.return %[[ENC]] : !sol.string<Memory>
// CHECK-NOT:     sol.constant_string
// CHECK:         %[[ENC2:.*]] = sol.encode %[[LIT]] : (!sol.constant_string) -> !sol.string<Memory>
// CHECK-NEXT:    sol.return %[[ENC2]] : !sol.string<Memory>
sol.contract @C {
  sol.func @f(%arg0: i1) -> !sol.string<Memory> {
    cf.cond_br %arg0, ^bb1, ^bb2
  ^bb1:
    %0 = sol.constant_string "abc"
    %1 = sol.encode %0 : (!sol.constant_string) -> !sol.string<Memory>
    sol.return %1 : !sol.string<Memory>
  ^bb2:
    %2 = sol.constant_string "abc"
    %3 = sol.encode %2 : (!sol.constant_string) -> !sol.string<Memory>
    sol.return %3 : !sol.string<Memory>
  }
} {kind = #sol<ContractKind Contract>, runtime}
