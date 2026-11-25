// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.object @C_deployed
// CHECK:         yul.func @g
// CHECK:           llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
// CHECK:           yul.codecopy
// CHECK:         yul.func @f
// CHECK-NOT:       llvm.mlir.addressof
// CHECK:           %[[SRC:.*]] = yul.calldatasize
// CHECK:           %[[LEN:.*]] = yul.constant 66
// CHECK:           yul.calldatacopy %{{.*}}, %[[SRC]], %[[LEN]]
// CHECK-NOT:       yul.codecopy
// CHECK:         llvm.mlir.global private unnamed_addr constant @__data_in_code.0("aaaa
// CHECK-NOT:     llvm.mlir.global
module {
  sol.contract @C {
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.string_lit "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00" -> !sol.string<Memory>
      sol.return
    }
    sol.func @g() attributes {orig_fn_type = () -> (), selector = 2 : i32, state_mutability = #NonPayable} {
      %0 = sol.string_lit "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" -> !sol.string<Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}
