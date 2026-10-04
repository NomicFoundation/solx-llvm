// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @from_uint : (i256) -> i256
    // CHECK-NEXT:  ^bb0(%arg0: i256):
    // CHECK-NEXT:    yul.func_return %arg0 : i256
    sol.func @from_uint(%arg0: ui160) -> !sol.address {
      %0 = sol.address_cast %arg0 : ui160 to !sol.address
      sol.return %0 : !sol.address
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @contract_to_payable : (i256) -> i256
    // CHECK-NEXT:  ^bb0(%arg0: i256):
    // CHECK-NEXT:    yul.func_return %arg0 : i256
    sol.func @contract_to_payable(%arg0: !sol.contract<"C">) -> !sol.address<payable> {
      %0 = sol.address_cast %arg0 : !sol.contract<"C"> to !sol.address
      %1 = sol.address_cast %0 : !sol.address to !sol.address<payable>
      sol.return %1 : !sol.address<payable>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @to_bytes20 : (i256) -> i256
    // CHECK:         %[[C96:.*]] = yul.constant 96
    // CHECK:         %[[R:.*]] = yul.arith_shl %arg0, %[[C96]]
    // CHECK:         yul.func_return %[[R]] : i256
    sol.func @to_bytes20(%arg0: !sol.address) -> !sol.fixedbytes<20> {
      %0 = sol.address_cast %arg0 : !sol.address to !sol.fixedbytes<20>
      sol.return %0 : !sol.fixedbytes<20>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // bytes20 is left-aligned: address(b) shifts it down by 96 bits.
    // CHECK-LABEL: yul.func @from_bytes20 : (i256) -> i256
    // CHECK:         %[[C96:.*]] = yul.constant 96
    // CHECK:         %[[R:.*]] = yul.arith_shr %arg0, %[[C96]]
    // CHECK:         yul.func_return %[[R]] : i256
    sol.func @from_bytes20(%arg0: !sol.fixedbytes<20>) -> !sol.address {
      %0 = sol.address_cast %arg0 : !sol.fixedbytes<20> to !sol.address
      sol.return %0 : !sol.address
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // bytes3 widened to bytes8 is cleaned to its top 3 bytes first.
    // CHECK-LABEL: yul.func @band_diff : (i256, i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[A:.*]]: i256, %[[B:.*]]: i256):
    // CHECK:         %[[M3:.*]] = yul.constant -6901746346790563787434755862277025452451108972170386555162524223799296{{$}}
    // CHECK:         %[[CA:.*]] = yul.and %[[A]], %[[M3]]
    // CHECK:         %[[R:.*]] = yul.and %[[CA]], %[[B]]
    // CHECK:         yul.func_return %[[R]] : i256
    sol.func @band_diff(%arg0: !sol.fixedbytes<3>, %arg1: !sol.fixedbytes<8>) -> !sol.fixedbytes<8> {
      %0 = sol.bytes_cast %arg0 : !sol.fixedbytes<3> to !sol.fixedbytes<8>
      %1 = sol.and %0, %arg1 : !sol.fixedbytes<8>
      sol.return %1 : !sol.fixedbytes<8>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
