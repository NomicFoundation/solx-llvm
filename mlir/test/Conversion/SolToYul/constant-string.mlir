// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// A constant string lowers to no value, and each consumer writes its bytes:
// immediate words up to 64 bytes and a codecopy from a code global above.
// The standard encoding zeroes the padding of the last word, and the helpers
// are keyed by the keccak of the bytes.

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45 : (i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[START:.*]]: i256):
    // CHECK:         %[[TAIL:.*]] = yul.add %[[START]], %{{.*}}
    // CHECK:         %[[DATA:.*]] = yul.add %[[TAIL]], %{{.*}}
    // CHECK:         %[[ABC:.*]] = yul.constant 44048180597813453602326562734351324025098966208897425494240603688123167145984
    // CHECK:         yul.mstore %[[DATA]], %[[ABC]]
    // CHECK:         %[[LEN:.*]] = yul.constant 3{{$}}
    // CHECK:         yul.mstore %[[TAIL]], %[[LEN]]
    // CHECK:         %[[WORD:.*]] = yul.constant 32{{$}}
    // CHECK:         %[[END:.*]] = yul.add %[[DATA]], %[[WORD]]
    // CHECK:         yul.func_return %[[END]]
    // CHECK-LABEL: yul.func @encode : () -> i256
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45(%{{.*}}) : (i256) -> i256
    sol.func @encode() -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.constant_string "abc"
      %1 = sol.encode %0 : (!sol.constant_string) -> !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.constant_string_8c0a2ac24a4f2dec7e1e644ab2d04079b47b53fe160f18e0075acf7628d96b6c : (i256) -> i256
    // CHECK:         %[[COPY:.*]] = yul.constant 160
    // CHECK-NEXT:    yul.codecopy %{{.*}}, %{{.*}}, %[[COPY]]
    // CHECK-NEXT:    %[[LEN:.*]] = yul.constant 160
    // CHECK-NEXT:    yul.mstore %{{.*}}, %[[LEN]]
    // CHECK-LABEL: yul.func @aligned : () -> i256
    sol.func @aligned() -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.constant_string "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
      %1 = sol.encode %0 : (!sol.constant_string) -> !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45.ui256 : (i256, i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[X:.*]]: i256, %[[START:.*]]: i256):
    // CHECK:         %[[TAIL:.*]] = yul.add %[[START]], %{{.*}}
    // CHECK:         %[[DATA:.*]] = yul.add %[[TAIL]], %{{.*}}
    // CHECK:         yul.mstore %[[DATA]], %{{.*}}
    // CHECK:         yul.mstore %[[TAIL]], %{{.*}}
    // CHECK:         %[[SECOND:.*]] = yul.add %[[START]], %{{.*}}
    // CHECK:         yul.mstore %[[SECOND]], %[[X]]
    // CHECK-LABEL: yul.func @extCall : (i256, i256) -> ()
    // CHECK-NEXT:  ^bb0(%{{.*}}: i256, %[[ARG1:.*]]: i256):
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45.ui256(%[[ARG1]], %{{.*}}) : (i256, i256) -> i256
    // CHECK:         yul.call
    sol.func @extCall(%arg0: !sol.address, %arg1: ui256) attributes {state_mutability = #NonPayable} {
      %c0 = sol.constant 0 : ui256
      %sel = sol.constant 1 : ui256
      %0 = sol.constant_string "abc"
      %status = sol.ext_call "g"(%0, %arg1) at %arg0 value %c0 selector %sel {callee_type = (!sol.string<Memory>, ui256) -> ()} : !sol.address, (!sol.constant_string, ui256) -> i1
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @extICall
    // CHECK:         yul.func_call @__sol.abi_encode_tuple.padded.tail.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45(%{{.*}}) : (i256) -> i256
    // CHECK:         yul.call
    sol.func @extICall(%arg0: !sol.ext_func_ref<(!sol.string<Memory>) -> ()>) attributes {state_mutability = #NonPayable} {
      %c0 = sol.constant 0 : ui256
      %0 = sol.constant_string "abc"
      %1 = sol.ext_icall %arg0(%0) value %c0 : <(!sol.string<Memory>) -> ()>, (!sol.constant_string) -> i1
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.constant_string_f1918e8562236eb17adc8502332f4c9c82bc14e19bfc0aa10ab674ff75b3d2f3 : (i256) -> i256
    // CHECK:         yul.constant 45231284858326638837332416019018714005183587760015845327913118753091066265600
    // CHECK-LABEL: yul.func @new : () -> i256
    // CHECK:         %[[MEM:.*]] = yul.mload
    // CHECK:         %[[END:.*]] = yul.func_call @__sol.abi_encode_tuple.padded.tail.constant_string_f1918e8562236eb17adc8502332f4c9c82bc14e19bfc0aa10ab674ff75b3d2f3(%{{.*}}) : (i256) -> i256
    // CHECK:         %[[SIZE:.*]] = yul.sub %[[END]], %[[MEM]]
    // CHECK:         yul.create %{{.*}}, %[[MEM]], %[[SIZE]]
    sol.func @new() -> !sol.contract<"D"> attributes {state_mutability = #NonPayable} {
      %c0 = sol.constant 0 : ui256
      %0 = sol.constant_string "d"
      %1 = sol.new "D" value = %c0 ctor(%0 : !sol.constant_string) : !sol.contract<"D">
      sol.return %1 : !sol.contract<"D">
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @emit : () -> ()
    // CHECK:         %[[TOPIC:.*]] = yul.constant 28314737293810674527488474353404243661761185637991170190359344066147653824637
    // CHECK:         %[[MEM:.*]] = yul.mload
    // CHECK:         %[[END:.*]] = yul.func_call @__sol.abi_encode_tuple.padded.tail.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45(%[[MEM]]) : (i256) -> i256
    // CHECK:         %[[SIZE:.*]] = yul.sub %[[END]], %[[MEM]]
    // CHECK:         yul.log %[[MEM]], %[[SIZE]] topics(%[[TOPIC]])
    sol.func @emit() attributes {state_mutability = #NonPayable} {
      %0 = sol.constant_string "abc"
      sol.emit "E(string)" non_indexed = [%0] : !sol.constant_string
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @emitIndexed : () -> ()
    // CHECK:         %[[SIGNATURE:.*]] = yul.constant 28314737293810674527488474353404243661761185637991170190359344066147653824637
    // CHECK-NEXT:    %[[TOPIC:.*]] = yul.constant 35286403120855365962805127237049809881669876751651884979611909062921250761797
    // CHECK:         %[[MEM:.*]] = yul.mload
    // CHECK:         yul.log %[[MEM]], %{{.*}} topics(%[[SIGNATURE]], %[[TOPIC]])
    sol.func @emitIndexed() attributes {state_mutability = #NonPayable} {
      %0 = sol.constant_string "abc"
      sol.emit "E(string)" indexed = [%0] : !sol.constant_string
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @concat : (i256) -> i256
    // CHECK:         %[[MEM:.*]] = yul.mload
    // CHECK:         %[[DST:.*]] = yul.add %[[MEM]], %{{.*}}
    // CHECK-NEXT:    %[[ABC:.*]] = yul.constant 44048180597813453602326562734351324025098966208897425494240603688123167145984
    // CHECK-NEXT:    yul.mstore %[[DST]], %[[ABC]]
    // CHECK-NEXT:    %[[LEN:.*]] = yul.constant 3{{$}}
    // CHECK-NEXT:    %[[NEXT:.*]] = yul.add %[[DST]], %[[LEN]]
    // CHECK:         yul.mcopy %[[NEXT]]
    sol.func @concat(%arg0: !sol.string<Memory>) -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.constant_string "abc"
      %1 = sol.concat %0, %arg0 : !sol.constant_string, !sol.string<Memory> -> !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @hashes : () -> (i256, i256)
    // CHECK:         %[[P:.*]] = yul.mload
    // CHECK-NEXT:    %[[ABC:.*]] = yul.constant 44048180597813453602326562734351324025098966208897425494240603688123167145984
    // CHECK-NEXT:    yul.mstore %[[P]], %[[ABC]]
    // CHECK-NEXT:    %[[LEN:.*]] = yul.constant 3{{$}}
    // CHECK-NOT:     yul.mstore
    // CHECK:         %[[SHA:.*]] = yul.constant 2{{$}}
    // CHECK-NEXT:    yul.static_call %{{.*}}, %[[SHA]], %[[P]], %[[LEN]],
    // CHECK:         %[[ABC2:.*]] = yul.constant 44048180597813453602326562734351324025098966208897425494240603688123167145984
    // CHECK-NEXT:    yul.mstore %[[Q:.*]], %[[ABC2]]
    // CHECK-NEXT:    %[[LEN2:.*]] = yul.constant 3{{$}}
    // CHECK-NOT:     yul.mstore
    // CHECK:         %[[RIPEMD:.*]] = yul.constant 3{{$}}
    // CHECK-NEXT:    yul.static_call %{{.*}}, %[[RIPEMD]], %[[Q]], %[[LEN2]],
    sol.func @hashes() -> (!sol.fixedbytes<32>, !sol.fixedbytes<20>) attributes {state_mutability = #Pure} {
      %0 = sol.constant_string "abc"
      %1 = "sol.sha256"(%0) : (!sol.constant_string) -> !sol.fixedbytes<32>
      %2 = sol.constant_string "abc"
      %3 = "sol.ripemd160"(%2) : (!sol.constant_string) -> !sol.fixedbytes<20>
      sol.return %1, %3 : !sol.fixedbytes<32>, !sol.fixedbytes<20>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @bareCalls : (i256) -> ()
    // CHECK:         %[[P:.*]] = yul.mload
    // CHECK-NEXT:    %[[XYZ:.*]] = yul.constant 54492172337884459557460545260627547743740629898835569074588186682020990025728
    // CHECK-NEXT:    yul.mstore %[[P]], %[[XYZ]]
    // CHECK-NEXT:    %[[LEN:.*]] = yul.constant 3{{$}}
    // CHECK-NOT:     yul.mstore
    // CHECK:         yul.call %{{.*}}, %{{.*}}, %{{.*}}, %[[P]], %[[LEN]],
    // CHECK:         %[[Q:.*]] = yul.mload
    // CHECK-NEXT:    %[[EMPTY:.*]] = yul.constant 0{{$}}
    // CHECK-NOT:     yul.mstore
    // CHECK:         yul.static_call %{{.*}}, %{{.*}}, %[[Q]], %[[EMPTY]],
    // CHECK:         %[[R:.*]] = yul.mload
    // CHECK-NEXT:    %[[Y:.*]] = yul.constant 54729854678575232993172223383012643946272141189619172846774873691240190181376
    // CHECK-NEXT:    yul.mstore %[[R]], %[[Y]]
    // CHECK-NEXT:    %[[ONE:.*]] = yul.constant 1{{$}}
    // CHECK-NOT:     yul.mstore
    // CHECK:         yul.delegate_call %{{.*}}, %{{.*}}, %[[R]], %[[ONE]],
    sol.func @bareCalls(%arg0: !sol.address) attributes {state_mutability = #NonPayable} {
      %c0 = sol.constant 0 : ui256
      %0 = sol.constant_string "xyz"
      %status, %ret_data = sol.bare_call %arg0 value %c0 input %0 : !sol.address, ui256, !sol.constant_string -> i1, !sol.string<Memory>
      %1 = sol.constant_string ""
      %status_0, %ret_data_1 = sol.bare_static_call %arg0 input %1 : !sol.address, !sol.constant_string -> i1, !sol.string<Memory>
      %2 = sol.constant_string "y"
      %status_2, %ret_data_3 = sol.bare_delegate_call %arg0 input %2 : !sol.address, !sol.constant_string -> i1, !sol.string<Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    sol.state_var @s slot 0 offset 0 : !sol.string<Storage>
    // CHECK-LABEL: yul.func @__sol.copy_string.constant_string_7a6f737e43d8df6b957106ab38e3ee7356f9640efbd029c659cfb25aa1f033a1.storage : (i256) -> ()
    // CHECK:         %[[OLD:.*]] = yul.func_call @__sol.storage_string_length(
    // CHECK-NEXT:    %[[LEN:.*]] = yul.constant 32{{$}}
    // CHECK-NEXT:    yul.func_call @__sol.clear_storage_string_tail(%arg0, %[[OLD]], %[[LEN]])
    // CHECK:         %[[DATA:.*]] = yul.keccak256
    // CHECK-NEXT:    %[[WORD:.*]] = yul.constant 44048183304486788312148433451363384677562265908331949128489393197024686584885
    // CHECK-NEXT:    yul.sstore %[[DATA]], %[[WORD]]
    // CHECK-NEXT:    %[[LONG:.*]] = yul.constant 65{{$}}
    // CHECK-NEXT:    yul.sstore %arg0, %[[LONG]]
    // CHECK-LABEL: yul.func @__sol.copy_string.constant_string_3543932457eeb70fdd26eee26b08ef8d5b039e5d2936242e767026359c7bf7ea.storage : (i256) -> ()
    // CHECK:         %[[OLD:.*]] = yul.func_call @__sol.storage_string_length(
    // CHECK-NEXT:    %[[LEN:.*]] = yul.constant 31{{$}}
    // CHECK-NEXT:    yul.func_call @__sol.clear_storage_string_tail(%arg0, %[[OLD]], %[[LEN]])
    // CHECK-NEXT:    %[[SHORT:.*]] = yul.constant 44048183304486788312148433451363384677562265908331949128489393197024686584894
    // CHECK-NEXT:    yul.sstore %arg0, %[[SHORT]]
    // CHECK-LABEL: yul.func @storage : () -> ()
    // CHECK:         yul.func_call @__sol.copy_string.constant_string_3543932457eeb70fdd26eee26b08ef8d5b039e5d2936242e767026359c7bf7ea.storage(
    // CHECK:         yul.func_call @__sol.copy_string.constant_string_7a6f737e43d8df6b957106ab38e3ee7356f9640efbd029c659cfb25aa1f033a1.storage(
    sol.func @storage() attributes {state_mutability = #NonPayable} {
      %0 = sol.constant_string "abcdefghijklmnopqrstuvwxyz01234"
      %1 = sol.addr_of @s : !sol.string<Storage>
      sol.copy %0, %1 : !sol.constant_string, !sol.string<Storage>
      %2 = sol.constant_string "abcdefghijklmnopqrstuvwxyz012345"
      %3 = sol.addr_of @s : !sol.string<Storage>
      sol.copy %2, %3 : !sol.constant_string, !sol.string<Storage>
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    sol.state_var @s slot 0 offset 0 : !sol.string<Storage>
    sol.state_var @t slot 1 offset 0 : !sol.string<Storage>
    // CHECK-LABEL: yul.func @__sol.copy_string.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45.storage : (i256) -> ()
    // CHECK-LABEL: yul.func @storageTwice : () -> ()
    // CHECK-NEXT:    %[[S:.*]] = yul.constant 0{{$}}
    // CHECK-NEXT:    yul.func_call @__sol.copy_string.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45.storage(%[[S]])
    // CHECK-NEXT:    %[[T:.*]] = yul.constant 1{{$}}
    // CHECK-NEXT:    yul.func_call @__sol.copy_string.constant_string_4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45.storage(%[[T]])
    sol.func @storageTwice() attributes {state_mutability = #NonPayable} {
      %0 = sol.constant_string "abc"
      %1 = sol.addr_of @s : !sol.string<Storage>
      sol.copy %0, %1 : !sol.constant_string, !sol.string<Storage>
      %2 = sol.addr_of @t : !sol.string<Storage>
      sol.copy %0, %2 : !sol.constant_string, !sol.string<Storage>
      sol.return
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.constant_string_73a59aa6baf021b62afa97ae033a9cbbcb3b7fdc6c5d42a33073d5cbf64dc0f4 : (i256) -> i256
    // CHECK:         %[[W0:.*]] = yul.constant 44048183304486788312148433451363384677562265908331949128489393197024686584885
    // CHECK-NEXT:    yul.mstore %[[DATA:.*]], %[[W0]]
    // CHECK:         %[[A1:.*]] = yul.add %[[DATA]], %{{.*}}
    // CHECK-NEXT:    %[[W1:.*]] = yul.constant 24522458453444134286487657463869616316458454434186520725591777181879917764962
    // CHECK-NEXT:    yul.mstore %[[A1]], %[[W1]]
    // CHECK-NOT:     yul.codecopy
    // CHECK:         yul.func_return
    sol.func @cutoff() -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.constant_string "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZab"
      %1 = sol.encode %0 : (!sol.constant_string) -> !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.padded.tail.constant_string_64238fc638406b78c4dd65f3ef26e183bd25bbd176b66a38fc87005b38fa840e : (i256) -> i256
    // CHECK:         %[[TAIL:.*]] = yul.add
    // CHECK:         %[[DATA:.*]] = yul.add %[[TAIL]], %{{.*}}
    // CHECK:         %[[G:.*]] = llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
    // CHECK:         %[[GI:.*]] = llvm.ptrtoint %[[G]] : !llvm.ptr<4> to i256
    // CHECK:         %[[COPY:.*]] = yul.constant 65
    // CHECK:         yul.codecopy %[[DATA]], %[[GI]], %[[COPY]]
    // CHECK:         %[[OFFSET:.*]] = yul.constant 65
    // CHECK:         %[[CLEANUP:.*]] = yul.add %[[DATA]], %[[OFFSET]]
    // CHECK:         %[[ZERO:.*]] = yul.constant 0{{$}}
    // CHECK:         yul.mstore %[[CLEANUP]], %[[ZERO]]
    // CHECK:         %[[LEN:.*]] = yul.constant 65
    // CHECK:         yul.mstore %[[TAIL]], %[[LEN]]
    // CHECK:         %[[ADVANCE:.*]] = yul.constant 96
    // CHECK:         %[[END:.*]] = yul.add %[[DATA]], %[[ADVANCE]]
    // CHECK:         yul.func_return %[[END]]
    sol.func @aboveCutoff() -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.constant_string "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabc"
      %1 = sol.encode %0 : (!sol.constant_string) -> !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @__sol.abi_encode_tuple.packed.inplace.constant_string_d7849930a0d7769a11103d8427005589757be5a87195ad088dba335b1e8fa147 : (i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[DST:.*]]: i256):
    // CHECK-NEXT:    %[[G:.*]] = llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
    // CHECK-NEXT:    %[[GI:.*]] = llvm.ptrtoint %[[G]] : !llvm.ptr<4> to i256
    // CHECK-NEXT:    %[[LEN:.*]] = yul.constant 129
    // CHECK-NEXT:    yul.codecopy %[[DST]], %[[GI]], %[[LEN]]
    // CHECK-NEXT:    %[[ADVANCE:.*]] = yul.constant 129
    // CHECK-NEXT:    %[[END:.*]] = yul.add %[[DST]], %[[ADVANCE]]
    // CHECK-NEXT:    yul.func_return %[[END]]
    // CHECK-LABEL: yul.func @longPacked : () -> i256
    // CHECK:       llvm.mlir.global private unnamed_addr constant @__data_in_code.0("{{(abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ){2}abcde}}") {addr_space = 4 : i32}
    sol.func @longPacked() -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.constant_string "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcde"
      %1 = sol.encode %0 : (!sol.constant_string) -> !sol.string<Memory> {packed}
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @longConcat : (i256) -> i256
    // CHECK:         %[[MEM:.*]] = yul.mload
    // CHECK:         %[[DST:.*]] = yul.add %[[MEM]], %{{.*}}
    // CHECK-NEXT:    %[[G:.*]] = llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
    // CHECK-NEXT:    %[[GI:.*]] = llvm.ptrtoint %[[G]] : !llvm.ptr<4> to i256
    // CHECK-NEXT:    %[[LEN:.*]] = yul.constant 129
    // CHECK-NEXT:    yul.codecopy %[[DST]], %[[GI]], %[[LEN]]
    // CHECK-NEXT:    %[[ADVANCE:.*]] = yul.constant 129
    // CHECK-NEXT:    %[[NEXT:.*]] = yul.add %[[DST]], %[[ADVANCE]]
    // CHECK:         yul.mcopy %[[NEXT]]
    sol.func @longConcat(%arg0: !sol.string<Memory>) -> !sol.string<Memory> attributes {state_mutability = #Pure} {
      %0 = sol.constant_string "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcde"
      %1 = sol.concat %0, %arg0 : !sol.constant_string, !sol.string<Memory> -> !sol.string<Memory>
      sol.return %1 : !sol.string<Memory>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#Pure = #sol<StateMutability Pure>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @longHash : () -> i256
    // CHECK:         %[[P:.*]] = yul.mload
    // CHECK-NEXT:    %[[G:.*]] = llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
    // CHECK-NEXT:    %[[GI:.*]] = llvm.ptrtoint %[[G]] : !llvm.ptr<4> to i256
    // CHECK-NEXT:    %[[COPY:.*]] = yul.constant 129
    // CHECK-NEXT:    yul.codecopy %[[P]], %[[GI]], %[[COPY]]
    // CHECK-NEXT:    %[[LEN:.*]] = yul.constant 129
    // CHECK-NOT:     yul.mstore
    // CHECK:         yul.static_call %{{.*}}, %{{.*}}, %[[P]], %[[LEN]],
    sol.func @longHash() -> !sol.fixedbytes<32> attributes {state_mutability = #Pure} {
      %0 = sol.constant_string "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcde"
      %1 = "sol.sha256"(%0) : (!sol.constant_string) -> !sol.fixedbytes<32>
      sol.return %1 : !sol.fixedbytes<32>
    }
  } {kind = #Contract, runtime}
}

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>
module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @longBareCall : (i256) -> ()
    // CHECK:         %[[P:.*]] = yul.mload
    // CHECK-NEXT:    %[[G:.*]] = llvm.mlir.addressof @__data_in_code.0 : !llvm.ptr<4>
    // CHECK-NEXT:    %[[GI:.*]] = llvm.ptrtoint %[[G]] : !llvm.ptr<4> to i256
    // CHECK-NEXT:    %[[COPY:.*]] = yul.constant 129
    // CHECK-NEXT:    yul.codecopy %[[P]], %[[GI]], %[[COPY]]
    // CHECK-NEXT:    %[[LEN:.*]] = yul.constant 129
    // CHECK-NOT:     yul.mstore
    // CHECK:         yul.call %{{.*}}, %{{.*}}, %{{.*}}, %[[P]], %[[LEN]],
    sol.func @longBareCall(%arg0: !sol.address) attributes {state_mutability = #NonPayable} {
      %c0 = sol.constant 0 : ui256
      %0 = sol.constant_string "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcde"
      %status, %ret_data = sol.bare_call %arg0 value %c0 input %0 : !sol.address, ui256, !sol.constant_string -> i1, !sol.string<Memory>
      sol.return
    }
  } {kind = #Contract, runtime}
}
