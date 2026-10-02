// RUN: mlir-opt --convert-yul-to-std %s | FileCheck %s

// The entry function of each object leads its module and is the only one
// marked as the start of the code.

// CHECK-LABEL: module @obj {
// CHECK-NEXT:    func.func @__entry() attributes {llvm.linkage = #llvm.linkage<external>, passthrough = ["nofree", "null_pointer_is_valid", "evm-entry-function"]}
// CHECK:         module @obj_deployed {
// CHECK-NEXT:      func.func @__entry() attributes {llvm.linkage = #llvm.linkage<external>, passthrough = ["nofree", "null_pointer_is_valid", "evm-entry-function"]}
// CHECK:           func.func @".unreachable"() attributes {llvm.linkage = #llvm.linkage<private>, passthrough = ["nofree", "null_pointer_is_valid"]}
// CHECK:         func.func @".unreachable"() attributes {llvm.linkage = #llvm.linkage<private>, passthrough = ["nofree", "null_pointer_is_valid"]}
module {
  "yul.object"() ({
    %c0 = yul.constant 0
    yul.revert %c0, %c0
    "yul.object"() ({
      %c1 = yul.constant 0
      yul.revert %c1, %c1
    }) {sym_name = "obj_deployed"} : () -> ()
  }) {sym_name = "obj"} : () -> ()
}
