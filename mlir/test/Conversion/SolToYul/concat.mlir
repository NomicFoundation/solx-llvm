// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // Each part is copied after the previous one; the length is stored last.
    // Fixed bytes are masked to their width and advance by it. Storage bytes
    // decode the packed length through the length helper, which raises the
    // corrupted-encoding panic 34, and copy through the bytes helper.
    // CHECK-LABEL: yul.func @__sol.storage_string_length : (i256) -> i256
    // CHECK:         yul.constant 127{{$}}
    // CHECK:         yul.arith_select
    // CHECK:         yul.constant 34{{$}}
    // CHECK:         yul.func_call @__sol.panic
    // CHECK-LABEL: yul.func @f : (i256, !llvm.struct<(i256, i256)>, i256, i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[MEM:.*]]: i256, %[[CD:.*]]: !llvm.struct<(i256, i256)>, %[[FB:.*]]: i256, %[[ST:.*]]: i256):
    // CHECK:         %[[BUF:.*]] = yul.mload
    // CHECK:         %[[DATA:.*]] = yul.add %[[BUF]], %{{.*}}
    // CHECK:         %[[LA:.*]] = yul.mload %[[MEM]]
    // CHECK:         yul.mcopy %[[DATA]], %{{.*}}, %[[LA]]
    // CHECK:         %[[P1:.*]] = yul.add %[[DATA]], %[[LA]]
    // CHECK:         %[[LB:.*]] = llvm.extractvalue %[[CD]][1]
    // CHECK:         %[[OB:.*]] = llvm.extractvalue %[[CD]][0]
    // CHECK:         yul.calldatacopy %[[P1]], %[[OB]], %[[LB]]
    // CHECK:         %[[P2:.*]] = yul.add %[[P1]], %[[LB]]
    // CHECK:         %[[M16:.*]] = yul.constant -340282366920938463463374607431768211456
    // CHECK:         %[[C:.*]] = yul.and %[[FB]], %[[M16]]
    // CHECK:         yul.mstore %[[P2]], %[[C]]
    // CHECK:         %[[C16:.*]] = yul.constant 16{{$}}
    // CHECK:         %[[P3:.*]] = yul.add %[[P2]], %[[C16]]
    // CHECK:         %[[S:.*]] = yul.sload %[[ST]]
    // CHECK:         %[[LD:.*]] = yul.func_call @__sol.storage_string_length(%[[S]])
    // CHECK:         yul.func_call @__sol.copy_string_bytes.storage.memory(%[[ST]], %[[S]], %[[LD]], %[[P3]])
    // CHECK:         %[[END:.*]] = yul.add %[[P3]], %[[LD]]
    // CHECK:         %[[LEN:.*]] = yul.sub %[[END]], %[[DATA]]
    // CHECK:         yul.mstore %[[BUF]], %[[LEN]]
    sol.func @f(%arg0: !sol.string<Memory>, %arg1: !sol.string<CallData>, %arg2: !sol.fixedbytes<16>, %arg3: !sol.string<Storage>) -> !sol.string<Memory> attributes {state_mutability = #NonPayable} {
      %0 = sol.concat %arg0, %arg1, %arg2, %arg3 : !sol.string<Memory>, !sol.string<CallData>, !sol.fixedbytes<16>, !sol.string<Storage> -> <Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @empty : () -> i256
    // CHECK:         %[[BUF:.*]] = yul.mload
    // CHECK:         %[[DATA:.*]] = yul.add %[[BUF]], %{{.*}}
    // CHECK:         %[[LEN:.*]] = yul.sub %[[DATA]], %[[DATA]]
    // CHECK:         yul.mstore %[[BUF]], %[[LEN]]
    sol.func @empty() -> !sol.string<Memory> attributes {state_mutability = #NonPayable} {
      %0 = sol.concat -> <Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
