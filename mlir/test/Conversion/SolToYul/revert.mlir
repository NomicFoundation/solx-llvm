// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL:     yul.func @revert : (i256) -> () {
    // CHECK:           ^bb0(%[[A:.*]]: i256):

    // revert E(a)
    // CHECK:             %[[P:.*]] = yul.mload %c64_i256
    // CHECK:             yul.mstore %[[P]], %c84701008042320515315298174644417619374439393932350505483920050946320629760_i256
    // CHECK:             %[[OFF:.*]] = yul.add %[[P]], %c4_i256
    // CHECK:             yul.mstore %[[OFF]], %[[A]]
    // CHECK:             yul.revert %[[P]], %{{.*}}

    // revert("error message"): Error(string), length 13.
    // CHECK:             %[[P:.*]] = yul.mload %c64_i256
    // CHECK:             yul.mstore %[[P]], %c3963877391197344453575983046348115674221700746820753546331534351508065746944_i256
    // CHECK:             %[[OFF:.*]] = yul.add %[[P]], %c4_i256
    // CHECK:             yul.mstore %[[OFF]], %c32_i256
    // CHECK:             yul.mstore %{{.*}}, %c13_i256
    // CHECK:             yul.mstore %{{.*}}, %c45885808075951196297010052350408398216268308371140631434831267343051471716352_i256
    // CHECK:             yul.revert %[[P]], %{{.*}}

    // revert()
    // CHECK:             yul.revert %[[Z:.*]], %[[Z]]
    // CHECK-NEXT:        yul.func_return
    sol.func @revert(%a: ui256) attributes {state_mutability = #NonPayable} {
      sol.revert "E(uint256)"(%a : ui256) {call}
      sol.revert "error message"
      sol.revert
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // require guards the same payloads with `cond == 0`.
    // CHECK-LABEL: yul.func @require : (i256, i256, i256) -> () {
    // CHECK-NEXT:  ^bb0(%[[COND:.*]]: i256, %[[A:.*]]: i256, %[[MSG:.*]]: i256):

    // require(c)
    // CHECK:         %[[F:.*]] = yul.cmp eq, %[[COND]], %c0_i256
    // CHECK:         yul.if %[[F]] {
    // CHECK:           yul.revert %[[Z:.*]], %[[Z]]
    // CHECK:         }

    // require(c, "Foobar"): Error(string).
    // CHECK:         %[[F:.*]] = yul.cmp eq, %[[COND]], %c0_i256
    // CHECK:         yul.if %[[F]] {
    // CHECK:           %[[P:.*]] = yul.mload %c64_i256
    // CHECK:           yul.mstore %[[P]], %c3963877391197344453575983046348115674221700746820753546331534351508065746944_i256
    // CHECK:           yul.revert %[[P]], %{{.*}}
    // CHECK:         }

    // require(c, E(a))
    // CHECK:         %[[F:.*]] = yul.cmp eq, %[[COND]], %c0_i256
    // CHECK:         yul.if %[[F]] {
    // CHECK:           %[[P:.*]] = yul.mload %c64_i256
    // CHECK:           yul.mstore %[[P]], %c84701008042320515315298174644417619374439393932350505483920050946320629760_i256
    // CHECK:           yul.revert %[[P]], %{{.*}}
    // CHECK:         }

    // require(c, msg): a runtime message is ABI-encoded as Error(string): offset
    // 32, then the length, then the bytes copied from memory.
    // CHECK:         %[[F:.*]] = yul.cmp eq, %[[COND]], %c0_i256
    // CHECK:         yul.if %[[F]] {
    // CHECK:           %[[P:.*]] = yul.mload %c64_i256
    // CHECK:           yul.mstore %[[P]], %c3963877391197344453575983046348115674221700746820753546331534351508065746944_i256
    // CHECK:           %[[LEN:.*]] = yul.mload %[[MSG]]
    // CHECK:           %[[SRC:.*]] = yul.add %[[MSG]], %c32_i256
    // CHECK:           yul.mcopy %{{.*}}, %[[SRC]], %[[LEN]]
    // CHECK:           yul.revert %[[P]], %{{.*}}
    // CHECK:         }
    sol.func @require(%c: i1, %a: ui256, %msg: !sol.string<Memory>) {
      sol.require %c
      sol.require %c, "Foobar"
      sol.require %c, "E(uint256)"(%a : ui256) {call}
      sol.require %c, "Error(string)"(%msg : !sol.string<Memory>) {call}
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // A failed assert reverts with Panic(0x01).
    // CHECK-LABEL: yul.func @assert : (i256) -> ()
    // CHECK:       ^bb0(%[[C:.*]]: i256):
    // CHECK:         %[[FAIL:.*]] = yul.cmp eq, %[[C]], %{{.*}}
    // CHECK:         yul.if %[[FAIL]] {
    // CHECK:           %[[SEL:.*]] = yul.constant 35408467139433450592217433187231851964531694900788300625387963629091585785856
    // CHECK:           yul.mstore %{{.*}}, %[[SEL]]
    // CHECK:           %[[C4:.*]] = yul.constant 4
    // CHECK:           %[[CODE:.*]] = yul.constant 1{{$}}
    // CHECK:           yul.mstore %[[C4]], %[[CODE]]
    // CHECK:           %[[C36:.*]] = yul.constant 36
    // CHECK:           yul.revert %{{.*}}, %[[C36]]
    // CHECK:         yul.func_return
    sol.func @assert(%c: i1) attributes {state_mutability = #NonPayable} {
      sol.assert %c
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
