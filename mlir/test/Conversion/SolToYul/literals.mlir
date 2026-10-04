// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Literals longer than a word are codecopied from a data-in-code global;
// short ones are a single left-aligned mstore. Every object that holds a copy
// of a long literal gets its own global.

// CHECK-LABEL: yul.func @short : () -> i256
// CHECK:         %[[MEM:.*]] = yul.mload
// CHECK:         %[[LEN:.*]] = yul.constant 5
// CHECK:         yul.mstore %[[MEM]], %[[LEN]]
// CHECK:         %[[DST:.*]] = yul.add %[[MEM]], %{{.*}}
// CHECK:         %[[HELLO:.*]] = yul.constant 47219736118171679016481614208494153725245902603978864281390662590579859259392
// CHECK:         yul.mstore %[[DST]], %[[HELLO]]
// CHECK-NOT:     yul.codecopy
// CHECK:         yul.func_return

// CHECK-LABEL: yul.object @Test {
// CHECK:         llvm.mlir.global private unnamed_addr constant @__data_in_code__0("{{a{32}b{32}c{32}d{32}z}}") {addr_space = 4 : i32}
// CHECK:         yul.func_call @Test()
// CHECK-LABEL: yul.func @Test : () -> ()
// CHECK:         yul.func_call @longLit() : () -> i256

// CHECK-LABEL: yul.object @Test_deployed {
// CHECK:         llvm.mlir.global private unnamed_addr constant @__data_in_code__0("{{a{32}b{32}c{32}d{32}z}}") {addr_space = 4 : i32}
// CHECK-LABEL: yul.func @longLit : () -> i256
// CHECK:         %[[LEN:.*]] = yul.constant 129
// CHECK:         %[[MEM:.*]] = yul.mload
// CHECK:         yul.mstore %[[MEM]], %[[LEN]]
// CHECK:         %[[G:.*]] = llvm.mlir.addressof @__data_in_code__0 : !llvm.ptr<4>
// CHECK:         %[[GI:.*]] = llvm.ptrtoint %[[G]] : !llvm.ptr<4> to i256
// CHECK:         %[[DST:.*]] = yul.add %[[MEM]], %{{.*}}
// CHECK:         yul.codecopy %[[DST]], %[[GI]], %[[LEN]]

// CHECK-LABEL: yul.func @longLit : () -> i256
// CHECK:         llvm.mlir.addressof @__data_in_code__0 : !llvm.ptr<4>
// CHECK:         yul.codecopy

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @short() -> !sol.string<Memory> {
    %0 = sol.string_lit "hello" -> !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.contract @Test {
    sol.func @longLit() -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.string_lit "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbccccccccccccccccccccccccccccccccddddddddddddddddddddddddddddddddz" -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
    sol.func @Test() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      %0 = sol.call @longLit() : () -> !sol.string<Memory>
      sol.return
    }
  } {kind = #Contract}
}
