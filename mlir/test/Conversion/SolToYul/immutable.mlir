// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// Immutables are staged in reserved memory at 128 + 32k, in declaration
// order, until the deploy code copies them into the runtime object.
// CHECK-LABEL: yul.object @C {
// CHECK:         yul.memoryguard 320
// CHECK:         yul.func_call @C()
// CHECK:         %[[RT:.*]] = yul.mload
// CHECK:         %[[C128:.*]] = yul.constant 128
// CHECK:         %[[A:.*]] = yul.mload %[[C128]]
// CHECK:         yul.setimmutable %[[RT]], "a", %[[A]]
// CHECK:         %[[C160:.*]] = yul.constant 160
// CHECK:         %[[B:.*]] = yul.mload %[[C160]]
// CHECK:         yul.setimmutable %[[RT]], "b", %[[B]]
// CHECK:         %[[C192:.*]] = yul.constant 192
// CHECK:         %[[F:.*]] = yul.mload %[[C192]]
// CHECK:         yul.setimmutable %[[RT]], "f", %[[F]]
// CHECK:         %[[C224:.*]] = yul.constant 224
// CHECK:         %[[I:.*]] = yul.mload %[[C224]]
// CHECK:         yul.setimmutable %[[RT]], "i", %[[I]]
// CHECK:         %[[C256:.*]] = yul.constant 256
// CHECK:         %[[J:.*]] = yul.mload %[[C256]]
// CHECK:         yul.setimmutable %[[RT]], "j", %[[J]]
// CHECK:         %[[C288:.*]] = yul.constant 288
// CHECK:         %[[H:.*]] = yul.mload %[[C288]]
// CHECK:         yul.setimmutable %[[RT]], "h", %[[H]]

// CHECK-LABEL: yul.func @init : () -> ()
// CHECK:         %[[C4:.*]] = yul.constant 4
// CHECK:         %[[C288:.*]] = yul.constant 288
// CHECK-NEXT:    yul.mstore %[[C288]], %[[C4]]

// Stores clean a non-constant value per type and store a constant as is; the
// function-typed immutable holds g's internal function id; a read in the ctor
// loads the staged slot.
// CHECK-LABEL: yul.func @C : () -> ()
// CHECK:         yul.func_call @init()
// CHECK:         %[[C128:.*]] = yul.constant 128
// CHECK:         %[[CM2:.*]] = yul.constant -2
// CHECK-NEXT:    yul.mstore %[[C128]], %[[CM2]]
// CHECK:         %[[C160:.*]] = yul.constant 160
// CHECK:         %[[AB:.*]] = yul.constant 24930
// CHECK:         %[[C240:.*]] = yul.constant 240
// CHECK:         %[[SHL:.*]] = yul.arith_shl %[[AB]], %[[C240]]
// CHECK:         %[[B:.*]] = yul.and %[[SHL]], %{{.*}}
// CHECK:         yul.mstore %[[C160]], %[[B]]
// CHECK:         %[[C192:.*]] = yul.constant 192
// CHECK:         %[[G:.*]] = yul.constant 34
// CHECK:         yul.mstore %[[C192]], %[[G]]
// CHECK:         %[[C224:.*]] = yul.constant 224
// CHECK:         %[[ONE:.*]] = yul.constant 1
// CHECK:         yul.mstore %[[C224]], %[[ONE]]
// CHECK:         %[[V:.*]] = yul.mload %[[C224]]
// CHECK:         %[[C256:.*]] = yul.constant 256
// CHECK:         yul.mstore %[[C256]], %[[V]]

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    sol.immutable @a index 0 : si8
    sol.immutable @b index 1 : !sol.fixedbytes<2>
    sol.immutable @f index 2 : !sol.func_ref<() -> ()>
    sol.immutable @i index 3 : ui256
    sol.immutable @j index 4 : ui256
    sol.immutable @h index 5 : ui8
    sol.func @C() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.call @init() : () -> ()
      %0 = sol.addr_of @a : !sol.ptr<si8, Immutable>
      %c-2_si8 = sol.constant -2 : si8
      sol.store %c-2_si8, %0 : si8, !sol.ptr<si8, Immutable>
      %1 = sol.addr_of @b : !sol.ptr<!sol.fixedbytes<2>, Immutable>
      %c24930_ui16 = sol.constant 24930 : ui16
      %2 = sol.bytes_cast %c24930_ui16 : ui16 to !sol.fixedbytes<2>
      sol.store %2, %1 : !sol.fixedbytes<2>, !sol.ptr<!sol.fixedbytes<2>, Immutable>
      %3 = sol.addr_of @f : !sol.ptr<!sol.func_ref<() -> ()>, Immutable>
      %4 = sol.func_constant @g : !sol.func_ref<() -> ()>
      sol.store %4, %3 : !sol.func_ref<() -> ()>, !sol.ptr<!sol.func_ref<() -> ()>, Immutable>
      %5 = sol.addr_of @i : !sol.ptr<ui256, Immutable>
      %c1_ui256 = sol.constant 1 : ui256
      sol.store %c1_ui256, %5 : ui256, !sol.ptr<ui256, Immutable>
      %6 = sol.load %5 : !sol.ptr<ui256, Immutable>, ui256
      %7 = sol.addr_of @j : !sol.ptr<ui256, Immutable>
      sol.store %6, %7 : ui256, !sol.ptr<ui256, Immutable>
      sol.return
    }
    sol.func @init() {
      %c4_ui8 = sol.constant 4 : ui8
      %0 = sol.addr_of @h : !sol.ptr<ui8, Immutable>
      sol.store %c4_ui8, %0 : ui8, !sol.ptr<ui8, Immutable>
      sol.return
    }
    sol.func @g() attributes {id = 34 : i64, state_mutability = #Pure} {
      sol.return
    }
  } {kind = #Contract}
}

// -----

// CHECK-LABEL: yul.object @C_deployed {
// CHECK-LABEL: yul.func @get : () -> i256
// CHECK:         %[[I:.*]] = yul.loadimmutable "i"
// CHECK:         yul.func_return %[[I]] : i256

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    sol.immutable @i index 0 : ui256
    sol.func @get() -> ui256 attributes {state_mutability = #NonPayable} {
      %0 = sol.load_immutable @i : ui256
      sol.return %0 : ui256
    }
  } {kind = #Contract, runtime}
}
