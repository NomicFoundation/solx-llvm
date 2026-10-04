// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @addr : (i256) -> i256
// CHECK:         %[[M:.*]] = yul.constant 1461501637330902918203684832716283019655932542975{{$}}
// CHECK:         yul.and %arg0, %[[M]]
// CHECK:         %[[FM:.*]] = yul.constant 1461501637330902918203684832716283019655932542975{{$}}
// CHECK:         yul.arith_shl %[[FM]], %{{.*}}
// CHECK:         yul.sstore
// CHECK:         %[[LM:.*]] = yul.constant 1461501637330902918203684832716283019655932542975{{$}}
// CHECK:         %[[R:.*]] = yul.and %{{.*}}, %[[LM]]
// CHECK:         yul.func_return %[[R]]

// bytes4 is left-aligned on the stack and right-aligned in its slot field.
// CHECK-LABEL: yul.func @bytes4 : (i256) -> i256
// CHECK:         %[[V:.*]] = yul.and %arg0, %{{.*}}
// CHECK:         %[[C224:.*]] = yul.constant 224{{$}}
// CHECK:         yul.arith_shr %[[V]], %[[C224]]
// CHECK:         %[[FM:.*]] = yul.constant 4294967295{{$}}
// CHECK:         yul.arith_shl %[[FM]], %{{.*}}
// CHECK:         yul.sstore
// CHECK:         %[[L:.*]] = yul.arith_shr
// CHECK:         %[[L224:.*]] = yul.constant 224{{$}}
// CHECK:         %[[R:.*]] = yul.arith_shl %[[L]], %[[L224]]
// CHECK:         yul.func_return %[[R]]

// CHECK-LABEL: yul.func @ui256 : (i256) -> i256
// CHECK-NOT:     yul.and %arg0
// CHECK:         %[[FM:.*]] = yul.constant -1{{$}}
// CHECK:         yul.arith_shl %[[FM]], %{{.*}}
// CHECK:         yul.arith_shl %arg0, %{{.*}}
// CHECK:         yul.sstore
// CHECK:         %[[R:.*]] = yul.arith_shr
// CHECK-NEXT:    yul.func_return %[[R]]

// A bool takes a whole byte in its slot.
// CHECK-LABEL: yul.func @bool : (i256) -> i256
// CHECK:         %[[V:.*]] = yul.cmp ne, %arg0, %{{.*}}
// CHECK:         %[[FM:.*]] = yul.constant 255{{$}}
// CHECK:         yul.arith_shl %[[FM]], %{{.*}}
// CHECK:         yul.arith_shl %[[V]], %{{.*}}
// CHECK:         yul.sstore
// CHECK:         %[[L:.*]] = yul.arith_shr
// CHECK:         %[[LM:.*]] = yul.constant 255{{$}}
// CHECK:         %[[B:.*]] = yul.and %[[L]], %[[LM]]
// CHECK:         %[[R:.*]] = yul.cmp ne, %[[B]], %{{.*}}
// CHECK:         yul.func_return %[[R]]

// The stored enum is range-checked (panic 0x21).
// CHECK-LABEL: yul.func @enum : (i256) -> i256
// CHECK:         %[[MAX:.*]] = yul.constant 2{{$}}
// CHECK:         yul.cmp ugt, %arg0, %[[MAX]]
// CHECK:         yul.constant 33{{$}}
// CHECK:         %[[FM:.*]] = yul.constant 255{{$}}
// CHECK:         yul.arith_shl %[[FM]], %{{.*}}
// CHECK:         yul.arith_shl %arg0, %{{.*}}
// CHECK:         yul.sstore
// CHECK:         %[[L:.*]] = yul.arith_shr
// CHECK:         %[[LM:.*]] = yul.constant 255{{$}}
// CHECK:         %[[R:.*]] = yul.and %[[L]], %[[LM]]
// CHECK:         yul.func_return %[[R]]

// The sign-extended value is masked back to its field width before the store.
// CHECK-LABEL: yul.func @si16 : (i256) -> i256
// CHECK:         %[[SX:.*]] = yul.signextend %{{.*}}, %arg0
// CHECK:         %[[M:.*]] = yul.constant 65535{{$}}
// CHECK:         %[[V:.*]] = yul.and %[[SX]], %[[M]]
// CHECK:         %[[FM:.*]] = yul.constant 65535{{$}}
// CHECK:         yul.arith_shl %[[FM]], %{{.*}}
// CHECK:         yul.arith_shl %[[V]], %{{.*}}
// CHECK:         yul.sstore
// CHECK:         %[[L:.*]] = yul.arith_shr
// CHECK:         %[[R:.*]] = yul.signextend %{{.*}}, %[[L]]
// CHECK:         yul.func_return %[[R]]

