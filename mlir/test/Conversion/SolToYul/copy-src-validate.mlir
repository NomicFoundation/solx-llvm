// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// Array copies into storage that convert the element type read each source
// element with the source element type, then convert to the destination
// element type. Each copy is outlined as the `__sol.copy_array` helper of its
// type pair, so the checks read the helper that the function calls.

// Same-type copies into an unpacked element store the cleaned word unmasked.
// CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.array$_dyn_si136_$_CallData_$.array$_dyn_si136_$_Storage_$
// CHECK:           %[[V:.*]] = yul.calldataload
// CHECK-NEXT:      %[[C16:.*]] = yul.constant 16
// CHECK-NEXT:      %[[S:.*]] = yul.signextend %[[C16]], %[[V]]
// CHECK-NEXT:      yul.cmp ne, %[[V]], %[[S]]
// CHECK:           yul.revert
// CHECK:           yul.sstore %{{.*}}, %[[S]]

// CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_dyn_si136_$_Memory_$.array$_dyn_si136_$_Storage_$
// CHECK:         yul.for
// CHECK:         yul.for
// CHECK:           %[[V:.*]] = yul.mload
// CHECK-NEXT:      %[[C16:.*]] = yul.constant 16
// CHECK-NEXT:      %[[S:.*]] = yul.signextend %[[C16]], %[[V]]
// CHECK-NEXT:      yul.sstore %{{.*}}, %[[S]]

// CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_dyn_si8_$_Memory_$.array$_dyn_si136_$_Storage_$
// CHECK:         yul.for
// CHECK:           %[[V:.*]] = yul.mload
// CHECK-NEXT:      %[[C0:.*]] = yul.constant 0
// CHECK-NEXT:      %[[S:.*]] = yul.signextend %[[C0]], %[[V]]
// CHECK-NEXT:      yul.sstore %{{.*}}, %[[S]]

// CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.array$_dyn_si8_$_CallData_$.array$_dyn_si16_$_Storage_$
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.calldataload
// CHECK-NEXT:        %[[C0:.*]] = yul.constant 0
// CHECK-NEXT:        %[[S:.*]] = yul.signextend %[[C0]], %[[V]]
// CHECK-NEXT:        yul.cmp ne, %[[V]], %[[S]]
// CHECK:             yul.revert
// CHECK:             %[[M:.*]] = yul.constant 65535
// CHECK-NEXT:        yul.and %[[S]], %[[M]]

// Packed -> unpacked storage: sign-extend the int8 field into int136.
// CHECK-LABEL: yul.func @__sol.copy_array.storage.storage.array$_dyn_si8_$_Storage_$.array$_dyn_si136_$_Storage_$
// CHECK:           %[[V:.*]] = yul.arith_shr
// CHECK-NEXT:      %[[C0:.*]] = yul.constant 0
// CHECK-NEXT:      %[[S:.*]] = yul.signextend %[[C0]], %[[V]]
// CHECK-NEXT:      yul.sstore %{{.*}}, %[[S]]

// Packed -> packed storage repack: sign-extend the int8 field into int16.
// CHECK-LABEL: yul.func @__sol.copy_array.storage.storage.array$_dyn_si8_$_Storage_$.array$_dyn_si16_$_Storage_$
// CHECK:           %[[M:.*]] = yul.constant 255
// CHECK-NEXT:      %[[V:.*]] = yul.and %{{.*}}, %[[M]]
// CHECK-NEXT:      %[[C0:.*]] = yul.constant 0
// CHECK-NEXT:      %[[S:.*]] = yul.signextend %[[C0]], %[[V]]
// CHECK-NEXT:      %[[M16:.*]] = yul.constant 65535
// CHECK-NEXT:      yul.and %[[S]], %[[M16]]

// bytes17 storage is right-aligned: left-align it as bytes17 for bytes32.
// CHECK-LABEL: yul.func @__sol.copy_array.storage.storage.array$_dyn_fixedbytes$_17_$_$_Storage_$.array$_dyn_fixedbytes$_32_$_$_Storage_$
// CHECK:         yul.for
// CHECK:           %[[V:.*]] = yul.sload
// CHECK-NEXT:      %[[C120:.*]] = yul.constant 120
// CHECK-NEXT:      yul.arith_shl %[[V]], %[[C120]]
// CHECK:           yul.sstore

