// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// Every copy is outlined into a `__sol.copy_array` or `__sol.clone_array`
// helper that takes the array references, so the packing loops are checked in
// the helper and the user function only passes its slot.
//
// bytes15[2] elements are inline in calldata (64 bytes each) and each fills
// one storage slot of two bytes16. The row copy is a helper of its own.
// CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.array$_2_fixedbytes$_15_$_$_CallData_$.array$_2_fixedbytes$_16_$_$_Storage_$ : (i256, i256) -> ()
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.calldataload
// CHECK:             %[[M:.*]] = yul.constant -87112285931760246646623899502532662132736
// CHECK:             %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK:             yul.cmp ne, %[[V]], %[[C]]
// CHECK:             %[[C128:.*]] = yul.constant 128
// CHECK:             yul.arith_shr %[[C]], %[[C128]]
// CHECK:           yul.sstore
// CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.array$_dyn_array$_2_fixedbytes$_15_$_$_CallData_$_$_CallData_$.array$_dyn_array$_2_fixedbytes$_16_$_$_Storage_$_$_Storage_$ : (!llvm.struct<(i256, i256)>, i256) -> ()
// CHECK-NEXT:  ^bb0(%[[A:.*]]: !llvm.struct<(i256, i256)>, %[[SLOT:.*]]: i256):
// CHECK:         %[[LEN:.*]] = llvm.extractvalue %[[A]][1]
// CHECK:         yul.sstore %[[SLOT]], %[[LEN]]
// CHECK:         yul.for
// CHECK:           yul.cmp ult, %{{.*}}, %[[LEN]]
// CHECK:           %[[C64:.*]] = yul.constant 64{{$}}
// CHECK:           yul.mul %{{.*}}, %[[C64]]
// CHECK:           yul.func_call @__sol.copy_array.calldata.storage.array$_2_fixedbytes$_15_$_$_CallData_$.array$_2_fixedbytes$_16_$_$_Storage_$
// CHECK-LABEL: yul.func @cd2s_b15_b16_ds : (!llvm.struct<(i256, i256)>) -> ()
// CHECK:         %[[S:.*]] = yul.constant 6{{$}}
// CHECK:         yul.func_call @__sol.copy_array.calldata.storage.array$_dyn_array$_2_fixedbytes$_15_$_$_CallData_$_$_CallData_$.array$_dyn_array$_2_fixedbytes$_16_$_$_Storage_$_$_Storage_$(%arg0, %[[S]])
module {
  sol.contract @C {
    sol.state_var @sb16ds slot 6 offset 0 : !sol.array<? x !sol.array<2 x !sol.fixedbytes<16>, Storage>, Storage>
    sol.func @cd2s_b15_b16_ds(%arg0: !sol.array<? x !sol.array<2 x !sol.fixedbytes<15>, CallData>, CallData>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @sb16ds : !sol.array<? x !sol.array<2 x !sol.fixedbytes<16>, Storage>, Storage>
      sol.copy %arg0, %0 : !sol.array<? x !sol.array<2 x !sol.fixedbytes<15>, CallData>, CallData>, !sol.array<? x !sol.array<2 x !sol.fixedbytes<16>, Storage>, Storage>
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// Inner calldata arrays are located by offset and validated before the
// per-element copy.
// CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.array$_dyn_fixedbytes$_15_$_$_CallData_$.array$_dyn_fixedbytes$_16_$_$_Storage_$ : (!llvm.struct<(i256, i256)>, i256) -> ()
// CHECK-NEXT:  ^bb0(%[[IA:.*]]: !llvm.struct<(i256, i256)>, %[[ISLOT:.*]]: i256):
// CHECK:         %[[ILEN:.*]] = llvm.extractvalue %[[IA]][1]
// CHECK:         yul.sstore %[[ISLOT]], %[[ILEN]]
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.calldataload
// CHECK:             %[[M:.*]] = yul.constant -87112285931760246646623899502532662132736
// CHECK:             yul.and %[[V]], %[[M]]
// CHECK:           yul.sstore
// CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.array$_dyn_array$_dyn_fixedbytes$_15_$_$_CallData_$_$_CallData_$.array$_dyn_array$_dyn_fixedbytes$_16_$_$_Storage_$_$_Storage_$ : (!llvm.struct<(i256, i256)>, i256) -> ()
// CHECK-NEXT:  ^bb0(%[[A:.*]]: !llvm.struct<(i256, i256)>, %[[SLOT:.*]]: i256):
// CHECK:         %[[LEN:.*]] = llvm.extractvalue %[[A]][1]
// CHECK:         %[[BASE:.*]] = llvm.extractvalue %[[A]][0]
// CHECK:         yul.sstore %[[SLOT]], %[[LEN]]
// CHECK:         yul.for
// CHECK:           %[[REL:.*]] = yul.calldataload
// CHECK:           yul.cmp sge, %[[REL]], %{{.*}}
// CHECK:           %[[INNER:.*]] = yul.add %[[BASE]], %[[REL]]
// CHECK:           yul.calldataload %[[INNER]]
// CHECK:           yul.func_call @__sol.copy_array.calldata.storage.array$_dyn_fixedbytes$_15_$_$_CallData_$.array$_dyn_fixedbytes$_16_$_$_Storage_$
// CHECK-LABEL: yul.func @cd2s_b15_b16_dd : (!llvm.struct<(i256, i256)>) -> ()
// CHECK:         %[[S:.*]] = yul.constant 3{{$}}
// CHECK:         yul.func_call @__sol.copy_array.calldata.storage.array$_dyn_array$_dyn_fixedbytes$_15_$_$_CallData_$_$_CallData_$.array$_dyn_array$_dyn_fixedbytes$_16_$_$_Storage_$_$_Storage_$(%arg0, %[[S]])
module {
  sol.contract @C {
    sol.state_var @sb16dd slot 3 offset 0 : !sol.array<? x !sol.array<? x !sol.fixedbytes<16>, Storage>, Storage>
    sol.func @cd2s_b15_b16_dd(%arg0: !sol.array<? x !sol.array<? x !sol.fixedbytes<15>, CallData>, CallData>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @sb16dd : !sol.array<? x !sol.array<? x !sol.fixedbytes<16>, Storage>, Storage>
      sol.copy %arg0, %0 : !sol.array<? x !sol.array<? x !sol.fixedbytes<15>, CallData>, CallData>, !sol.array<? x !sol.array<? x !sol.fixedbytes<16>, Storage>, Storage>
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// bytes17 takes a whole slot, stored right-aligned.
// CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_3_fixedbytes$_17_$_$_Memory_$.array$_3_fixedbytes$_17_$_$_Storage_$ : (i256, i256) -> ()
// CHECK:         yul.for
// CHECK:           %[[S:.*]] = yul.add %arg1, %{{.*}}
// CHECK:           %[[V:.*]] = yul.mload
// CHECK:           %[[C120:.*]] = yul.constant 120
// CHECK:           %[[R:.*]] = yul.arith_shr %[[V]], %[[C120]]
// CHECK:           yul.sstore %[[S]], %[[R]]
// CHECK-LABEL: yul.func @m2s_b17s_135 : (i256) -> ()
// CHECK:         %[[SLOT:.*]] = yul.constant 9{{$}}
// CHECK:         yul.func_call @__sol.copy_array.memory.storage.array$_3_fixedbytes$_17_$_$_Memory_$.array$_3_fixedbytes$_17_$_$_Storage_$(%arg0, %[[SLOT]])
module {
  sol.contract @C {
    sol.state_var @sb17s slot 9 offset 0 : !sol.array<3 x !sol.fixedbytes<17>, Storage>
    sol.func @m2s_b17s_135(%arg0: !sol.array<3 x !sol.fixedbytes<17>, Memory>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @sb17s : !sol.array<3 x !sol.fixedbytes<17>, Storage>
      sol.copy %arg0, %0 : !sol.array<3 x !sol.fixedbytes<17>, Memory>, !sol.array<3 x !sol.fixedbytes<17>, Storage>
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.func @__sol.copy_array.storage.storage.array$_dyn_fixedbytes$_17_$_$_Storage_$.array$_dyn_fixedbytes$_17_$_$_Storage_$ : (i256, i256) -> ()
// CHECK:         yul.cmp ne, %arg0, %arg1
// CHECK:         %[[LEN:.*]] = yul.sload %arg0
// CHECK:         yul.sstore %arg1, %[[LEN]]
// CHECK:         yul.for
// CHECK:           yul.sstore
// CHECK:         yul.for
// CHECK:           %[[W:.*]] = yul.sload
// CHECK:           yul.sstore %{{.*}}, %[[W]]
// CHECK-LABEL: yul.func @s2s_b17d_123 : () -> ()
// CHECK:         %[[SRC:.*]] = yul.constant 12{{$}}
// CHECK:         %[[DST:.*]] = yul.constant 13{{$}}
// CHECK:         yul.func_call @__sol.copy_array.storage.storage.array$_dyn_fixedbytes$_17_$_$_Storage_$.array$_dyn_fixedbytes$_17_$_$_Storage_$(%[[SRC]], %[[DST]])
module {
  sol.contract @C {
    sol.state_var @sb17d_a slot 12 offset 0 : !sol.array<? x !sol.fixedbytes<17>, Storage>
    sol.state_var @sb17d_b slot 13 offset 0 : !sol.array<? x !sol.fixedbytes<17>, Storage>
    sol.func @s2s_b17d_123() attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @sb17d_a : !sol.array<? x !sol.fixedbytes<17>, Storage>
      %1 = sol.addr_of @sb17d_b : !sol.array<? x !sol.fixedbytes<17>, Storage>
      sol.copy %0, %1 : !sol.array<? x !sol.fixedbytes<17>, Storage>, !sol.array<? x !sol.fixedbytes<17>, Storage>
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// Storage-to-storage packed copy moves whole slots, masking the last
// partial one (10 bytes3 per slot).
// CHECK-LABEL: yul.func @__sol.copy_array.storage.storage.array$_5_fixedbytes$_3_$_$_Storage_$.array$_dyn_fixedbytes$_3_$_$_Storage_$ : (i256, i256) -> ()
// CHECK:         yul.sstore %arg1, %{{.*}}
// CHECK:         %[[M:.*]] = yul.constant 1766847064778384329583297500742918515827483896875618958121606201292619775
// CHECK:         %[[MW:.*]] = yul.and %{{.*}}, %[[M]]
// CHECK:           yul.sstore %{{.*}}, %[[MW]]
// CHECK:         %[[TW:.*]] = yul.sload
// CHECK:         %[[C24:.*]] = yul.constant 24{{$}}
// CHECK:         %[[BITS:.*]] = yul.mul %{{.*}}, %[[C24]]
// CHECK:         %[[SH:.*]] = yul.arith_shl %{{.*}}, %[[BITS]]
// CHECK:         %[[TM:.*]] = yul.sub %[[SH]], %{{.*}}
// CHECK:         %[[TV:.*]] = yul.and %[[TW]], %[[TM]]
// CHECK:         yul.sstore %{{.*}}, %[[TV]]
// CHECK-LABEL: yul.func @s2s_b3_115 : () -> ()
// CHECK:         %[[SRC:.*]] = yul.constant 4{{$}}
// CHECK:         %[[DST:.*]] = yul.constant 5{{$}}
// CHECK:         yul.func_call @__sol.copy_array.storage.storage.array$_5_fixedbytes$_3_$_$_Storage_$.array$_dyn_fixedbytes$_3_$_$_Storage_$(%[[SRC]], %[[DST]])
module {
  sol.contract @C {
    sol.state_var @sb3s_a slot 4 offset 0 : !sol.array<5 x !sol.fixedbytes<3>, Storage>
    sol.state_var @sb3d slot 5 offset 0 : !sol.array<? x !sol.fixedbytes<3>, Storage>
    sol.func @s2s_b3_115() attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @sb3s_a : !sol.array<5 x !sol.fixedbytes<3>, Storage>
      %1 = sol.addr_of @sb3d : !sol.array<? x !sol.fixedbytes<3>, Storage>
      sol.copy %0, %1 : !sol.array<5 x !sol.fixedbytes<3>, Storage>, !sol.array<? x !sol.fixedbytes<3>, Storage>
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>

// Calldata elements are validated against their type's mask before the
// memory store.
// CHECK-LABEL: yul.func @__sol.clone_array.calldata.memory.array$_3_fixedbytes$_16_$_$_CallData_$ : (i256) -> i256
// CHECK:         %[[P:.*]] = yul.mload %c64
// CHECK:         yul.for
// CHECK:           %[[V:.*]] = yul.calldataload
// CHECK:           %[[M:.*]] = yul.constant -340282366920938463463374607431768211456
// CHECK:           %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK:           %[[BAD:.*]] = yul.cmp ne, %[[V]], %[[C]]
// CHECK:           yul.if %[[BAD]] {
// CHECK:           yul.mstore %{{.*}}, %[[C]]
// CHECK:         yul.func_return %[[P]] : i256
// CHECK-LABEL: yul.func @cd2m_b16s_107 : (i256) -> i256
// CHECK:         %[[R:.*]] = yul.func_call @__sol.clone_array.calldata.memory.array$_3_fixedbytes$_16_$_$_CallData_$(%arg0)
// CHECK:         yul.func_return %[[R]] : i256
module {
  sol.contract @C {
    sol.func @cd2m_b16s_107(%arg0: !sol.array<3 x !sol.fixedbytes<16>, CallData>) -> !sol.array<3 x !sol.fixedbytes<16>, Memory> attributes {state_mutability = #Pure} {
      %0 = sol.data_loc_cast %arg0 : !sol.array<3 x !sol.fixedbytes<16>, CallData>, !sol.array<3 x !sol.fixedbytes<16>, Memory>
      sol.return %0 : !sol.array<3 x !sol.fixedbytes<16>, Memory>
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.func @__sol.copy_array.calldata.storage.array$_5_fixedbytes$_3_$_$_CallData_$.array$_5_fixedbytes$_3_$_$_Storage_$ : (i256, i256) -> ()
// CHECK:         %[[PER:.*]] = yul.constant 10{{$}}
// CHECK:         yul.for %{{.*}}, %arg0, %arg1, %{{.*}} :
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.calldataload
// CHECK:             %[[M:.*]] = yul.constant -6901746346790563787434755862277025452451108972170386555162524223799296
// CHECK:             %[[C:.*]] = yul.and %[[V]], %[[M]]
// CHECK:             yul.cmp ne, %[[V]], %[[C]]
// CHECK:             %[[C232:.*]] = yul.constant 232
// CHECK:             %[[R:.*]] = yul.arith_shr %[[C]], %[[C232]]
// CHECK:             %[[B3:.*]] = yul.constant 16777215
// CHECK:             %[[E:.*]] = yul.and %[[R]], %[[B3]]
// CHECK:             yul.arith_shl %[[E]], %{{.*}}
// CHECK:           yul.sstore
// CHECK:         yul.if
// CHECK:         } {full_unroll}
// CHECK:         yul.sstore
// CHECK-LABEL: yul.func @cd2s_b3s_93 : (i256) -> ()
// CHECK:         %[[SLOT:.*]] = yul.constant 4{{$}}
// CHECK:         yul.func_call @__sol.copy_array.calldata.storage.array$_5_fixedbytes$_3_$_$_CallData_$.array$_5_fixedbytes$_3_$_$_Storage_$(%arg0, %[[SLOT]])
module {
  sol.contract @C {
    sol.state_var @sb3s_a slot 4 offset 0 : !sol.array<5 x !sol.fixedbytes<3>, Storage>
    sol.func @cd2s_b3s_93(%arg0: !sol.array<5 x !sol.fixedbytes<3>, CallData>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @sb3s_a : !sol.array<5 x !sol.fixedbytes<3>, Storage>
      sol.copy %arg0, %0 : !sol.array<5 x !sol.fixedbytes<3>, CallData>, !sol.array<5 x !sol.fixedbytes<3>, Storage>
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#View = #sol<StateMutability View>

// CHECK-LABEL: yul.func @__sol.clone_array.storage.memory.array$_dyn_fixedbytes$_16_$_$_Storage_$ : (i256) -> i256
// CHECK:         %[[LEN:.*]] = yul.sload %arg0
// CHECK:         yul.keccak256
// CHECK:         %[[P:.*]] = yul.func_call @__sol.alloc
// CHECK:         yul.mstore %[[P]], %[[LEN]]
// CHECK:         yul.for
// CHECK:           %[[W:.*]] = yul.sload
// CHECK:           yul.for
// CHECK:             %[[E:.*]] = yul.arith_shr %[[W]], %{{.*}}
// CHECK:             %[[C128:.*]] = yul.constant 128
// CHECK:             %[[L:.*]] = yul.arith_shl %[[E]], %[[C128]]
// CHECK:             yul.mstore %{{.*}}, %[[L]]
// CHECK:         yul.if %{{.*}} -> i256 {
// CHECK:         yul.func_return %[[P]] : i256
// CHECK-LABEL: yul.func @s2m_b16d_81 : () -> i256
// CHECK:         %[[SLOT:.*]] = yul.constant 8{{$}}
// CHECK:         %[[R:.*]] = yul.func_call @__sol.clone_array.storage.memory.array$_dyn_fixedbytes$_16_$_$_Storage_$(%[[SLOT]])
// CHECK:         yul.func_return %[[R]] : i256
module {
  sol.contract @C {
    sol.state_var @sb16d_a slot 8 offset 0 : !sol.array<? x !sol.fixedbytes<16>, Storage>
    sol.func @s2m_b16d_81() -> !sol.array<? x !sol.fixedbytes<16>, Memory> attributes {state_mutability = #View} {
      %0 = sol.addr_of @sb16d_a : !sol.array<? x !sol.fixedbytes<16>, Storage>
      %1 = sol.data_loc_cast %0 : !sol.array<? x !sol.fixedbytes<16>, Storage>, !sol.array<? x !sol.fixedbytes<16>, Memory>
      sol.return %1 : !sol.array<? x !sol.fixedbytes<16>, Memory>
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#View = #sol<StateMutability View>

// CHECK-LABEL: yul.func @__sol.clone_array.storage.memory.array$_5_fixedbytes$_3_$_$_Storage_$ : (i256) -> i256
// CHECK:         %[[P:.*]] = yul.mload %c64
// CHECK:         %[[PER:.*]] = yul.constant 10{{$}}
// CHECK:         yul.for %{{.*}}, %[[P]], %arg0, %{{.*}} :
// CHECK:           %[[W:.*]] = yul.sload
// CHECK:           yul.for
// CHECK:             %[[E:.*]] = yul.arith_shr %[[W]], %{{.*}}
// CHECK:             %[[C232:.*]] = yul.constant 232
// CHECK:             %[[L:.*]] = yul.arith_shl %[[E]], %[[C232]]
// CHECK:             yul.mstore %{{.*}}, %[[L]]
// CHECK:         yul.if %{{.*}} -> i256 {
// CHECK:         yul.func_return %[[P]] : i256
// CHECK-LABEL: yul.func @s2m_b3s_72 : () -> i256
// CHECK:         %[[SLOT:.*]] = yul.constant 4{{$}}
// CHECK:         %[[R:.*]] = yul.func_call @__sol.clone_array.storage.memory.array$_5_fixedbytes$_3_$_$_Storage_$(%[[SLOT]])
// CHECK:         yul.func_return %[[R]] : i256
module {
  sol.contract @C {
    sol.state_var @sb3s_a slot 4 offset 0 : !sol.array<5 x !sol.fixedbytes<3>, Storage>
    sol.func @s2m_b3s_72() -> !sol.array<5 x !sol.fixedbytes<3>, Memory> attributes {state_mutability = #View} {
      %0 = sol.addr_of @sb3s_a : !sol.array<5 x !sol.fixedbytes<3>, Storage>
      %1 = sol.data_loc_cast %0 : !sol.array<5 x !sol.fixedbytes<3>, Storage>, !sol.array<5 x !sol.fixedbytes<3>, Memory>
      sol.return %1 : !sol.array<5 x !sol.fixedbytes<3>, Memory>
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// On shrink, the bytes past the new end in the last used slot are masked
// off and the remaining old slots are zeroed, before the packed copy.
// bytes16 elements are shifted down from the left-aligned memory word
// before masking.
// CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_dyn_fixedbytes$_16_$_$_Memory_$.array$_dyn_fixedbytes$_16_$_$_Storage_$ : (i256, i256) -> ()
// CHECK-NEXT:  ^bb0(%[[ARR:.*]]: i256, %[[SLOT:.*]]: i256):
// CHECK:         %[[LEN:.*]] = yul.mload %[[ARR]]
// CHECK:         %[[OLD:.*]] = yul.sload %[[SLOT]]
// CHECK:         yul.sstore %[[SLOT]], %[[LEN]]
// CHECK:         %[[SHRINK:.*]] = yul.cmp ult, %[[LEN]], %[[OLD]]
// CHECK:         yul.if %[[SHRINK]] {
// CHECK:           %[[ESZ:.*]] = yul.constant 16{{$}}
// CHECK:           %[[BYTES:.*]] = yul.mul %{{.*}}, %[[ESZ]]
// CHECK:           %[[BITS:.*]] = yul.mul %[[BYTES]], %{{.*}}
// CHECK:           %[[ONES:.*]] = yul.constant -1
// CHECK:           %[[C256:.*]] = yul.constant 256
// CHECK:           %[[SH:.*]] = yul.sub %[[C256]], %[[BITS]]
// CHECK:           %[[KEEP:.*]] = yul.arith_shr %[[ONES]], %[[SH]]
// CHECK:           %[[LAST:.*]] = yul.sload
// CHECK:           %[[CL:.*]] = yul.and %[[LAST]], %[[KEEP]]
// CHECK:           yul.sstore %{{.*}}, %[[CL]]
// CHECK:           yul.for
// CHECK:             yul.sstore
// CHECK:         yul.for
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.mload
// CHECK-NEXT:        %[[C128:.*]] = yul.constant 128
// CHECK-NEXT:        %[[R:.*]] = yul.arith_shr %[[V]], %[[C128]]
// CHECK-NEXT:        %[[M:.*]] = yul.constant 340282366920938463463374607431768211455
// CHECK-NEXT:        %[[E:.*]] = yul.and %[[R]], %[[M]]
// CHECK:             yul.arith_shl %[[E]], %{{.*}}
// CHECK:           yul.sstore
// CHECK-LABEL: yul.func @m2s_b16d_62 : (i256) -> ()
// CHECK:         %[[S:.*]] = yul.constant 8{{$}}
// CHECK:         yul.func_call @__sol.copy_array.memory.storage.array$_dyn_fixedbytes$_16_$_$_Memory_$.array$_dyn_fixedbytes$_16_$_$_Storage_$(%arg0, %[[S]])
module {
  sol.contract @C {
    sol.state_var @sb16d_a slot 8 offset 0 : !sol.array<? x !sol.fixedbytes<16>, Storage>
    sol.func @m2s_b16d_62(%arg0: !sol.array<? x !sol.fixedbytes<16>, Memory>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @sb16d_a : !sol.array<? x !sol.fixedbytes<16>, Storage>
      sol.copy %arg0, %0 : !sol.array<? x !sol.fixedbytes<16>, Memory>, !sol.array<? x !sol.fixedbytes<16>, Storage>
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL: yul.func @__sol.copy_array.memory.storage.array$_33_ui8_$_Memory_$.array$_33_ui8_$_Storage_$ : (i256, i256) -> ()
// CHECK:         %[[LEN:.*]] = yul.constant 33{{$}}
// CHECK:         %[[PER:.*]] = yul.constant 32{{$}}
// CHECK:         yul.cmp uge, %[[LEN]], %[[PER]]
// CHECK:         yul.for %{{.*}}, %arg0, %arg1, %{{.*}} :
// CHECK:           yul.for
// CHECK:             %[[V:.*]] = yul.mload
// CHECK:             %[[M:.*]] = yul.constant 255
// CHECK:             %[[E:.*]] = yul.and %[[V]], %[[M]]
// CHECK:             yul.arith_shl %[[E]], %{{.*}}
// CHECK:           yul.sstore
// CHECK:         yul.cmp ult, %{{.*}}, %[[LEN]]
// CHECK:         } {full_unroll}
// CHECK:         yul.sstore
// CHECK-LABEL: yul.func @m2s_u8s_51 : (i256) -> ()
// CHECK:         %[[S:.*]] = yul.constant 0{{$}}
// CHECK:         yul.func_call @__sol.copy_array.memory.storage.array$_33_ui8_$_Memory_$.array$_33_ui8_$_Storage_$(%arg0, %[[S]])
module {
  sol.contract @C {
    sol.state_var @su8s_a slot 0 offset 0 : !sol.array<33 x ui8, Storage>
    sol.func @m2s_u8s_51(%arg0: !sol.array<33 x ui8, Memory>) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @su8s_a : !sol.array<33 x ui8, Storage>
      sol.copy %arg0, %0 : !sol.array<33 x ui8, Memory>, !sol.array<33 x ui8, Storage>
      sol.return
    }
  } {kind = #Contract}
}
