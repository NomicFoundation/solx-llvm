// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A string literal over 128 bytes is data in the code, which the object that
// copies it holds in a global of its own, so the copy binds to its data section.

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         yul.func @f
// CHECK:           llvm.mlir.addressof @[[DATA:__data_in_code_[_0-9]+]] : !llvm.ptr<4>
// CHECK:           yul.codecopy
// CHECK:         llvm.mlir.global private unnamed_addr constant @[[DATA]]("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") {addr_space = 4 : i32}
module {
  sol.contract @C {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.string_lit "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" -> !sol.string<Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}