// CHECK-LABEL: yul.func @__sol.copy_array.storage.storage.array$_dyn_si136_$_Storage_$.array$_dyn_si256_$_Storage_$
// CHECK:         yul.for
// CHECK:           %[[V:.*]] = yul.sload
// CHECK-NEXT:      %[[C16:.*]] = yul.constant 16
// CHECK-NEXT:      yul.signextend %[[C16]], %[[V]]
// CHECK:           yul.sstore

// CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_dyn_ui8_$_Memory_$.array$_dyn_ui136_$_Storage_$
// CHECK:         yul.for
// CHECK:           %[[V:.*]] = yul.mload
// CHECK-NEXT:      %[[M:.*]] = yul.constant 255
// CHECK-NEXT:      yul.and %[[V]], %[[M]]
// CHECK:           yul.sstore

// CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.array$_dyn_fixedbytes$_15_$_$_CallData_$.array$_dyn_fixedbytes$_17_$_$_Storage_$
// CHECK:         yul.for
// CHECK:           %[[V:.*]] = yul.calldataload
// CHECK-NEXT:      %[[M:.*]] = yul.constant -87112285931760246646623899502532662132736
// CHECK-NEXT:      %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK-NEXT:      yul.cmp ne, %[[V]], %[[C]]
// CHECK:           %[[C120:.*]] = yul.constant 120
// CHECK-NEXT:      yul.arith_shr %[[C]], %[[C120]]
// CHECK:           yul.sstore

// CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_dyn_fixedbytes$_15_$_$_Memory_$.array$_dyn_fixedbytes$_16_$_$_Storage_$
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.mload
// CHECK-NEXT:        %[[M:.*]] = yul.constant -87112285931760246646623899502532662132736
// CHECK-NEXT:        %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK-NEXT:        %[[C128:.*]] = yul.constant 128
// CHECK-NEXT:        yul.arith_shr %[[C]], %[[C128]]

// CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_dyn_si8_$_Memory_$.array$_dyn_si16_$_Storage_$
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.mload
// CHECK-NEXT:        %[[C0:.*]] = yul.constant 0
// CHECK-NEXT:        %[[S:.*]] = yul.signextend %[[C0]], %[[V]]
// CHECK-NEXT:        %[[M:.*]] = yul.constant 65535
// CHECK-NEXT:        yul.and %[[S]], %[[M]]

// CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.array$_dyn_fixedbytes$_15_$_$_CallData_$.array$_dyn_fixedbytes$_16_$_$_Storage_$
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.calldataload
// CHECK-NEXT:        %[[M:.*]] = yul.constant -87112285931760246646623899502532662132736
// CHECK-NEXT:        %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK-NEXT:        yul.cmp ne, %[[V]], %[[C]]

// CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.array$_dyn_ui8_$_CallData_$.array$_dyn_ui16_$_Storage_$
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.calldataload
// CHECK-NEXT:        %[[M:.*]] = yul.constant 255
// CHECK-NEXT:        %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK-NEXT:        yul.cmp ne, %[[V]], %[[C]]

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    sol.state_var @su16 slot 0 offset 0 : !sol.array<? x ui16, Storage>
    sol.state_var @si16 slot 1 offset 0 : !sol.array<? x si16, Storage>
    sol.state_var @sb16 slot 2 offset 0 : !sol.array<? x !sol.fixedbytes<16>, Storage>
    sol.state_var @sb17 slot 3 offset 0 : !sol.array<? x !sol.fixedbytes<17>, Storage>
    sol.state_var @su136 slot 4 offset 0 : !sol.array<? x ui136, Storage>
    sol.state_var @si136 slot 5 offset 0 : !sol.array<? x si136, Storage>
    sol.state_var @si256 slot 6 offset 0 : !sol.array<? x si256, Storage>
    sol.state_var @sb17s slot 7 offset 0 : !sol.array<? x !sol.fixedbytes<17>, Storage>
    sol.state_var @sb32 slot 8 offset 0 : !sol.array<? x !sol.fixedbytes<32>, Storage>
    sol.state_var @si8 slot 9 offset 0 : !sol.array<? x si8, Storage>
    sol.func @cd2s_u8_u16(%arg0: !sol.array<? x ui8, CallData>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @su16 : !sol.array<? x ui16, Storage>
      sol.copy %arg0, %0 : !sol.array<? x ui8, CallData>, !sol.array<? x ui16, Storage>
      sol.return
    }
    sol.func @cd2s_b15_b16(%arg0: !sol.array<? x !sol.fixedbytes<15>, CallData>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @sb16 : !sol.array<? x !sol.fixedbytes<16>, Storage>
      sol.copy %arg0, %0 : !sol.array<? x !sol.fixedbytes<15>, CallData>, !sol.array<? x !sol.fixedbytes<16>, Storage>
      sol.return
    }
    sol.func @m2s_i8_i16(%arg0: !sol.array<? x si8, Memory>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @si16 : !sol.array<? x si16, Storage>
      sol.copy %arg0, %0 : !sol.array<? x si8, Memory>, !sol.array<? x si16, Storage>
      sol.return
    }
    sol.func @m2s_b15_b16(%arg0: !sol.array<? x !sol.fixedbytes<15>, Memory>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @sb16 : !sol.array<? x !sol.fixedbytes<16>, Storage>
      sol.copy %arg0, %0 : !sol.array<? x !sol.fixedbytes<15>, Memory>, !sol.array<? x !sol.fixedbytes<16>, Storage>
      sol.return
    }
    sol.func @cd2s_b15_b17(%arg0: !sol.array<? x !sol.fixedbytes<15>, CallData>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @sb17 : !sol.array<? x !sol.fixedbytes<17>, Storage>
      sol.copy %arg0, %0 : !sol.array<? x !sol.fixedbytes<15>, CallData>, !sol.array<? x !sol.fixedbytes<17>, Storage>
      sol.return
    }
    sol.func @m2s_u8_u136(%arg0: !sol.array<? x ui8, Memory>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @su136 : !sol.array<? x ui136, Storage>
      sol.copy %arg0, %0 : !sol.array<? x ui8, Memory>, !sol.array<? x ui136, Storage>
      sol.return
    }
    sol.func @s2s_i136_i256() attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @si136 : !sol.array<? x si136, Storage>
      %1 = sol.addr_of @si256 : !sol.array<? x si256, Storage>
      sol.copy %0, %1 : !sol.array<? x si136, Storage>, !sol.array<? x si256, Storage>
      sol.return
    }
    sol.func @s2s_b17_b32() attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @sb17s : !sol.array<? x !sol.fixedbytes<17>, Storage>
      %1 = sol.addr_of @sb32 : !sol.array<? x !sol.fixedbytes<32>, Storage>
      sol.copy %0, %1 : !sol.array<? x !sol.fixedbytes<17>, Storage>, !sol.array<? x !sol.fixedbytes<32>, Storage>
      sol.return
    }
    sol.func @s2s_i8_i16() attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @si8 : !sol.array<? x si8, Storage>
      %1 = sol.addr_of @si16 : !sol.array<? x si16, Storage>
      sol.copy %0, %1 : !sol.array<? x si8, Storage>, !sol.array<? x si16, Storage>
      sol.return
    }
    sol.func @s2s_i8_i136() attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @si8 : !sol.array<? x si8, Storage>
      %1 = sol.addr_of @si136 : !sol.array<? x si136, Storage>
      sol.copy %0, %1 : !sol.array<? x si8, Storage>, !sol.array<? x si136, Storage>
      sol.return
    }
    sol.func @cd2s_i8_i16(%arg0: !sol.array<? x si8, CallData>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @si16 : !sol.array<? x si16, Storage>
      sol.copy %arg0, %0 : !sol.array<? x si8, CallData>, !sol.array<? x si16, Storage>
      sol.return
    }
    sol.func @m2s_i8_i136(%arg0: !sol.array<? x si8, Memory>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @si136 : !sol.array<? x si136, Storage>
      sol.copy %arg0, %0 : !sol.array<? x si8, Memory>, !sol.array<? x si136, Storage>
      sol.return
    }
    sol.func @m2s_i136_i136(%arg0: !sol.array<? x si136, Memory>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @si136 : !sol.array<? x si136, Storage>
      sol.copy %arg0, %0 : !sol.array<? x si136, Memory>, !sol.array<? x si136, Storage>
      sol.return
    }
    sol.func @cd2s_i136_i136(%arg0: !sol.array<? x si136, CallData>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @si136 : !sol.array<? x si136, Storage>
      sol.copy %arg0, %0 : !sol.array<? x si136, CallData>, !sol.array<? x si136, Storage>
      sol.return
    }
  } {kind = #Contract, runtime}
}
