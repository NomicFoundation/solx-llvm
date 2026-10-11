// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.func @encode
// CHECK:         [[START:%.+]] = yul.mload %c64
// CHECK:         [[SELECTOR_ADDR:%.+]] = yul.add [[START]], %c32
// CHECK:         yul.mstore %c64
// CHECK:         yul.sload
// CHECK:         [[HASH:%.+]] = yul.keccak256
// CHECK:         [[SELECTOR:%.+]] = yul.and [[HASH]], %c-26959946667150639794667015087019630673637144422540572481103610249216
// CHECK-NEXT:    [[WORD:%.+]] = yul.mload [[SELECTOR_ADDR]]
// CHECK:         [[DATA:%.+]] = yul.and [[WORD]], %c26959946667150639794667015087019630673637144422540572481103610249215
// CHECK-NEXT:    [[MERGED:%.+]] = yul.or [[DATA]], [[SELECTOR]]
// CHECK-NEXT:    yul.mstore [[SELECTOR_ADDR]], [[MERGED]]
// CHECK-NEXT:    yul.func_return [[START]]
sol.contract @Encode {
  sol.state_var @signature slot 0 offset 0 : !sol.string<Storage>
  sol.func @encode(%value: ui256) -> !sol.string<Memory> attributes {orig_fn_type = (ui256) -> !sol.string<Memory>, selector = 1 : i32, state_mutability = #NonPayable} {
    %signature = sol.addr_of @signature : !sol.string<Storage>
    %encoded = sol.encode selector(%signature) %value : !sol.string<Storage> ui256 : !sol.string<Memory>
    sol.return %encoded : !sol.string<Memory>
  }
} {kind = #Contract}
