// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A string literal over 64 bytes is data in the code, which the object that
// copies it holds in a global of its own, so the copy binds to its data
// section. Two uses of one literal share its global, and a different literal
// gets the next one.

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         yul.func @h
// CHECK:           llvm.mlir.addressof @__data_in_code.1 : !llvm.ptr<4>
// CHECK:           yul.codecopy
// CHECK:         yul.func @g
// CHECK:           llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
// CHECK:           yul.codecopy
// CHECK:         yul.func @f
// CHECK:           llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
// CHECK:           yul.codecopy
// CHECK:         llvm.mlir.global private unnamed_addr constant @__data_in_code.0("aaaa
// CHECK:         llvm.mlir.global private unnamed_addr constant @__data_in_code.1("bbbb
// CHECK-NOT:     llvm.mlir.global
module {
  sol.contract @C {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.string_lit "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" -> !sol.string<Memory>
      sol.return
    }
    sol.func @g() attributes {orig_fn_type = () -> (), selector = 2 : i32, state_mutability = #NonPayable} {
      %0 = sol.string_lit "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" -> !sol.string<Memory>
      sol.return
    }
    sol.func @h() attributes {orig_fn_type = () -> (), selector = 3 : i32, state_mutability = #NonPayable} {
      %0 = sol.string_lit "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" -> !sol.string<Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}
