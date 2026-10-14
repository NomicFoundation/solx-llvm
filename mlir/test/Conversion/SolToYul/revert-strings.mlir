// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Splits: revert("oops") under Default, Debug and Strip. The ctor callvalue
// check stands for every compiler-generated revert.

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>

// Default: compiler-generated reverts carry no data; user strings are kept.
// CHECK-LABEL: sol.revert_strings = #Default} {
// CHECK:         yul.object @C {
// CHECK:           %[[CV:.*]] = yul.cmp ne, %{{.*}}, %{{.*}}
// CHECK:           yul.if %[[CV]] {
// CHECK-NEXT:        %[[Z:.*]] = yul.constant 0
// CHECK-NEXT:        yul.revert %[[Z]], %[[Z]]
// CHECK:           yul.func @f
// CHECK:             yul.mstore %{{.*}}, %c3963877391197344453575983046348115674221700746820753546331534351508065746944_i256
// CHECK:             yul.mstore %{{.*}}, %c4_i256
// CHECK:             yul.mstore %{{.*}}, %c50403622312917677035490496883056546535118835118647273693795073633902808530944_i256
// CHECK:             yul.revert
module attributes {sol.revert_strings = #Default} {
  sol.contract @C {
    sol.func @f() {
      sol.revert "oops"
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#Debug = #sol<RevertStrings Debug>

// Debug: compiler-generated reverts get Error(string) reasons.
// CHECK-LABEL: sol.revert_strings = #Debug} {
// CHECK:         yul.object @C {
// CHECK:           %[[CV:.*]] = yul.cmp ne, %{{.*}}, %{{.*}}
// CHECK:           yul.if %[[CV]] {
// CHECK:             yul.mstore %{{.*}}, %c3963877391197344453575983046348115674221700746820753546331534351508065746944_i256
// CHECK:             yul.mstore %{{.*}}, %c34_i256
// CHECK:             yul.mstore %{{.*}}, %c31415261328353303702084310916408897443248934326374928715502706161730952852585_i256
// CHECK:             yul.mstore %{{.*}}, %c50401079369868191385693144506192493582494805642273906399376938498073271730176_i256
// CHECK:             yul.revert
// CHECK:           yul.func @f
// CHECK:             yul.mstore %{{.*}}, %c4_i256
// CHECK:             yul.mstore %{{.*}}, %c50403622312917677035490496883056546535118835118647273693795073633902808530944_i256
// CHECK:             yul.revert
module attributes {sol.revert_strings = #Debug} {
  sol.contract @C {
    sol.func @f() {
      sol.revert "oops"
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#Strip = #sol<RevertStrings Strip>

// Strip: user strings are dropped too.
// CHECK-LABEL: sol.revert_strings = #Strip} {
// CHECK:         yul.object @C {
// CHECK:           %[[CV:.*]] = yul.cmp ne, %{{.*}}, %{{.*}}
// CHECK:           yul.if %[[CV]] {
// CHECK-NEXT:        %[[Z:.*]] = yul.constant 0
// CHECK-NEXT:        yul.revert %[[Z]], %[[Z]]
// CHECK:           yul.func @f : () -> () {
// CHECK-NEXT:        %[[Z:.*]] = yul.constant 0
// CHECK-NEXT:        yul.revert %[[Z]], %[[Z]]
// CHECK-NEXT:      }
module attributes {sol.revert_strings = #Strip} {
  sol.contract @C {
    sol.func @f() {
      sol.revert "oops"
    }
  } {kind = #Contract}
}
