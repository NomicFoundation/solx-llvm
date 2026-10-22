// RUN: mlir-opt --convert-yul-to-std %s | FileCheck %s

// A global the object holds lands in its module with the functions.

// CHECK-LABEL: module @obj {
// CHECK-NEXT:    func.func @__entry()
// CHECK:         llvm.mlir.global private unnamed_addr constant @data("ab") {addr_space = 4 : i32}
module {
  "yul.object"() ({
    llvm.mlir.global private unnamed_addr constant @data("ab") {addr_space = 4 : i32} : !llvm.array<2 x i8>
    %c0 = yul.constant 0
    yul.revert %c0, %c0
  }) {sym_name = "obj"} : () -> ()
}
