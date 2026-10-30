// RUN: mlir-opt --convert-yul-to-std %s | FileCheck %s

// The entry function leads the module and is the only one
// marked as the start of the code.

// CHECK-LABEL: module @obj {
// CHECK-NEXT:    func.func @__entry() attributes {llvm.linkage = #llvm.linkage<external>, passthrough = ["nofree", "null_pointer_is_valid", ["target-features", "+osaka"], "evm-entry-function"]}
// CHECK:         func.func @f() attributes {llvm.linkage = #llvm.linkage<private>, passthrough = ["nofree", "null_pointer_is_valid", ["target-features", "+osaka"]]}
module {
  "yul.object"() ({
    yul.func @f : () -> () {
      yul.func_return
    }
    %c0 = yul.constant 0
    yul.revert %c0, %c0
  }) {sym_name = "obj"} : () -> ()
}
