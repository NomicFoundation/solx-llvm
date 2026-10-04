// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#Pure = #sol<StateMutability Pure>
#View = #sol<StateMutability View>
module {
  sol.contract @C {
    // Long storage bytes read their first word from keccak(slot); data shorter
    // than the target is masked to its length.
    // CHECK-LABEL: yul.func @fromStorage32 : (i256) -> i256
    // CHECK:         %[[M:.*]] = yul.constant -1{{$}}
    // CHECK:         %[[S:.*]] = yul.sload
    // CHECK:         %[[LEN:.*]] = yul.arith_select
    // CHECK:         %[[PANIC:.*]] = yul.constant 34{{$}}
    // CHECK:         yul.mstore %{{.*}}, %[[PANIC]]
    // CHECK:         %[[LONG:.*]] = yul.cmp ugt, %[[LEN]], %{{.*}}
    // CHECK:         %[[W:.*]] = yul.if %[[LONG]] -> i256 {
    // CHECK:           yul.keccak256
    // CHECK:           yul.sload
    // CHECK:         %[[V:.*]] = yul.and %[[W]], %[[M]]
    // CHECK:         %[[N:.*]] = yul.constant 32{{$}}
    // CHECK:         %[[SHORT:.*]] = yul.cmp ult, %[[LEN]], %[[N]]
    // CHECK:         %[[R:.*]] = yul.if %[[SHORT]] -> i256 {
    // CHECK:           %[[SH:.*]] = yul.mul
    // CHECK:           %[[KEEP:.*]] = yul.shl %[[SH]], %[[M]]
    // CHECK:           yul.and %[[V]], %[[KEEP]]
    // CHECK:         yul.func_return %[[R]] : i256
    sol.func @fromStorage32(%arg0: !sol.string<Storage>) -> !sol.fixedbytes<32> attributes {state_mutability = #View} {
      %0 = sol.dyn_bytes_to_fixedbytes %arg0 : <Storage> to <32>
      sol.return %0 : !sol.fixedbytes<32>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @fromCalldata16 : (!llvm.struct<(i256, i256)>) -> i256
    // CHECK:         %[[M:.*]] = yul.constant [[$B16:-340282366920938463463374607431768211456]]
    // CHECK:         %[[OFF:.*]] = llvm.extractvalue %{{.*}}[0]
    // CHECK:         %[[D:.*]] = yul.calldataload %[[OFF]]
    // CHECK:         %[[LEN:.*]] = llvm.extractvalue %{{.*}}[1]
    // CHECK:         %[[V:.*]] = yul.and %[[D]], %[[M]]
    // CHECK:         %[[N:.*]] = yul.constant 16{{$}}
    // CHECK:         %[[SHORT:.*]] = yul.cmp ult, %[[LEN]], %[[N]]
    // CHECK:         %[[R:.*]] = yul.if %[[SHORT]] -> i256 {
    // CHECK:           %[[SH:.*]] = yul.mul
    // CHECK:           %[[KEEP:.*]] = yul.arith_shl %[[M]], %[[SH]]
    // CHECK:           yul.and %[[V]], %[[KEEP]]
    // CHECK:         yul.func_return %[[R]] : i256
    sol.func @fromCalldata16(%arg0: !sol.string<CallData>) -> !sol.fixedbytes<16> attributes {state_mutability = #Pure} {
      %0 = sol.dyn_bytes_to_fixedbytes %arg0 : <CallData> to <16>
      sol.return %0 : !sol.fixedbytes<16>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @fromMemory16 : (i256) -> i256
    // CHECK:         %[[M:.*]] = yul.constant [[$B16]]
    // CHECK:         %[[D:.*]] = yul.mload
    // CHECK:         %[[LEN:.*]] = yul.mload
    // CHECK:         %[[V:.*]] = yul.and %[[D]], %[[M]]
    // CHECK:         %[[N:.*]] = yul.constant 16{{$}}
    // CHECK:         %[[SHORT:.*]] = yul.cmp ult, %[[LEN]], %[[N]]
    // CHECK:         %[[R:.*]] = yul.if %[[SHORT]] -> i256 {
    // CHECK:           %[[SH:.*]] = yul.mul
    // CHECK:           %[[KEEP:.*]] = yul.arith_shl %[[M]], %[[SH]]
    // CHECK:           yul.and %[[V]], %[[KEEP]]
    // CHECK:         yul.func_return %[[R]] : i256
    sol.func @fromMemory16(%arg0: !sol.string<Memory>) -> !sol.fixedbytes<16> attributes {state_mutability = #Pure} {
      %0 = sol.dyn_bytes_to_fixedbytes %arg0 : <Memory> to <16>
      sol.return %0 : !sol.fixedbytes<16>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
