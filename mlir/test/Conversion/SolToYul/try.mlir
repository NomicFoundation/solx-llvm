// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

module {
  sol.contract @C {
    sol.func @use(%arg0: ui256) {
      sol.return
    }
    sol.func @useStr(%arg0: !sol.string<Memory>) {
      sol.return
    }

    // The first try catches only Panic: any other revert is re-thrown with the
    // callee's returndata. The second adds Error(string) and a bytes fallback.
    // CHECK-LABEL: yul.func @f : (i256, i256) -> ()
    // CHECK:         %[[S:.*]] = yul.call %arg1,
    // CHECK:         %[[OK:.*]] = yul.cmp ne, %[[S]], %{{.*}}
    // CHECK:         %[[R:.*]] = yul.if %[[OK]] -> i256 {
    // CHECK:         yul.if %[[OK]] {
    // CHECK:           yul.func_call @use(%[[R]])
    // CHECK:         } else {
    // CHECK:           %[[UNCAUGHT:.*]] = llvm.alloca
    // CHECK:           yul.returndatacopy
    // CHECK:           yul.switch
    // CHECK:           case 1313373041 {
    // CHECK:             llvm.store %{{.*}}, %[[UNCAUGHT]]
    // CHECK:             %[[C4:.*]] = yul.constant 4
    // CHECK:             %[[C32:.*]] = yul.constant 32
    // CHECK:             yul.returndatacopy %[[ZERO:.*]], %[[C4]], %[[C32]]
    // CHECK:             %[[CODE:.*]] = yul.mload %[[ZERO]]
    // CHECK:             yul.func_call @use(%[[CODE]])
    // CHECK:           %[[U:.*]] = llvm.load %[[UNCAUGHT]]
    // CHECK:           yul.if %[[U]] {
    // CHECK:             yul.returndatacopy
    // CHECK:             yul.revert
    // CHECK:         %[[S2:.*]] = yul.call %arg1,
    // CHECK:         %[[OK2:.*]] = yul.cmp ne, %[[S2]], %{{.*}}
    // CHECK:         yul.if %[[OK2]] {
    // CHECK:           yul.func_call @use
    // CHECK:         } else {
    // CHECK:           case 1313373041 {
    // CHECK:             yul.func_call @use
    // CHECK:           case 147028384 {
    // CHECK:             %[[C68:.*]] = yul.constant 68
    // CHECK:             %[[SIZEOK:.*]] = yul.cmp uge, %[[RDS:.*]], %[[C68]]
    // CHECK:             yul.if %[[SIZEOK]] {
    // CHECK:               %[[U64:.*]] = yul.constant 18446744073709551615
    // CHECK:               %[[C4E:.*]] = yul.constant 4{{$}}
    // CHECK:               %[[TSIZE:.*]] = yul.sub %[[RDS]], %[[C4E]]
    // CHECK:               %[[TUPLE:.*]] = yul.mload %c64_i256{{[_0-9]*}}
    // CHECK:               yul.returndatacopy %[[TUPLE]], %{{.*}}, %[[TSIZE]]
    // CHECK:               %[[OFF:.*]] = yul.mload %[[TUPLE]]
    // CHECK:               %[[OFFSMALL:.*]] = yul.cmp ule, %[[OFF]], %[[U64]]
    // CHECK:               %[[C36:.*]] = yul.constant 36
    // CHECK:               %[[OFFEND:.*]] = yul.add %[[OFF]], %[[C36]]
    // CHECK:               %[[OFFIN:.*]] = yul.cmp ule, %[[OFFEND]], %[[RDS]]
    // CHECK:               %[[OFFOK:.*]] = yul.and %[[OFFSMALL]], %[[OFFIN]]
    // CHECK:               yul.if %[[OFFOK]] {
    // CHECK:                 %[[MSG:.*]] = yul.add %[[TUPLE]], %[[OFF]]
    // CHECK:                 %[[LEN:.*]] = yul.mload %[[MSG]]
    // CHECK:                 %[[LENSMALL:.*]] = yul.cmp ule, %[[LEN]], %[[U64]]
    // CHECK:                 %[[BODY:.*]] = yul.add %[[MSG]], %{{.*}}
    // CHECK:                 %[[MSGEND:.*]] = yul.add %[[BODY]], %[[LEN]]
    // CHECK:                 %[[DATAEND:.*]] = yul.add %[[TUPLE]], %[[TSIZE]]
    // CHECK:                 %[[LENIN:.*]] = yul.cmp ule, %[[MSGEND]], %[[DATAEND]]
    // CHECK:                 %[[LENOK:.*]] = yul.and %[[LENSMALL]], %[[LENIN]]
    // CHECK:                 yul.if %[[LENOK]] {
    // CHECK:                   %[[USED:.*]] = yul.sub %[[MSGEND]], %[[TUPLE]]
    // CHECK:                   %[[FREE:.*]] = yul.add %[[TUPLE]], %{{.*}}
    // CHECK:                   yul.mstore %c64_i256{{[_0-9]*}}, %[[FREE]]
    // CHECK:                   yul.func_call @useStr(%[[MSG]])
    // CHECK:           %[[FB:.*]] = llvm.load
    // CHECK:           yul.if %[[FB]] {
    // CHECK:             %[[N:.*]] = yul.returndatasize
    // CHECK:             %[[EMPTY:.*]] = yul.cmp eq, %[[N]], %{{.*}}
    // CHECK:             %[[BYTES:.*]] = yul.if %[[EMPTY]] -> i256 {
    // CHECK:               yul.yield %c96_i256 : i256
    // CHECK:             } else {
    // CHECK:               %[[BUF:.*]] = yul.func_call @__sol.alloc(
    // CHECK:               yul.mstore %[[BUF]], %[[N]]
    // CHECK:               %[[DATA:.*]] = yul.add %[[BUF]], %{{.*}}
    // CHECK:               yul.returndatacopy %[[DATA]], %{{.*}}, %[[N]]
    // CHECK:               yul.yield %[[BUF]] : i256
    // CHECK:             yul.func_call @useStr(%[[BYTES]])
    // CHECK-NOT:         yul.revert
    // CHECK:         yul.func_return
    sol.func @f(%arg0: !sol.address, %arg1: ui256) {
      %c3017696395_ui256 = sol.constant 3017696395 : ui256
      %c0_ui256 = sol.constant 0 : ui256
      %status, %outs = sol.ext_call "f"(%c0_ui256) at %arg0 gas %arg1 value %c0_ui256 selector %c3017696395_ui256 {callee_type = (ui256) -> ui256, try_call} : !sol.address, (ui256) -> (i1, ui256)
      sol.try %status {
        sol.call @use(%outs) : (ui256) -> ()
        sol.yield
      } panic {
      ^bb0(%arg2: ui256):
        sol.call @use(%arg2) : (ui256) -> ()
        sol.yield
      } error {
      } fallback {
      }
      %status_0, %outs_1 = sol.ext_call "f"(%c0_ui256) at %arg0 gas %arg1 value %c0_ui256 selector %c3017696395_ui256 {callee_type = (ui256) -> ui256, try_call} : !sol.address, (ui256) -> (i1, ui256)
      sol.try %status_0 {
        sol.call @use(%outs_1) : (ui256) -> ()
        sol.yield
      } panic {
      ^bb0(%arg2: ui256):
        sol.call @use(%arg2) : (ui256) -> ()
        sol.yield
      } error {
      ^bb0(%arg2: !sol.string<Memory>):
        sol.call @useStr(%arg2) : (!sol.string<Memory>) -> ()
        sol.yield
      } fallback {
      ^bb0(%arg2: !sol.string<Memory>):
        sol.call @useStr(%arg2) : (!sol.string<Memory>) -> ()
        sol.yield
      }
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // A failed create returns address 0, which selects the catch block.
    // CHECK-LABEL: yul.func @g : () -> i256
    // CHECK:         %[[ADDR:.*]] = yul.create
    // CHECK:         %[[MASK:.*]] = yul.constant 1461501637330902918203684832716283019655932542975
    // CHECK:         %[[A:.*]] = yul.and %[[ADDR]], %[[MASK]]
    // CHECK:         %[[OK:.*]] = yul.cmp ne, %[[A]], %{{.*}}
    // CHECK:         yul.if %[[OK]] {
    // CHECK:           yul.func_return
    // CHECK:         } else {
    // CHECK:           yul.constant 2
    // CHECK:           yul.func_return
    sol.func @g() -> ui256 {
      %c0_ui256 = sol.constant 0 : ui256
      %0 = sol.new "Other" value = %c0_ui256 ctor() try : !sol.contract<"Other">
      %1 = sol.address_cast %0 : !sol.contract<"Other"> to !sol.address
      %2 = sol.address_cast %1 : !sol.address to ui160
      %c0_ui160 = sol.constant 0 : ui160
      %3 = sol.cmp ne, %2, %c0_ui160 : ui160
      sol.try %3 {
        %c1_ui256 = sol.constant 1 : ui256
        sol.return %c1_ui256 : ui256
      ^bb1:  // no predecessors
        sol.yield
      } panic {
      } error {
      } fallback {
        %c2_ui256 = sol.constant 2 : ui256
        sol.return %c2_ui256 : ui256
      ^bb1:  // no predecessors
        sol.yield
      }
      sol.return %c0_ui256 : ui256
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