// A state var is a (slot, byte offset) pair; the write clears the field's bits
// before or-ing the value in, the read shifts by offset*8 and masks.
// CHECK-LABEL: yul.func @ui8 : (i256) -> i256
// CHECK:         %[[S:.*]] = yul.constant 0{{$}}
// CHECK-NEXT:    %[[O:.*]] = yul.constant 1{{$}}
// CHECK:         llvm.insertvalue %[[S]], %{{.*}}[0]
// CHECK:         llvm.insertvalue %[[O]], %{{.*}}[1]
// CHECK:         %[[SLOT:.*]] = llvm.extractvalue %{{.*}}[0]
// CHECK:         %[[OFF:.*]] = llvm.extractvalue %{{.*}}[1]
// CHECK:         %[[M:.*]] = yul.constant 255{{$}}
// CHECK:         %[[V:.*]] = yul.and %arg0, %[[M]]
// CHECK:         %[[SH:.*]] = yul.mul %[[OFF]], %{{.*}}
// CHECK:         %[[OLD:.*]] = yul.sload %[[SLOT]]
// CHECK:         %[[FM:.*]] = yul.constant 255{{$}}
// CHECK:         %[[HOLE:.*]] = yul.arith_shl %[[FM]], %[[SH]]
// CHECK:         %[[INV:.*]] = yul.xor %[[HOLE]], %{{.*}}
// CHECK:         %[[CLR:.*]] = yul.and %[[OLD]], %[[INV]]
// CHECK:         %[[VSH:.*]] = yul.arith_shl %[[V]], %[[SH]]
// CHECK:         %[[NEW:.*]] = yul.or %[[CLR]], %[[VSH]]
// CHECK:         yul.sstore %[[SLOT]], %[[NEW]]
// CHECK:         %[[LSLOT:.*]] = llvm.extractvalue %{{.*}}[0]
// CHECK:         %[[LOFF:.*]] = llvm.extractvalue %{{.*}}[1]
// CHECK:         %[[LD:.*]] = yul.sload %[[LSLOT]]
// CHECK:         %[[LSH:.*]] = yul.mul %[[LOFF]], %{{.*}}
// CHECK:         %[[L:.*]] = yul.arith_shr %[[LD]], %[[LSH]]
// CHECK:         %[[LM:.*]] = yul.constant 255{{$}}
// CHECK:         %[[R:.*]] = yul.and %[[L]], %[[LM]]
// CHECK:         yul.func_return %[[R]]

// An internal function pointer is a 64-bit field.
// CHECK-LABEL: yul.func @fnptr : (i256) -> i256
// CHECK:         %[[M:.*]] = yul.constant 18446744073709551615{{$}}
// CHECK:         %[[V:.*]] = yul.and %arg0, %[[M]]
// CHECK:         %[[FM:.*]] = yul.constant 18446744073709551615{{$}}
// CHECK:         yul.arith_shl %[[FM]], %{{.*}}
// CHECK:         yul.arith_shl %[[V]], %{{.*}}
// CHECK:         yul.sstore
// CHECK:         %[[L:.*]] = yul.arith_shr
// CHECK:         %[[LM:.*]] = yul.constant 18446744073709551615{{$}}
// CHECK:         %[[R:.*]] = yul.and %[[L]], %[[LM]]
// CHECK:         yul.func_return %[[R]]

// A transient state var takes the storage path with tload/tstore.
// CHECK-LABEL: yul.func @transient : (i256) -> i256
// CHECK:         %[[SLOT:.*]] = llvm.extractvalue %{{.*}}[0]
// CHECK:         %[[OLD:.*]] = yul.tload %[[SLOT]]
// CHECK:         %[[CLR:.*]] = yul.and %[[OLD]], %{{.*}}
// CHECK:         %[[NEW:.*]] = yul.or %[[CLR]], %{{.*}}
// CHECK:         yul.tstore %[[SLOT]], %[[NEW]]
// CHECK:         %[[LSLOT:.*]] = llvm.extractvalue %{{.*}}[0]
// CHECK:         yul.tload %[[LSLOT]]
// CHECK-NOT:     yul.sload
// CHECK:         yul.func_return

