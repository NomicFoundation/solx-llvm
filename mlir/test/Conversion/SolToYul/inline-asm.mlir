// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// A storage reference's .offset folds to 0.
// CHECK-LABEL: yul.func @storageOffset : (i256) -> i256
// CHECK:         %[[O:.*]] = llvm.alloca
// CHECK:         %[[OP:.*]] = builtin.unrealized_conversion_cast %[[O]] : !llvm.ptr to !yul.ptr
// CHECK:         %[[Z:.*]] = yul.constant 0
// CHECK:         yul.store %[[Z]], %[[OP]] : i256, !yul.ptr

// d.offset / d.length are the fields of the {offset, length} calldata slot.
// CHECK-LABEL: yul.func @calldataMembers : (!llvm.struct<(i256, i256)>) -> (i256, i256)
// CHECK:       ^bb0(%[[ARG:.*]]: !llvm.struct<(i256, i256)>):
// CHECK:         %[[D:.*]] = llvm.alloca %{{.*}} x !llvm.struct<(i256, i256)>
// CHECK:         llvm.store %[[ARG]], %[[D]]
// CHECK:         %[[O:.*]] = llvm.alloca
// CHECK:         %[[OP:.*]] = builtin.unrealized_conversion_cast %[[O]] : !llvm.ptr to !yul.ptr
// CHECK:         %[[L:.*]] = llvm.alloca
// CHECK:         %[[LP:.*]] = builtin.unrealized_conversion_cast %[[L]] : !llvm.ptr to !yul.ptr
// CHECK:         %[[DO:.*]] = llvm.getelementptr %[[D]][0, 0]
// CHECK:         %[[DOP:.*]] = builtin.unrealized_conversion_cast %[[DO]]
// CHECK:         %[[OV:.*]] = yul.load %[[DOP]]
// CHECK:         yul.store %[[OV]], %[[OP]]
// CHECK:         %[[DL:.*]] = llvm.getelementptr %[[D]][0, 1]
// CHECK:         %[[DLP:.*]] = builtin.unrealized_conversion_cast %[[DL]]
// CHECK:         %[[LV:.*]] = yul.load %[[DLP]]
// CHECK:         yul.store %[[LV]], %[[LP]]

// CHECK-LABEL: yul.func @constantRef : () -> i256
// CHECK:         %[[W:.*]] = llvm.alloca
// CHECK:         %[[WP:.*]] = builtin.unrealized_conversion_cast %[[W]] : !llvm.ptr to !yul.ptr
// CHECK:         %[[C42:.*]] = yul.constant 42
// CHECK:         yul.store %[[C42]], %[[WP]] : i256, !yul.ptr

// f.address / f.selector are the fields of the {address, selector} slot.
// CHECK-LABEL: yul.func @extFuncMembers : (!llvm.struct<(i256, i256)>) -> (i256, i256)
// CHECK:       ^bb0(%[[ARG:.*]]: !llvm.struct<(i256, i256)>):
// CHECK:         %[[A:.*]] = llvm.alloca
// CHECK:         %[[AP:.*]] = builtin.unrealized_conversion_cast %[[A]] : !llvm.ptr to !yul.ptr
// CHECK:         %[[S:.*]] = llvm.alloca
// CHECK:         %[[SP:.*]] = builtin.unrealized_conversion_cast %[[S]] : !llvm.ptr to !yul.ptr
// CHECK:         %[[F:.*]] = llvm.alloca %{{.*}} x !llvm.struct<(i256, i256)>
// CHECK:         llvm.store %[[ARG]], %[[F]]
// CHECK:         %[[FA:.*]] = llvm.getelementptr %[[F]][0, 0]
// CHECK:         %[[FAP:.*]] = builtin.unrealized_conversion_cast %[[FA]]
// CHECK:         %[[AV:.*]] = yul.load %[[FAP]]
// CHECK:         yul.store %[[AV]], %[[AP]]
// CHECK:         %[[FS:.*]] = llvm.getelementptr %[[F]][0, 1]
// CHECK:         %[[FSP:.*]] = builtin.unrealized_conversion_cast %[[FS]]
// CHECK:         %[[SV:.*]] = yul.load %[[FSP]]
// CHECK:         yul.store %[[SV]], %[[SP]]

