// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Value keys hash keccak256(key . slot) from scratch space; string keys hash
// keccak256(bytes . slot) built at the free memory pointer.

// CHECK-LABEL: yul.func @get_uint : (i256) -> i256
// CHECK:         yul.mstore %[[Z:.*]], %arg0
// CHECK:         yul.mstore %c32_i256, %c0_i256
// CHECK:         %[[H:.*]] = yul.keccak256 %[[Z]], %c64_i256
// CHECK:         llvm.insertvalue %[[H]], %{{.*}}[0]
// CHECK:         yul.sload

#Contract = #sol<ContractKind Contract>
module {
  sol.contract @C {
    sol.state_var @m_uint slot 0 offset 0 : !sol.mapping<ui256, ui256>
    sol.func @get_uint(%arg0: ui256) -> ui256 {
      %0 = sol.addr_of @m_uint : !sol.mapping<ui256, ui256>
      %1 = sol.map %0, %arg0 : !sol.mapping<ui256, ui256>, ui256, !sol.ptr<ui256, Storage>
      %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
      sol.return %2 : ui256
    }
  } {kind = #Contract}
}

// -----

// CHECK-LABEL: yul.func @get_addr : (i256) -> i256
// CHECK:         %[[KC:.*]] = yul.and %arg0, %c1461501637330902918203684832716283019655932542975_i256
// CHECK:         yul.mstore %[[Z:.*]], %[[KC]]
// CHECK:         yul.mstore %c32_i256, %c1_i256
// CHECK:         %[[H:.*]] = yul.keccak256 %[[Z]], %c64_i256

#Contract = #sol<ContractKind Contract>
module {
  sol.contract @C {
    sol.state_var @m_addr slot 1 offset 0 : !sol.mapping<!sol.address, ui256>
    sol.func @get_addr(%arg0: !sol.address) -> ui256 {
      %0 = sol.addr_of @m_addr : !sol.mapping<!sol.address, ui256>
      %1 = sol.map %0, %arg0 : !sol.mapping<!sol.address, ui256>, !sol.address, !sol.ptr<ui256, Storage>
      %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
      sol.return %2 : ui256
    }
  } {kind = #Contract}
}

// -----

// CHECK-LABEL: yul.func @set_string : (i256, i256) -> ()
// CHECK:         %[[BUF:.*]] = yul.mload %c64_i256
// CHECK:         %[[LEN:.*]] = yul.mload %arg0
// CHECK:         yul.mcopy %[[BUF]], %{{.*}}, %[[LEN]]
// CHECK:         %[[END:.*]] = yul.add %[[BUF]], %[[LEN]]
// CHECK:         yul.mstore %[[END]], %c2_i256
// CHECK:         %[[SZ:.*]] = yul.add %[[LEN]], %c32_i256
// CHECK:         %[[H:.*]] = yul.keccak256 %[[BUF]], %[[SZ]]
// CHECK:         llvm.insertvalue %[[H]], %{{.*}}[0]
// CHECK:         yul.sstore

#Contract = #sol<ContractKind Contract>
module {
  sol.contract @C {
    sol.state_var @m_string slot 2 offset 0 : !sol.mapping<!sol.string<Memory>, ui256>
    sol.func @set_string(%arg0: !sol.string<Memory>, %arg1: ui256) {
      %0 = sol.addr_of @m_string : !sol.mapping<!sol.string<Memory>, ui256>
      %1 = sol.map %0, %arg0 : !sol.mapping<!sol.string<Memory>, ui256>, !sol.string<Memory>, !sol.ptr<ui256, Storage>
      sol.store %arg1, %1 : ui256, !sol.ptr<ui256, Storage>
      sol.return
    }
  } {kind = #Contract}
}