#Contract = #sol<ContractKind Contract>
module {
  sol.contract @C {
    sol.state_var @a slot 0 offset 1 : ui8
    sol.state_var @b slot 0 offset 2 : si16
    sol.state_var @c slot 0 offset 4 : !sol.enum<2>
    sol.state_var @d slot 0 offset 0 : i1
    sol.state_var @e slot 1 offset 0 : ui256
    sol.state_var @f slot 2 offset 0 : !sol.fixedbytes<4>
    sol.state_var @g slot 2 offset 4 : !sol.address
    sol.state_var @h slot 3 offset 0 : !sol.func_ref<(ui256) -> ui256>
    sol.state_var @i transient slot 1 offset 2 : ui8
    sol.func @transient(%v: ui8) -> ui8 {
      %p = sol.addr_of @i : !sol.ptr<ui8, Transient>
      sol.store %v, %p : ui8, !sol.ptr<ui8, Transient>
      %r = sol.load %p : !sol.ptr<ui8, Transient>, ui8
      sol.return %r : ui8
    }
    sol.func @fnptr(%v: !sol.func_ref<(ui256) -> ui256>) -> !sol.func_ref<(ui256) -> ui256> {
      %p = sol.addr_of @h : !sol.ptr<!sol.func_ref<(ui256) -> ui256>, Storage>
      sol.store %v, %p : !sol.func_ref<(ui256) -> ui256>, !sol.ptr<!sol.func_ref<(ui256) -> ui256>, Storage>
      %r = sol.load %p : !sol.ptr<!sol.func_ref<(ui256) -> ui256>, Storage>, !sol.func_ref<(ui256) -> ui256>
      sol.return %r : !sol.func_ref<(ui256) -> ui256>
    }
    sol.func @ui8(%v: ui8) -> ui8 {
      %p = sol.addr_of @a : !sol.ptr<ui8, Storage>
      sol.store %v, %p : ui8, !sol.ptr<ui8, Storage>
      %r = sol.load %p : !sol.ptr<ui8, Storage>, ui8
      sol.return %r : ui8
    }
    sol.func @si16(%v: si16) -> si16 {
      %p = sol.addr_of @b : !sol.ptr<si16, Storage>
      sol.store %v, %p : si16, !sol.ptr<si16, Storage>
      %r = sol.load %p : !sol.ptr<si16, Storage>, si16
      sol.return %r : si16
    }
    sol.func @enum(%v: !sol.enum<2>) -> !sol.enum<2> {
      %p = sol.addr_of @c : !sol.ptr<!sol.enum<2>, Storage>
      sol.store %v, %p : !sol.enum<2>, !sol.ptr<!sol.enum<2>, Storage>
      %r = sol.load %p : !sol.ptr<!sol.enum<2>, Storage>, !sol.enum<2>
      sol.return %r : !sol.enum<2>
    }
    sol.func @bool(%v: i1) -> i1 {
      %p = sol.addr_of @d : !sol.ptr<i1, Storage>
      sol.store %v, %p : i1, !sol.ptr<i1, Storage>
      %r = sol.load %p : !sol.ptr<i1, Storage>, i1
      sol.return %r : i1
    }
    sol.func @ui256(%v: ui256) -> ui256 {
      %p = sol.addr_of @e : !sol.ptr<ui256, Storage>
      sol.store %v, %p : ui256, !sol.ptr<ui256, Storage>
      %r = sol.load %p : !sol.ptr<ui256, Storage>, ui256
      sol.return %r : ui256
    }
    sol.func @bytes4(%v: !sol.fixedbytes<4>) -> !sol.fixedbytes<4> {
      %p = sol.addr_of @f : !sol.ptr<!sol.fixedbytes<4>, Storage>
      sol.store %v, %p : !sol.fixedbytes<4>, !sol.ptr<!sol.fixedbytes<4>, Storage>
      %r = sol.load %p : !sol.ptr<!sol.fixedbytes<4>, Storage>, !sol.fixedbytes<4>
      sol.return %r : !sol.fixedbytes<4>
    }
    sol.func @addr(%v: !sol.address) -> !sol.address {
      %p = sol.addr_of @g : !sol.ptr<!sol.address, Storage>
      sol.store %v, %p : !sol.address, !sol.ptr<!sol.address, Storage>
      %r = sol.load %p : !sol.ptr<!sol.address, Storage>, !sol.address
      sol.return %r : !sol.address
    }
  } {kind = #Contract}
}
