// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A dot separates the index of a string literal global, and no Solidity name
// can carry one: a function symbol holds its parameter list, an assembly
// symbol lives in the inline_asm table. So a symbol of the old underscore
// shape is a different symbol, and both survive the lowering.

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         yul.func @__data_in_code_0
// CHECK:           llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
// CHECK:         llvm.mlir.global private unnamed_addr constant @__data_in_code.0("cccc
// CHECK-NOT:     llvm.mlir.global

module {
  sol.contract @C {
    sol.func @__data_in_code_0() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.string_lit "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc" -> !sol.string<Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}
