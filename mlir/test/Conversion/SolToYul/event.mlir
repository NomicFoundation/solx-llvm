// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @emitV : (i256) -> ()
    // CHECK:         %[[SIG:.*]] = yul.constant -5439156989899726624871022547575570226779898903108835760635768268537395055798{{$}}
    // CHECK:         %[[B:.*]] = yul.cmp ne, %{{.*}}, %{{.*}}
    // CHECK:         yul.log %{{.*}}, %{{.*}} topics(%[[SIG]], %[[B]])
    sol.func @emitV(%arg0: i1) attributes {state_mutability = #NonPayable} {
      sol.emit "V(bool)" indexed = [%arg0] : i1
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // An indexed string is logged as the keccak of its contents.
    // CHECK-LABEL: yul.func @emitR : (i256) -> ()
    // CHECK:         %[[SIG:.*]] = yul.constant 34354843262229843807123348806149206935067866475963268020757943107646077459833{{$}}
    // CHECK:         yul.mcopy
    // CHECK:         %[[HASH:.*]] = yul.keccak256
    // CHECK:         yul.log %{{.*}}, %{{.*}} topics(%[[SIG]], %[[HASH]])
    sol.func @emitR(%arg0: !sol.string<Memory>) attributes {state_mutability = #NonPayable} {
      sol.emit "R(string)" indexed = [%arg0] : !sol.string<Memory>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // An indexed struct is logged as the keccak of its in-place encoding, string
    // members padded to a word.
    // CHECK-LABEL: yul.func @emitStatic : (i256) -> ()
    // CHECK:       ^bb0(%[[S:.*]]: i256):
    // CHECK:         %[[SIG:.*]] = yul.constant 22992739540827417338739692891253355298809991475767957404135938865693038621146{{$}}
    // CHECK:         %[[BUF:.*]] = yul.mload
    // CHECK-NOT:     yul.mcopy
    // CHECK:         %[[X:.*]] = yul.mload %[[S]]
    // CHECK:         %[[M:.*]] = yul.constant 65535
    // CHECK:         %[[B:.*]] = yul.and %[[X]], %[[M]]
    // CHECK:         yul.mstore %[[BUF]], %[[B]]
    // CHECK-NOT:     yul.mcopy
    // CHECK:         %[[H:.*]] = yul.keccak256 %[[BUF]],
    // CHECK:         yul.log %{{.*}}, %{{.*}} topics(%[[SIG]], %[[H]])
    sol.func @emitStatic(%arg0: !sol.struct<(ui16), Memory>) attributes {state_mutability = #NonPayable} {
      sol.emit "EStatic((uint16))" indexed = [%arg0] : !sol.struct<(ui16), Memory>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @emitDynamic : (i256) -> ()
    // CHECK:       ^bb0(%[[S:.*]]: i256):
    // CHECK:         %[[SIG:.*]] = yul.constant 20419421517794169989111501949961529592723745139203314723394321486472158066767{{$}}
    // CHECK:         %[[BUF:.*]] = yul.mload
    // CHECK:         %[[STR:.*]] = yul.mload %[[S]]
    // CHECK:         %[[LEN:.*]] = yul.mload %[[STR]]
    // CHECK:         %[[DATA:.*]] = yul.add %[[STR]],
    // CHECK:         yul.mcopy %[[BUF]], %[[DATA]], %[[LEN]]
    // CHECK:         %[[MASK:.*]] = yul.constant -32
    // CHECK:         %[[PAD:.*]] = yul.and %{{.*}}, %[[MASK]]
    // CHECK:         %[[END:.*]] = yul.add %[[BUF]], %[[PAD]]
    // CHECK:         %[[SIZE:.*]] = yul.sub %[[END]], %[[BUF]]
    // CHECK:         %[[H:.*]] = yul.keccak256 %[[BUF]], %[[SIZE]]
    // CHECK:         yul.log %{{.*}}, %{{.*}} topics(%[[SIG]], %[[H]])
    sol.func @emitDynamic(%arg0: !sol.struct<(!sol.string<Memory>), Memory>) attributes {state_mutability = #NonPayable} {
      sol.emit "EDynamic((string))" indexed = [%arg0] : !sol.struct<(!sol.string<Memory>), Memory>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @emitAnon : (i256) -> ()
    // CHECK:       ^bb0(%[[A:.*]]: i256):
    // CHECK:         yul.log %{{.*}}, %{{.*}} topics(%[[A]])
    sol.func @emitAnon(%arg0: ui256) attributes {state_mutability = #NonPayable} {
      sol.emit indexed = [%arg0] : ui256
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @emitMixed : (i256, i256) -> ()
    // CHECK:       ^bb0(%[[I:.*]]: i256, %{{.*}}: i256):
    // CHECK:         %[[SIG:.*]] = yul.constant 56223025768741404677931981242731356084606262024008358662602253767454331384788{{$}}
    // CHECK:         %[[HEAD:.*]] = yul.mload
    // CHECK:         yul.mcopy
    // CHECK:         %[[SIZE:.*]] = yul.sub %{{.*}}, %[[HEAD]]
    // CHECK:         yul.log %[[HEAD]], %[[SIZE]] topics(%[[SIG]], %[[I]])
    sol.func @emitMixed(%arg0: ui256, %arg1: !sol.string<Memory>) attributes {state_mutability = #NonPayable} {
      sol.emit "Mixed(uint256,string)" indexed = [%arg0] non_indexed = [%arg1] : ui256, !sol.string<Memory>
      sol.return
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
