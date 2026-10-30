// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Literals longer than 64 bytes are codecopied from a data-in-code global;
// short ones are left-aligned mstores. Literals with equal content share one
// global per module, see string-literal-many.mlir.

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

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @aboveCutoff : () -> i256
    // CHECK:         %[[MEM:.*]] = yul.mload
    // CHECK:         yul.func_call @__sol.panic
    // CHECK:         yul.mstore
    // CHECK-NEXT:    %[[LEN:.*]] = yul.constant 65{{$}}
    // CHECK-NEXT:    yul.mstore %[[MEM]], %[[LEN]]
    // CHECK:         %[[DST:.*]] = yul.add %[[MEM]], %{{.*}}
    // CHECK-NEXT:    %[[G:.*]] = llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
    // CHECK-NEXT:    %[[GI:.*]] = llvm.ptrtoint %[[G]] : !llvm.ptr<4> to i256
    // CHECK-NEXT:    %[[COPY:.*]] = yul.constant 65{{$}}
    // CHECK-NEXT:    yul.codecopy %[[DST]], %[[GI]], %[[COPY]]
    // CHECK-NEXT:    yul.func_return %[[MEM]]
    // CHECK-LABEL: yul.func @atCutoff : () -> i256
    // CHECK:         %[[MEM:.*]] = yul.mload
    // CHECK:         yul.func_call @__sol.panic
    // CHECK:         yul.mstore
    // CHECK-NEXT:    %[[LEN:.*]] = yul.constant 64{{$}}
    // CHECK-NEXT:    yul.mstore %[[MEM]], %[[LEN]]
    // CHECK:         %[[DST:.*]] = yul.add %[[MEM]], %{{.*}}
    // CHECK-NEXT:    %[[A:.*]] = yul.constant 44046402572626160612103472728795008085361523578694645928734845681441465000289
    // CHECK-NEXT:    yul.mstore %[[DST]], %[[A]]
    // CHECK:         %[[DST2:.*]] = yul.add %[[DST]], %{{.*}}
    // CHECK-NEXT:    %[[B:.*]] = yul.constant 44500489197086224123568456983731039096550817636206961866144483265786222371426
    // CHECK-NEXT:    yul.mstore %[[DST2]], %[[B]]
    // CHECK-NEXT:    yul.func_return %[[MEM]]
    // CHECK:       llvm.mlir.global private unnamed_addr constant @__data_in_code.0("{{a{32}b{32}z}}") {addr_space = 4 : i32}
    sol.func @atCutoff() -> !sol.string<Memory> {
      %0 = sol.string_lit "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
    sol.func @aboveCutoff() -> !sol.string<Memory> {
      %0 = sol.string_lit "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbz" -> !sol.string<Memory>
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
  // CHECK-LABEL: yul.func @Test : () -> ()
  // CHECK:         yul.func_call @longLit() : () -> i256

  // CHECK-LABEL: yul.func @longLit : () -> i256
  // CHECK:         llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
  // CHECK:         yul.codecopy
  // CHECK:       llvm.mlir.global private unnamed_addr constant @__data_in_code.0("{{a{32}b{32}c{32}d{32}z}}") {addr_space = 4 : i32}
  // CHECK:       yul.func_call @Test()
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
  // CHECK:         %[[MEM:.*]] = yul.mload
  // CHECK:         %[[LEN:.*]] = yul.constant 129
  // CHECK:         yul.mstore %[[MEM]], %[[LEN]]
  // CHECK:         %[[DST:.*]] = yul.add %[[MEM]], %{{.*}}
  // CHECK:         %[[G:.*]] = llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
  // CHECK:         %[[GI:.*]] = llvm.ptrtoint %[[G]] : !llvm.ptr<4> to i256
  // CHECK:         %[[COPY:.*]] = yul.constant 129
  // CHECK:         yul.codecopy %[[DST]], %[[GI]], %[[COPY]]
  // CHECK-NEXT:    yul.func_return %[[MEM]]
  // CHECK:       llvm.mlir.global private unnamed_addr constant @__data_in_code.0("{{a{32}b{32}c{32}d{32}z}}") {addr_space = 4 : i32}
  sol.contract @Test {
    sol.func @longLit() -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.string_lit "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbccccccccccccccccccccccccccccccccddddddddddddddddddddddddddddddddz" -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}