// .slot/.offset fold to the storage layout.
// CHECK-LABEL: yul.func @slotOffset : () -> (i256, i256)
// CHECK:         %[[SL:.*]] = llvm.alloca
// CHECK:         %[[S:.*]] = builtin.unrealized_conversion_cast %[[SL]] : !llvm.ptr to !yul.ptr
// CHECK:         %[[OL:.*]] = llvm.alloca
// CHECK:         %[[O:.*]] = builtin.unrealized_conversion_cast %[[OL]] : !llvm.ptr to !yul.ptr
// CHECK:         %[[C1:.*]] = yul.constant 1
// CHECK:         yul.store %[[C1]], %[[S]]
// CHECK:         %[[C2:.*]] = yul.constant 2
// CHECK:         yul.store %[[C2]], %[[O]]

// CHECK-LABEL: yul.func @extRef : (i256) -> i256
// CHECK:       ^bb0(%[[ARG:.*]]: i256):
// CHECK:         %[[X:.*]] = llvm.alloca
// CHECK:         %[[XP:.*]] = builtin.unrealized_conversion_cast %[[X]] : !llvm.ptr to !yul.ptr
// CHECK:         llvm.store %[[ARG]], %[[X]]
// CHECK:         %[[V:.*]] = yul.load %[[XP]] : !yul.ptr -> i256
// CHECK:         %[[C1:.*]] = yul.constant 1
// CHECK:         %[[ADD:.*]] = yul.add %[[V]], %[[C1]]
// CHECK:         yul.store %[[ADD]], %[[XP]] : i256, !yul.ptr
// CHECK:         %[[RET:.*]] = llvm.load %[[X]]
// CHECK:         yul.func_return %[[RET]] : i256

// p.slot := sb.slot rewrites p's stack slot to 3.
// CHECK-LABEL: yul.func @slotRewrite : (i256) -> i256
// CHECK:       ^bb0(%[[ARG:.*]]: i256):
// CHECK:         %[[P:.*]] = llvm.alloca
// CHECK:         %[[PP:.*]] = builtin.unrealized_conversion_cast %[[P]] : !llvm.ptr to !yul.ptr
// CHECK:         llvm.store %[[ARG]], %[[P]]
// CHECK:         %[[C3:.*]] = yul.constant 3
// CHECK:         yul.store %[[C3]], %[[PP]] : i256, !yul.ptr
// CHECK:         %[[PV:.*]] = llvm.load %[[P]]
// CHECK:         yul.func_return %[[PV]] : i256

