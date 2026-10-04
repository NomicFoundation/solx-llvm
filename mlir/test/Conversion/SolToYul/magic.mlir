// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @encode : (i256, i256, i256) -> i256
// CHECK:         yul.mstore %{{.*}}, %arg0
// CHECK:         %[[BC:.*]] = yul.and %arg1, %c255_i256
// CHECK:         yul.mstore %{{.*}}, %[[BC]]
// CHECK:         %[[CC:.*]] = yul.signextend %c3_i256, %arg2
// CHECK:         yul.mstore %{{.*}}, %[[CC]]

// CHECK-LABEL: yul.func @decode : (i256) -> (i256, i256, i256)
// CHECK:         yul.cmp slt, %{{.*}}, %c96_i256
// CHECK:         %[[A:.*]] = yul.mload
// CHECK:         %[[B:.*]] = yul.mload
// CHECK:         %[[BC:.*]] = yul.and %[[B]], %c255_i256
// CHECK:         yul.cmp ne, %[[B]], %[[BC]]
// CHECK:         %[[C:.*]] = yul.mload
// CHECK:         %[[CC:.*]] = yul.signextend %c3_i256, %[[C]]
// CHECK:         yul.cmp ne, %[[C]], %[[CC]]
// CHECK:         yul.func_return %[[A]], %[[BC]], %[[CC]] : i256, i256, i256

// CHECK-LABEL: yul.func @decode_calldata : (!llvm.struct<(i256, i256)>) -> (i256, i256, i256)
// CHECK:         yul.cmp slt, %{{.*}}, %c96_i256
// CHECK:         %[[A:.*]] = yul.calldataload
// CHECK:         %[[B:.*]] = yul.calldataload
// CHECK:         %[[BC:.*]] = yul.and %[[B]], %c255_i256
// CHECK:         yul.cmp ne, %[[B]], %[[BC]]
// CHECK:         %[[C:.*]] = yul.calldataload
// CHECK:         %[[CC:.*]] = yul.signextend %c3_i256, %[[C]]
// CHECK:         yul.cmp ne, %[[C]], %[[CC]]
// CHECK:         yul.func_return %[[A]], %[[BC]], %[[CC]] : i256, i256, i256

// CHECK-LABEL: yul.func @encode_packed : (i256, i256) -> i256
// CHECK:         %[[X:.*]] = yul.and %arg0, %c16777215_i256
// CHECK:         %[[XS:.*]] = yul.arith_shl %[[X]], %c232_i256
// CHECK:         yul.mstore %[[P0:.*]], %[[XS]]
// CHECK:         %[[P1:.*]] = yul.add %[[P0]], %c3_i256
// CHECK:         %[[Y:.*]] = yul.and %arg1, %c79228162514264337593543950335_i256
// CHECK:         %[[YS:.*]] = yul.arith_shl %[[Y]], %c160_i256
// CHECK:         yul.mstore %[[P1]], %[[YS]]
// CHECK:         yul.add %[[P1]], %c12_i256

// CHECK-LABEL: yul.func @encode_addr : (i256) -> i256
// CHECK:         %[[C:.*]] = yul.and %arg0, %c1461501637330902918203684832716283019655932542975_i256
// CHECK:         yul.mstore %{{.*}}, %[[C]]

// CHECK-LABEL: yul.func @decode_addr : (i256) -> i256
// CHECK:         yul.cmp slt, %{{.*}}, %c32_i256
// CHECK:         %[[V:.*]] = yul.mload
// CHECK:         %[[C:.*]] = yul.and %[[V]], %c1461501637330902918203684832716283019655932542975_i256
// CHECK:         yul.cmp ne, %[[V]], %[[C]]
// CHECK:         yul.func_return %[[C]] : i256

// CHECK-LABEL: yul.func @encode_bool : (i256) -> i256
// CHECK:         %[[C:.*]] = yul.cmp ne, %arg0, %c0_i256
// CHECK:         yul.mstore %{{.*}}, %[[C]]

// CHECK-LABEL: yul.func @encode_enum : (i256) -> i256
// CHECK:         %[[OOR:.*]] = yul.cmp ugt, %arg0, %c2_i256
// CHECK:         yul.if %[[OOR]] {
// CHECK:           yul.mstore %{{.*}}, %c33_i256
// CHECK:         yul.mstore %{{.*}}, %arg0

// CHECK-LABEL: yul.func @encode_bytes5 : (i256) -> i256
// CHECK:         %[[C:.*]] = yul.and %arg0, %c-105312291668557186697918027683670432318895095400549111254310977536_i256
// CHECK:         yul.mstore %{{.*}}, %[[C]]

// CHECK-LABEL: yul.func @encode_selector : (i256, i256) -> i256
// CHECK:         yul.mstore %[[P:.*]], %arg0
// CHECK:         %[[ARGS:.*]] = yul.add %[[P]], %c4_i256
// CHECK:         yul.mstore %[[ARGS]], %arg1

// CHECK-LABEL: yul.func @encode_selector_literal : () -> i256
// CHECK:         %[[SEL:.*]] = yul.arith_shl %c69443890_i256, %c224_i256
// CHECK:         yul.mstore %{{.*}}, %[[SEL]]

// CHECK-LABEL: yul.func @encode_fnptr : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         %[[F:.*]] = yul.or
// CHECK:         %[[W:.*]] = yul.arith_shl %[[F]], %c64_i256
// CHECK:         yul.mstore %[[P:.*]], %[[W]]
// CHECK:         yul.add %[[P]], %c32_i256

