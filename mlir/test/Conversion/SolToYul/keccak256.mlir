// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.func @hashes
// CHECK:         [[SCRATCH:%.+]] = yul.mload %c64
// CHECK:         [[PACKED:%.+]] = yul.keccak256 [[SCRATCH]],
// CHECK-NEXT:    yul.add %arg2, %arg2
// CHECK:         [[LENGTH:%.+]] = yul.mload %arg1
// CHECK:         [[HASH:%.+]] = yul.keccak256 %{{.+}}, [[LENGTH]]
// CHECK:         yul.log %{{.+}}, %{{.+}} topics(%{{.+}}, [[PACKED]], [[HASH]])
sol.contract @Keccak256 {
  sol.func @hashes(%values: !sol.array<? x ui256, Memory>, %data: !sol.string<Memory>, %value: ui256) attributes {orig_fn_type = (!sol.array<? x ui256, Memory>, !sol.string<Memory>, ui256) -> (), selector = 1 : i32, state_mutability = #NonPayable} {
    %packed = "sol.keccak256"(%values) : (!sol.array<? x ui256, Memory>) -> !sol.fixedbytes<32>
    %sum = sol.cadd %value, %value : ui256
    %hash = "sol.keccak256"(%data) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
    sol.emit "Hashed(uint256[],bytes,uint256)" indexed = [%packed, %hash] non_indexed = [%sum] : !sol.fixedbytes<32>, !sol.fixedbytes<32>, ui256
    sol.return
  }
} {kind = #Contract}
