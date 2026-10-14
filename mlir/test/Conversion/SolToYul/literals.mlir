// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Literals longer than a word are codecopied from a data-in-code global;
// short ones are a single left-aligned mstore. Literals with equal content
// share one global per module, see string-literal-many.mlir.

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @short : () -> i256
    // CHECK:         %[[MEM:.*]] = yul.mload
    // CHECK:         %[[LEN:.*]] = yul.constant 5
    // CHECK:         yul.mstore %[[MEM]], %[[LEN]]
    // CHECK:         %[[DST:.*]] = yul.add %[[MEM]], %{{.*}}
    // CHECK:         %[[HELLO:.*]] = yul.constant 47219736118171679016481614208494153725245902603978864281390662590579859259392
    // CHECK:         yul.mstore %[[DST]], %[[HELLO]]
    // CHECK-NOT:     yul.codecopy
    // CHECK:         yul.func_return
    sol.func @short() -> !sol.string<Memory> {
      %0 = sol.string_lit "hello" -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
#Pure = #sol<StateMutability Pure>
module {
  // CHECK-LABEL: yul.object @Test {
  // CHECK:         yul.func_call @Test()
  // CHECK-LABEL: yul.func @Test : () -> ()
  // CHECK:         yul.func_call @longLit() : () -> i256

  // CHECK-LABEL: yul.func @longLit : () -> i256
  // CHECK:         llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
  // CHECK:         yul.codecopy
  // CHECK:       llvm.mlir.global private unnamed_addr constant @__data_in_code.0("{{a{32}b{32}c{32}d{32}z}}") {addr_space = 4 : i32}
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

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  // CHECK-LABEL: yul.object @Test_deployed {
  // CHECK-LABEL: yul.func @longLit : () -> i256
  // CHECK:         %[[LEN:.*]] = yul.constant 129
  // CHECK:         %[[MEM:.*]] = yul.func_call @__sol.alloc(
  // CHECK:         yul.mstore %[[MEM]], %[[LEN]]
  // CHECK:         %[[G:.*]] = llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
  // CHECK:         %[[GI:.*]] = llvm.ptrtoint %[[G]] : !llvm.ptr<4> to i256
  // CHECK:         %[[DST:.*]] = yul.add %[[MEM]], %{{.*}}
  // CHECK:         yul.codecopy %[[DST]], %[[GI]], %[[LEN]]
  // CHECK:       llvm.mlir.global private unnamed_addr constant @__data_in_code.0("{{a{32}b{32}c{32}d{32}z}}") {addr_space = 4 : i32}
  sol.contract @Test {
    sol.func @longLit() -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.string_lit "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbccccccccccccccccccccccccccccccccddddddddddddddddddddddddddddddddz" -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}