// CHECK-LABEL: yul.func @encode_packed_fnptr : (!llvm.struct<(i256, i256)>) -> i256
// CHECK:         %[[A:.*]] = llvm.extractvalue %arg0[0]
// CHECK:         %[[S:.*]] = llvm.extractvalue %arg0[1]
// CHECK:         %[[SEL:.*]] = yul.and %[[S]], %c4294967295_i256
// CHECK:         %[[AS:.*]] = yul.arith_shl %[[A]], %c32_i256
// CHECK:         %[[F:.*]] = yul.or %[[AS]], %[[SEL]]
// CHECK:         %[[W:.*]] = yul.arith_shl %[[F]], %c64_i256
// CHECK:         yul.mstore %[[P:.*]], %[[W]]
// CHECK:         yul.add %[[P]], %c24_i256

// CHECK-LABEL: yul.object @C_deployed {
// CHECK-LABEL: yul.func @encode_selector_storage : (i256) -> i256
// CHECK:         %[[STR:.*]] = yul.sload %c0_i256
// CHECK:         yul.func_call @__sol.copy_string_data.storage.memory(%c0_i256{{.*}}, %[[STR]],

// CHECK-LABEL: yul.func @encode_packed_storage : () -> i256
// CHECK:         %[[S0:.*]] = yul.sload %c0_i256
// CHECK:         yul.func_call @__sol.copy_string_data.storage.memory(%c0_i256{{.*}}, %[[S0]],
// CHECK:         %[[S1:.*]] = yul.sload %c1_i256
// CHECK:         yul.func_call @__sol.copy_string_data.storage.memory(%c1_i256{{.*}}, %[[S1]],

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @encode(%arg0: ui256, %arg1: ui8, %arg2: si32) -> !sol.string<Memory> {
    %0 = sol.encode %arg0, %arg1, %arg2 : ui256, ui8, si32 : !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @decode(%arg0: !sol.string<Memory>) -> (ui256, ui8, si32) {
    %0:3 = sol.decode %arg0 : !sol.string<Memory> -> ui256, ui8, si32
    sol.return %0#0, %0#1, %0#2 : ui256, ui8, si32
  }
  sol.func @decode_calldata(%arg0: !sol.string<CallData>) -> (ui256, ui8, si32) {
    %0:3 = sol.decode %arg0 : !sol.string<CallData> -> ui256, ui8, si32
    sol.return %0#0, %0#1, %0#2 : ui256, ui8, si32
  }
  sol.func @encode_packed(%arg0: ui24, %arg1: ui96) -> !sol.string<Memory> {
    %0 = sol.encode %arg0, %arg1 : ui24, ui96 : !sol.string<Memory> {packed}
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @encode_addr(%arg0: !sol.address) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.address : !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @decode_addr(%arg0: !sol.string<Memory>) -> !sol.address<payable> {
    %0 = sol.decode %arg0 : !sol.string<Memory> -> !sol.address<payable>
    sol.return %0 : !sol.address<payable>
  }
  sol.func @encode_bool(%arg0: i1) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : i1 : !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @encode_enum(%arg0: !sol.enum<2>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.enum<2> : !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @encode_bytes5(%arg0: !sol.fixedbytes<5>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.fixedbytes<5> : !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @encode_selector(%arg0: !sol.fixedbytes<4>, %arg1: ui256) -> !sol.string<Memory> {
    %0 = sol.encode selector(%arg0) %arg1 : !sol.fixedbytes<4> ui256 : !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @encode_selector_literal() -> !sol.string<Memory> {
    %c69443890_ui32 = sol.constant 69443890 : ui32
    %0 = sol.bytes_cast %c69443890_ui32 : ui32 to !sol.fixedbytes<4>
    %1 = sol.encode selector(%0) : !sol.fixedbytes<4>  : !sol.string<Memory>
    sol.return %1 : !sol.string<Memory>
  }
  sol.func @encode_fnptr(%arg0: !sol.ext_func_ref<(ui256) -> ui256>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.ext_func_ref<(ui256) -> ui256> : !sol.string<Memory>
    sol.return %0 : !sol.string<Memory>
  }
  sol.func @encode_packed_fnptr(%arg0: !sol.ext_func_ref<(ui256) -> ui256>) -> !sol.string<Memory> {
    %0 = sol.encode %arg0 : !sol.ext_func_ref<(ui256) -> ui256> : !sol.string<Memory> {packed}
    sol.return %0 : !sol.string<Memory>
  }
}

// -----

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.contract @C {
    sol.state_var @str slot 0 offset 0 : !sol.string<Storage>
    sol.state_var @str2 slot 1 offset 0 : !sol.string<Storage>
    sol.func @encode_packed_storage() -> !sol.string<Memory> {
      %0 = sol.addr_of @str : !sol.string<Storage>
      %1 = sol.addr_of @str2 : !sol.string<Storage>
      %2 = sol.encode %0, %1 : !sol.string<Storage>, !sol.string<Storage> : !sol.string<Memory> {packed}
      sol.return %2 : !sol.string<Memory>
    }
    sol.func @encode_selector_storage(%arg0: !sol.fixedbytes<4>) -> !sol.string<Memory> {
      %0 = sol.addr_of @str : !sol.string<Storage>
      %1 = sol.encode selector(%arg0) %0 : !sol.fixedbytes<4> !sol.string<Storage> : !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract}
}
