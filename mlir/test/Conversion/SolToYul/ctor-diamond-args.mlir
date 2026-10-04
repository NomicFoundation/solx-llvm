// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// The constructor's args are decoded from the code appended after the creation
// object, and a function both codes reach is in both objects. A payable
// constructor gets no callvalue check.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Payable = #sol<StateMutability Payable>

// CHECK-LABEL: yul.object @D {
// CHECK-NOT:     yul.callvalue
// CHECK:         %[[SIZE:.*]] = yul.datasize {obj = @D}
// CHECK:         %[[CODE:.*]] = yul.codesize
// CHECK:         %[[ARGSZ:.*]] = yul.sub %[[CODE]], %[[SIZE]]
// CHECK:         yul.codecopy %[[BUF:.*]], %[[SIZE]], %[[ARGSZ]]
// CHECK:         %[[END:.*]] = yul.add %[[BUF]], %[[ARGSZ]]
// CHECK:         %[[TSIZE:.*]] = yul.sub %[[END]], %[[BUF]]
// CHECK:         yul.cmp slt, %[[TSIZE]], %{{.*}}
// CHECK:         %[[A:.*]] = yul.mload %[[BUF]]
// CHECK:         %[[P:.*]] = yul.add %[[BUF]], %{{.*}}
// CHECK:         %[[B:.*]] = yul.mload %[[P]]
// CHECK:         yul.func_call @D(%[[A]], %[[B]]) : (i256, i256) -> ()
// CHECK-LABEL:   yul.func @h : (i256, i256) -> ()
// CHECK-LABEL:   yul.func @g : (i256, i256) -> ()
// CHECK:           yul.func_call @h(%arg0, %arg1)
// CHECK-LABEL:   yul.func @f : (i256, i256) -> ()
// CHECK:           yul.func_call @g(%arg0, %arg1)
// CHECK-LABEL:   yul.func @D : (i256, i256) -> ()
// CHECK:           yul.func_call @f(%arg1, %arg0)

module {
  sol.contract @D {
    sol.func @D(%arg0: ui256, %arg1: ui256) attributes {kind = #Constructor, orig_fn_type = (ui256, ui256) -> (), state_mutability = #Payable} {
      sol.call @f(%arg1, %arg0) : (ui256, ui256) -> ()
      sol.return
    }
    sol.func @f(%arg0: ui256, %arg1: ui256) {
      sol.call @g(%arg0, %arg1) : (ui256, ui256) -> ()
      sol.return
    }
    sol.func @g(%arg0: ui256, %arg1: ui256) {
      sol.call @h(%arg0, %arg1) : (ui256, ui256) -> ()
      sol.return
    }
    sol.func @h(%arg0: ui256, %arg1: ui256) {
      sol.return
    }
  } {kind = #Contract}
}

// -----

#Contract = #sol<ContractKind Contract>

// CHECK-LABEL: yul.object @D_deployed {
// CHECK-LABEL:   yul.func @h : (i256, i256) -> ()
// CHECK-LABEL:   yul.func @g : (i256, i256) -> ()
// CHECK-LABEL:   yul.func @f : (i256, i256) -> ()

module {
  sol.contract @D {
    sol.func @f(%arg0: ui256, %arg1: ui256) {
      sol.call @g(%arg0, %arg1) : (ui256, ui256) -> ()
      sol.return
    }
    sol.func @g(%arg0: ui256, %arg1: ui256) {
      sol.call @h(%arg0, %arg1) : (ui256, ui256) -> ()
      sol.return
    }
    sol.func @h(%arg0: ui256, %arg1: ui256) {
      sol.return
    }
  } {kind = #Contract, runtime}
}
