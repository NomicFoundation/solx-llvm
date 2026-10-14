// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Each function carries a long literal of its own and one that every function
// shares. The shared literal has a single global that all four uses address,
// and each own literal takes the next index, so the module holds one global
// per distinct literal rather than one per use.

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         yul.func @f3
// CHECK:           llvm.mlir.addressof @__data_in_code.4 : !llvm.ptr<4>
// CHECK:           llvm.mlir.addressof @__data_in_code.1 : !llvm.ptr<4>
// CHECK:         yul.func @f2
// CHECK:           llvm.mlir.addressof @__data_in_code.3 : !llvm.ptr<4>
// CHECK:           llvm.mlir.addressof @__data_in_code.1 : !llvm.ptr<4>
// CHECK:         yul.func @f1
// CHECK:           llvm.mlir.addressof @__data_in_code.2 : !llvm.ptr<4>
// CHECK:           llvm.mlir.addressof @__data_in_code.1 : !llvm.ptr<4>
// CHECK:         yul.func @f0
// CHECK:           llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
// CHECK:           llvm.mlir.addressof @__data_in_code.1 : !llvm.ptr<4>
// CHECK:         llvm.mlir.global private unnamed_addr constant @__data_in_code.0("l0_
// CHECK:         llvm.mlir.global private unnamed_addr constant @__data_in_code.1("ss
// CHECK:         llvm.mlir.global private unnamed_addr constant @__data_in_code.2("l1_
// CHECK:         llvm.mlir.global private unnamed_addr constant @__data_in_code.3("l2_
// CHECK:         llvm.mlir.global private unnamed_addr constant @__data_in_code.4("l3_
// CHECK-NOT:     llvm.mlir.global

module {
  sol.contract @C {
    sol.func @f0() attributes {state_mutability = #Pure} {
      %0 = sol.string_lit "l0_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" -> !sol.string<Memory>
      %1 = sol.string_lit "ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" -> !sol.string<Memory>
      sol.return
    }
    sol.func @f1() attributes {state_mutability = #Pure} {
      %0 = sol.string_lit "l1_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" -> !sol.string<Memory>
      %1 = sol.string_lit "ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" -> !sol.string<Memory>
      sol.return
    }
    sol.func @f2() attributes {state_mutability = #Pure} {
      %0 = sol.string_lit "l2_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" -> !sol.string<Memory>
      %1 = sol.string_lit "ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" -> !sol.string<Memory>
      sol.return
    }
    sol.func @f3() attributes {state_mutability = #Pure} {
      %0 = sol.string_lit "l3_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" -> !sol.string<Memory>
      %1 = sol.string_lit "ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" -> !sol.string<Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}
