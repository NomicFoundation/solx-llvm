// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// The two string constructor args are decoded from the appended code into
// fresh memory copies by the tuple decoder helper.
// CHECK-LABEL: yul.object @ERC20 {
// CHECK-LABEL:   yul.func @__sol.abi_decode_tuple.memory.string$_Memory_$.string$_Memory_$ : (i256, i256) -> (i256, i256)
// CHECK:           yul.mcopy
// CHECK:           yul.mcopy
// CHECK-LABEL:   yul.func @ctor : (i256, i256) -> ()
// CHECK:         ^bb0(%[[NAME:.*]]: i256, %[[SYM:.*]]: i256):
// CHECK:           %[[S1:.*]] = yul.constant 1{{$}}
// CHECK:           yul.func_call @__sol.copy_string.memory.storage(%[[NAME]], %[[S1]])
// CHECK:           %[[S2:.*]] = yul.constant 2{{$}}
// CHECK:           yul.func_call @__sol.copy_string.memory.storage(%[[SYM]], %[[S2]])
// CHECK:         yul.codecopy
// CHECK:         %[[ARGS:.*]]:2 = yul.func_call @__sol.abi_decode_tuple.memory.string$_Memory_$.string$_Memory_$(%{{.*}}, %{{.*}}) : (i256, i256) -> (i256, i256)
// CHECK:         yul.func_call @ctor(%[[ARGS]]#0, %[[ARGS]]#1) : (i256, i256) -> ()
module {
  sol.contract @ERC20 {
    sol.state_var @name slot 1 offset 0 : !sol.string<Storage>
    sol.state_var @symbol slot 2 offset 0 : !sol.string<Storage>
    sol.func @ctor(%name: !sol.string<Memory>, %symbol: !sol.string<Memory>) attributes {kind = #Constructor, orig_fn_type = (!sol.string<Memory>, !sol.string<Memory>) -> (), state_mutability = #NonPayable} {
      %0 = sol.addr_of @name : !sol.string<Storage>
      sol.copy %name, %0 : !sol.string<Memory>, !sol.string<Storage>
      %1 = sol.addr_of @symbol : !sol.string<Storage>
      sol.copy %symbol, %1 : !sol.string<Memory>, !sol.string<Storage>
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

// CHECK-LABEL:   yul.object @ERC20_deployed {
// CHECK-LABEL:     yul.func @transfer : (i256, i256, i256) -> ()
// CHECK:           ^bb0(%[[FROM:.*]]: i256, %[[TO:.*]]: i256, %[[AMT:.*]]: i256):
// CHECK:             yul.keccak256
// CHECK:             yul.sload
// CHECK:             %[[OK:.*]] = yul.cmp uge, %{{.*}}, %[[AMT]]
// CHECK:             %[[FAIL:.*]] = yul.cmp eq, %[[OK]], %{{.*}}
// CHECK:             yul.if %[[FAIL]] {
// CHECK:               yul.constant 3963877391197344453575983046348115674221700746820753546331534351508065746944{{$}}
// CHECK:               yul.constant 38{{$}}
// CHECK:               yul.revert
// CHECK:             yul.sub
// CHECK:             yul.sstore
// CHECK:             yul.add
// CHECK:             yul.sstore
// CHECK:             %[[TOPIC:.*]] = yul.constant -15402802100530019096323380498944738953123845089667699673314898783681816316945{{$}}
// CHECK:             %[[T1:.*]] = yul.and %[[FROM]],
// CHECK:             %[[T2:.*]] = yul.and %[[TO]],
// CHECK:             yul.func_call @__sol.abi_encode_tuple.padded.tail.ui256(%[[AMT]],
// CHECK:             yul.log %{{.*}}, %{{.*}} topics(%[[TOPIC]], %[[T1]], %[[T2]])
module {
  sol.contract @ERC20 {
    sol.state_var @balances slot 0 offset 0 : !sol.mapping<!sol.address, ui256>
    sol.func @transfer(%from: !sol.address, %to: !sol.address, %amt: ui256) attributes {state_mutability = #NonPayable} {
      %0 = sol.addr_of @balances : !sol.mapping<!sol.address, ui256>
      %1 = sol.map %0, %from : !sol.mapping<!sol.address, ui256>, !sol.address, !sol.ptr<ui256, Storage>
      %2 = sol.load %1 : !sol.ptr<ui256, Storage>, ui256
      %3 = sol.cmp ge, %2, %amt : ui256
      sol.require %3, "ERC20: transfer amount exceeds balance"
      %4 = sol.sub %2, %amt : ui256
      sol.store %4, %1 : ui256, !sol.ptr<ui256, Storage>
      %5 = sol.map %0, %to : !sol.mapping<!sol.address, ui256>, !sol.address, !sol.ptr<ui256, Storage>
      %6 = sol.load %5 : !sol.ptr<ui256, Storage>, ui256
      %7 = sol.add %6, %amt : ui256
      sol.store %7, %5 : ui256, !sol.ptr<ui256, Storage>
      sol.emit "Transfer(address,address,uint256)" indexed = [%from, %to] non_indexed = [%amt] : !sol.address, !sol.address, ui256
      sol.return
    }
  } {kind = #Contract, runtime}
}