#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#Pure = #sol<StateMutability Pure>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @storageOffset(%arg0: !sol.array<? x ui256, Storage>) -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    %1 = sol.alloca : !sol.ptr<!sol.array<? x ui256, Storage>, Stack>
    sol.store %arg0, %1 : !sol.array<? x ui256, Storage>, !sol.ptr<!sol.array<? x ui256, Storage>, Stack>
    sol.inline_asm {
      %3 = sol.yul_storage_offset %1 : !sol.ptr<!sol.array<? x ui256, Storage>, Stack>
      %4 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
      yul.store %3, %4 : i256, !yul.ptr
    }
    %2 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %2 : ui256
  }
  sol.func @calldataMembers(%arg0: !sol.string<CallData>) -> (ui256, ui256) {
    %0 = sol.alloca : !sol.ptr<!sol.string<CallData>, Stack>
    sol.store %arg0, %0 : !sol.string<CallData>, !sol.ptr<!sol.string<CallData>, Stack>
    %1 = sol.alloca : !sol.ptr<ui256, Stack>
    %2 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.inline_asm {
      %5 = sol.yul_calldata_offset %0 : !sol.ptr<!sol.string<CallData>, Stack> -> !yul.ptr
      %6 = yul.load %5 : !yul.ptr -> i256
      %7 = sol.yul_ptr_cast %1 : !sol.ptr<ui256, Stack> -> !yul.ptr
      yul.store %6, %7 : i256, !yul.ptr
      %8 = sol.yul_calldata_length %0 : !sol.ptr<!sol.string<CallData>, Stack> -> !yul.ptr
      %9 = yul.load %8 : !yul.ptr -> i256
      %10 = sol.yul_ptr_cast %2 : !sol.ptr<ui256, Stack> -> !yul.ptr
      yul.store %9, %10 : i256, !yul.ptr
    }
    %3 = sol.load %1 : !sol.ptr<ui256, Stack>, ui256
    %4 = sol.load %2 : !sol.ptr<ui256, Stack>, ui256
    sol.return %3, %4 : ui256, ui256
  }
  sol.func @constantRef() -> ui256 {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    sol.inline_asm {
      %c42_ui256 = sol.constant 42 : ui256
      %2 = sol.yul_val_cast %c42_ui256 : ui256 -> i256
      %3 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
      yul.store %2, %3 : i256, !yul.ptr
    }
    %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    sol.return %1 : ui256
  }
  sol.func @extFuncMembers(%arg0: !sol.ext_func_ref<() -> ()>) -> (ui256, ui256) {
    %0 = sol.alloca : !sol.ptr<ui256, Stack>
    %1 = sol.alloca : !sol.ptr<ui256, Stack>
    %2 = sol.alloca : !sol.ptr<!sol.ext_func_ref<() -> ()>, Stack>
    sol.store %arg0, %2 : !sol.ext_func_ref<() -> ()>, !sol.ptr<!sol.ext_func_ref<() -> ()>, Stack>
    sol.inline_asm {
      %5 = sol.yul_address_of %2 : !sol.ptr<!sol.ext_func_ref<() -> ()>, Stack> -> !yul.ptr
      %6 = yul.load %5 : !yul.ptr -> i256
      %7 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
      yul.store %6, %7 : i256, !yul.ptr
      %8 = sol.yul_selector %2 : !sol.ptr<!sol.ext_func_ref<() -> ()>, Stack> -> !yul.ptr
      %9 = yul.load %8 : !yul.ptr -> i256
      %10 = sol.yul_ptr_cast %1 : !sol.ptr<ui256, Stack> -> !yul.ptr
      yul.store %9, %10 : i256, !yul.ptr
    }
    %3 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
    %4 = sol.load %1 : !sol.ptr<ui256, Stack>, ui256
    sol.return %3, %4 : ui256, ui256
  }
  sol.contract @C {
    sol.state_var @b slot 1 offset 2 : ui8
    sol.state_var @sb slot 3 offset 0 : !sol.array<? x ui256, Storage>
    sol.func @slotRewrite(%arg0: !sol.array<? x ui256, Storage>) -> !sol.array<? x ui256, Storage> attributes {state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<!sol.array<? x ui256, Storage>, Stack>
      sol.store %arg0, %0 : !sol.array<? x ui256, Storage>, !sol.ptr<!sol.array<? x ui256, Storage>, Stack>
      sol.inline_asm {
        %2 = sol.yul_state_var_slot @sb
        %3 = sol.yul_storage_slot %0 : !sol.ptr<!sol.array<? x ui256, Storage>, Stack> -> !yul.ptr
        yul.store %2, %3 : i256, !yul.ptr
      }
      %1 = sol.load %0 : !sol.ptr<!sol.array<? x ui256, Storage>, Stack>, !sol.array<? x ui256, Storage>
      sol.return %1 : !sol.array<? x ui256, Storage>
    }
    sol.func @extRef(%arg0: ui256) -> ui256 attributes {state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.store %arg0, %0 : ui256, !sol.ptr<ui256, Stack>
      sol.inline_asm {
        %2 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
        %3 = yul.load %2 : !yul.ptr -> i256
        %c1_i256 = yul.constant 1
        %4 = yul.add %3, %c1_i256
        %5 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
        yul.store %4, %5 : i256, !yul.ptr
      }
      %1 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      sol.return %1 : ui256
    }
    sol.func @slotOffset() -> (ui256, ui256) attributes {state_mutability = #Pure} {
      %0 = sol.alloca : !sol.ptr<ui256, Stack>
      %1 = sol.alloca : !sol.ptr<ui256, Stack>
      sol.inline_asm {
        %4 = sol.yul_state_var_slot @b
        %5 = sol.yul_ptr_cast %0 : !sol.ptr<ui256, Stack> -> !yul.ptr
        yul.store %4, %5 : i256, !yul.ptr
        %6 = sol.yul_state_var_offset @b
        %7 = sol.yul_ptr_cast %1 : !sol.ptr<ui256, Stack> -> !yul.ptr
        yul.store %6, %7 : i256, !yul.ptr
      }
      %2 = sol.load %0 : !sol.ptr<ui256, Stack>, ui256
      %3 = sol.load %1 : !sol.ptr<ui256, Stack>, ui256
      sol.return %2, %3 : ui256, ui256
    }
  } {kind = #Contract}
}
