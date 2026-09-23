// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

!Sstg = !sol.struct<(ui8, !sol.fixedbytes<19>, si72, !sol.string<Storage>), Storage>
#Contract = #sol<ContractKind Contract>

// Storage to storage copies word by word in a helper per struct type, which
// the site skips on self-assignment.
// CHECK-LABEL: yul.func @__sol.copy_struct.storage.storage.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_Storage_$_$_$_Storage_$.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_Storage_$_$_$_Storage_$ : (i256, i256) -> ()
// CHECK-NEXT:  ^bb0(%[[SRC:.*]]: i256, %[[DST:.*]]: i256):
// CHECK:         yul.add %[[SRC]], %{{.*}}
// CHECK:         yul.sload
// CHECK:         yul.constant 5708990770823839524233143877797980545530986495
// CHECK:         yul.constant 4722366482869645213695
// CHECK:         yul.constant -6901746346790563787434755862277025452451108972170386555162524223799296
// CHECK:         yul.sstore
// CHECK:         %[[C1S:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    %[[DS:.*]] = yul.add %[[SRC]], %[[C1S]]
// CHECK-NEXT:    %[[C1D:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    %[[DD:.*]] = yul.add %[[DST]], %[[C1D]]
// CHECK:         yul.func_call @__sol.copy_string.storage.storage(%[[DS]], %[[DD]])
// CHECK-LABEL: yul.func @f1 : () -> ()
// CHECK:         %[[SRC:.*]] = yul.constant 2
// CHECK:         %[[DST:.*]] = yul.constant 0
// CHECK:         %[[NE:.*]] = yul.cmp ne, %[[SRC]], %[[DST]]
// CHECK:         yul.if %[[NE]] {
// CHECK:           yul.func_call @__sol.copy_struct.storage.storage.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_Storage_$_$_$_Storage_$.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_Storage_$_$_$_Storage_$(%[[SRC]], %[[DST]])
module {
  sol.contract @C {
    sol.state_var @c1 slot 0 offset 0 : !Sstg
    sol.state_var @c2 slot 2 offset 0 : !Sstg
    sol.func @f1() {
      %0 = sol.addr_of @c2 : !Sstg
      %1 = sol.addr_of @c1 : !Sstg
      sol.copy %0, %1 : !Sstg, !Sstg
      sol.return
    }
  } {kind = #Contract}
}

// -----

!Sstg = !sol.struct<(ui8, !sol.fixedbytes<19>, si72, !sol.string<Storage>), Storage>
!Smem = !sol.struct<(ui8, !sol.fixedbytes<19>, si72, !sol.string<Memory>), Memory>
#Contract = #sol<ContractKind Contract>

// a, the left-aligned bytes19 b and c pack into slot 0.
// CHECK-LABEL: yul.func @__sol.copy_struct.memory.storage.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_Memory_$_$_$_Memory_$.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_Storage_$_$_$_Storage_$ : (i256, i256) -> ()
// CHECK:         %[[A:.*]] = yul.mload %arg0
// CHECK:         %[[AM:.*]] = yul.constant 255
// CHECK:         %[[AC:.*]] = yul.and %[[A]], %[[AM]]
// CHECK:         %[[ACC:.*]] = yul.or %{{.*}}, %[[AC]]
// CHECK:         %[[B:.*]] = yul.mload
// CHECK:         %[[C104:.*]] = yul.constant 104
// CHECK:         %[[BR:.*]] = yul.arith_shr %[[B]], %[[C104]]
// CHECK:         %[[C8:.*]] = yul.constant 8
// CHECK:         %[[BS:.*]] = yul.arith_shl %[[BR]], %[[C8]]
// CHECK:         %[[ACC2:.*]] = yul.or %[[ACC]], %[[BS]]
// CHECK:         %[[C:.*]] = yul.mload
// CHECK:         %[[CM:.*]] = yul.constant 4722366482869645213695
// CHECK:         %[[CC:.*]] = yul.and %[[C]], %[[CM]]
// CHECK:         %[[C160:.*]] = yul.constant 160
// CHECK:         %[[CS:.*]] = yul.arith_shl %[[CC]], %[[C160]]
// CHECK:         %[[W:.*]] = yul.or %[[ACC2]], %[[CS]]
// CHECK:         %[[OLD:.*]] = yul.sload
// CHECK:         %[[KEEP:.*]] = yul.constant -6901746346790563787434755862277025452451108972170386555162524223799296
// CHECK:         %[[CLR:.*]] = yul.and %[[OLD]], %[[KEEP]]
// CHECK:         %[[NEW:.*]] = yul.or %[[CLR]], %[[W]]
// CHECK:         yul.sstore %{{.*}}, %[[NEW]]
// CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    %[[D:.*]] = yul.add %{{.*}}, %[[C1]]
// CHECK-NEXT:    yul.func_call @__sol.copy_string.memory.storage(%{{.*}}, %[[D]])
// CHECK-LABEL: yul.func @f2 : (i256) -> ()
// CHECK:         yul.func_call @__sol.copy_struct.memory.storage.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_Memory_$_$_$_Memory_$.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_Storage_$_$_$_Storage_$(%arg0, %{{.*}})
module {
  sol.contract @C {
    sol.state_var @c1 slot 0 offset 0 : !Sstg
    sol.func @f2(%arg0: !Smem) {
      %0 = sol.addr_of @c1 : !Sstg
      sol.copy %arg0, %0 : !Smem, !Sstg
      sol.return
    }
  } {kind = #Contract}
}

// -----

!Sstg = !sol.struct<(ui8, !sol.fixedbytes<19>, si72, !sol.string<Storage>), Storage>
!Scd = !sol.struct<(ui8, !sol.fixedbytes<19>, si72, !sol.string<CallData>), CallData>
#Contract = #sol<ContractKind Contract>

// Calldata members are validated before being packed into storage.
// CHECK-LABEL: yul.func @__sol.copy_struct.calldata.storage.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_CallData_$_$_$_CallData_$.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_Storage_$_$_$_Storage_$ : (i256, i256) -> ()
// CHECK:         yul.constant 255
// CHECK:         yul.revert
// CHECK:         %[[B:.*]] = yul.calldataload
// CHECK:         %[[BM:.*]] = yul.constant -20282409603651670423947251286016
// CHECK:         %[[BC:.*]] = yul.and %[[B]], %[[BM]]
// CHECK:         %[[BDIRTY:.*]] = yul.cmp ne, %[[B]], %[[BC]]
// CHECK:         yul.if %[[BDIRTY]] {
// CHECK:           yul.revert
// CHECK:         %[[C104:.*]] = yul.constant 104
// CHECK:         yul.arith_shr %[[BC]], %[[C104]]
// CHECK:         %[[I:.*]] = yul.calldataload
// CHECK:         %[[IC:.*]] = yul.signextend %{{.*}}, %[[I]]
// CHECK:         %[[IDIRTY:.*]] = yul.cmp ne, %[[I]], %[[IC]]
// CHECK:         yul.if %[[IDIRTY]] {
// CHECK:           yul.revert
// CHECK:         %[[IM:.*]] = yul.constant 4722366482869645213695
// CHECK:         yul.and %[[IC]], %[[IM]]
// CHECK:         %[[D:.*]] = yul.add %{{.*}}, %c1_i256
// CHECK:         yul.func_call @__sol.copy_string.calldata.storage(%{{.*}}, %[[D]])
// CHECK-LABEL: yul.func @f3 : (i256) -> ()
// CHECK:         yul.func_call @__sol.copy_struct.calldata.storage.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_CallData_$_$_$_CallData_$.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_Storage_$_$_$_Storage_$(%arg0, %{{.*}})
module {
  sol.contract @C {
    sol.state_var @c1 slot 0 offset 0 : !Sstg
    sol.func @f3(%arg0: !Scd) {
      %0 = sol.addr_of @c1 : !Sstg
      sol.copy %arg0, %0 : !Scd, !Sstg
      sol.return
    }
  } {kind = #Contract}
}

// -----

!Sstg = !sol.struct<(ui8, !sol.fixedbytes<19>, si72, !sol.string<Storage>), Storage>
!Smem = !sol.struct<(ui8, !sol.fixedbytes<19>, si72, !sol.string<Memory>), Memory>
#Contract = #sol<ContractKind Contract>

// The storage string is cloned by its own helper, which allocates the memory
// copy and fills it.
// CHECK-LABEL: yul.func @__sol.clone_string.storage.memory : (i256) -> i256
// CHECK-NEXT:  ^bb0(%[[D:.*]]: i256):
// CHECK:         %[[DW:.*]] = yul.sload %[[D]]
// CHECK:         %[[LEN:.*]] = yul.func_call @__sol.storage_string_length(%[[DW]])
// CHECK:         %[[P:.*]] = yul.func_call @__sol.alloc
// CHECK:         yul.mstore %[[P]], %[[LEN]]
// CHECK:         yul.func_call @__sol.copy_string_bytes.storage.memory(%[[D]], %[[DW]], %[[LEN]], %{{.*}})
// CHECK:         yul.func_return %[[P]]
// CHECK-LABEL: yul.func @__sol.clone_struct.storage.memory.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_Storage_$_$_$_Storage_$ : (i256) -> i256
// CHECK:         yul.constant 128
// CHECK:         %[[S:.*]] = yul.sload
// CHECK:         %[[C160:.*]] = yul.constant 160
// CHECK-NEXT:    %[[I:.*]] = yul.arith_shr %[[S]], %[[C160]]
// CHECK-NEXT:    %[[C8:.*]] = yul.constant 8
// CHECK-NEXT:    yul.signextend %[[C8]], %[[I]]
// CHECK:         %[[C1:.*]] = yul.constant 1{{$}}
// CHECK-NEXT:    %[[D:.*]] = yul.add %{{.*}}, %[[C1]]
// CHECK-NEXT:    yul.func_call @__sol.clone_string.storage.memory(%[[D]])
// CHECK:         yul.func_return
// CHECK-LABEL: yul.func @f4 : () -> i256
// CHECK:         %[[R:.*]] = yul.func_call @__sol.clone_struct.storage.memory.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_Storage_$_$_$_Storage_$(%{{.*}})
// CHECK:         yul.func_return %[[R]]
module {
  sol.contract @C {
    sol.state_var @c1 slot 0 offset 0 : !Sstg
    sol.func @f4() -> !Smem {
      %0 = sol.addr_of @c1 : !Sstg
      %1 = sol.data_loc_cast %0 : !Sstg, !Smem
      sol.return %1 : !Smem
    }
  } {kind = #Contract}
}

// -----

!Smem = !sol.struct<(ui8, !sol.fixedbytes<19>, si72, !sol.string<Memory>), Memory>
!Scd = !sol.struct<(ui8, !sol.fixedbytes<19>, si72, !sol.string<CallData>), CallData>
#Contract = #sol<ContractKind Contract>

// The 128-byte head is one word per member; the string member gets its own
// allocation, filled from calldata.
// CHECK-LABEL: yul.func @__sol.clone_struct.calldata.memory.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_CallData_$_$_$_CallData_$ : (i256) -> i256
// CHECK:         %[[HEAD:.*]] = yul.constant 128
// CHECK:         %[[P:.*]] = yul.mload
// CHECK:         yul.add %[[HEAD]],
// CHECK:         %[[SP:.*]] = yul.add %[[P]], %c96_i256
// CHECK:         %[[STR:.*]] = yul.func_call @__sol.alloc
// CHECK:         yul.calldatacopy %{{[0-9]+}}, %{{[0-9]+}}, %{{[0-9]+}}{{$}}
// CHECK:         yul.mstore %[[SP]], %[[STR]]
// CHECK:         yul.func_return %[[P]]
// CHECK-LABEL: yul.func @f5 : (i256) -> i256
// CHECK:         %[[R:.*]] = yul.func_call @__sol.clone_struct.calldata.memory.struct$_$_ui8_$_fixedbytes$_19_$_$_si72_$_string$_CallData_$_$_$_CallData_$(%arg0)
// CHECK:         yul.func_return %[[R]]
module {
  sol.contract @C {
    sol.func @f5(%arg0: !Scd) -> !Smem {
      %0 = sol.data_loc_cast %arg0 : !Scd, !Smem
      sol.return %0 : !Smem
    }
  } {kind = #Contract}
}
