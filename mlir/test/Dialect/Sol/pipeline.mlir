// RUN: mlir-opt %s --sol-to-yul-pipeline --dump-pass-pipeline 2>&1 >/dev/null | FileCheck %s

// CHECK:      builtin.module(
// CHECK-NEXT:   sol-inline-modifiers,
// CHECK-NEXT:   sol.contract(
// CHECK-NEXT:     sol.func(
// CHECK-NEXT:       canonicalize{{{.*}}}
// CHECK-NEXT:     )
// CHECK-NEXT:   ),
// CHECK-NEXT:   convert-sol-to-yul,
// CHECK-NEXT:   yul.object(
// CHECK-NEXT:     yul.func(
// CHECK-NEXT:       canonicalize{{{.*}}}
// CHECK-NEXT:     )
// CHECK-NEXT:   )
// CHECK-NEXT: )

module {
  sol.contract @C {
  } {kind = #sol<ContractKind Contract>}
}
