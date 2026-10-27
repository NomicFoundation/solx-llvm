// RUN: mlir-opt %s -canonicalize | FileCheck %s

sol.contract @C {
  // The hash of a literal is a constant, and the literal no longer used is
  // erased.
  // CHECK-LABEL: sol.func @literal(
  // CHECK-NEXT:    %[[HASH:.*]] = sol.constant 61678357398080765210293718086378416697372618187842506566286863523773954249005 : ui256
  // CHECK-NEXT:    %[[BYTES:.*]] = sol.bytes_cast %[[HASH]] : ui256 to !sol.fixedbytes<32>
  // CHECK-NEXT:    sol.return %[[BYTES]] : !sol.fixedbytes<32>
  sol.func @literal() -> !sol.fixedbytes<32> {
    %0 = sol.string_lit "hevm cheat code" -> !sol.string<Memory>
    %1 = "sol.keccak256"(%0) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
    sol.return %1 : !sol.fixedbytes<32>
  }

  // CHECK-LABEL: sol.func @emptyLiteral(
  // CHECK-NEXT:    %[[HASH:.*]] = sol.constant 89477152217924674838424037953991966239322087453347756267410168184682657981552 : ui256
  // CHECK-NEXT:    %[[BYTES:.*]] = sol.bytes_cast %[[HASH]] : ui256 to !sol.fixedbytes<32>
  // CHECK-NEXT:    sol.return %[[BYTES]] : !sol.fixedbytes<32>
  sol.func @emptyLiteral() -> !sol.fixedbytes<32> {
    %0 = sol.string_lit "" -> !sol.string<Memory>
    %1 = "sol.keccak256"(%0) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
    sol.return %1 : !sol.fixedbytes<32>
  }

  // CHECK-LABEL: sol.func @longLiteral(
  // CHECK-NEXT:    %[[HASH:.*]] = sol.constant 19388751928902909765299343656493465694177465148741363623896312979730877008019 : ui256
  // CHECK-NEXT:    %[[BYTES:.*]] = sol.bytes_cast %[[HASH]] : ui256 to !sol.fixedbytes<32>
  // CHECK-NEXT:    sol.return %[[BYTES]] : !sol.fixedbytes<32>
  sol.func @longLiteral() -> !sol.fixedbytes<32> {
    %0 = sol.string_lit "The quick brown fox jumps over the lazy dog, again." -> !sol.string<Memory>
    %1 = "sol.keccak256"(%0) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
    sol.return %1 : !sol.fixedbytes<32>
  }

  // CHECK-LABEL: sol.func @binaryLiteral(
  // CHECK-NEXT:    %[[HASH:.*]] = sol.constant 142677944781355243449484197729476552576528029131510218358722598352270485208 : ui256
  // CHECK-NEXT:    %[[BYTES:.*]] = sol.bytes_cast %[[HASH]] : ui256 to !sol.fixedbytes<32>
  // CHECK-NEXT:    sol.return %[[BYTES]] : !sol.fixedbytes<32>
  sol.func @binaryLiteral() -> !sol.fixedbytes<32> {
    %0 = sol.string_lit "\00\FF" -> !sol.string<Memory>
    %1 = "sol.keccak256"(%0) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
    sol.return %1 : !sol.fixedbytes<32>
  }

  // A literal with another use stays for it.
  // CHECK-LABEL: sol.func @usedLiteral(
  // CHECK-NEXT:    %[[HASH:.*]] = sol.constant 61678357398080765210293718086378416697372618187842506566286863523773954249005 : ui256
  // CHECK-NEXT:    %[[LITERAL:.*]] = sol.string_lit "hevm cheat code" -> !sol.string<Memory>
  // CHECK-NEXT:    %[[BYTES:.*]] = sol.bytes_cast %[[HASH]] : ui256 to !sol.fixedbytes<32>
  // CHECK-NEXT:    sol.return %[[BYTES]], %[[LITERAL]] : !sol.fixedbytes<32>, !sol.string<Memory>
  sol.func @usedLiteral() -> (!sol.fixedbytes<32>, !sol.string<Memory>) {
    %0 = sol.string_lit "hevm cheat code" -> !sol.string<Memory>
    %1 = "sol.keccak256"(%0) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
    sol.return %1, %0 : !sol.fixedbytes<32>, !sol.string<Memory>
  }

  // CHECK-LABEL: sol.func @argument(
  // CHECK-SAME:    %[[STRING:.*]]: !sol.string<Memory>
  // CHECK-NEXT:    %[[HASH:.*]] = "sol.keccak256"(%[[STRING]]) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
  // CHECK-NEXT:    sol.return %[[HASH]] : !sol.fixedbytes<32>
  sol.func @argument(%arg0: !sol.string<Memory>) -> !sol.fixedbytes<32> {
    %0 = "sol.keccak256"(%arg0) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
    sol.return %0 : !sol.fixedbytes<32>
  }

  // CHECK-LABEL: sol.func @encodedAndHashed(
  // CHECK-NEXT:    %[[HASH:.*]] = sol.constant 35286403120855365962805127237049809881669876751651884979611909062921250761797 : ui256
  // CHECK-NEXT:    %[[LIT:.*]] = sol.constant_string "abc"
  // CHECK-NEXT:    %[[ENC:.*]] = sol.encode %[[LIT]], %[[LIT]] : (!sol.constant_string, !sol.constant_string) -> !sol.string<Memory>
  // CHECK-NEXT:    %[[BYTES:.*]] = sol.bytes_cast %[[HASH]] : ui256 to !sol.fixedbytes<32>
  // CHECK-NEXT:    sol.return %[[ENC]], %[[BYTES]] : !sol.string<Memory>, !sol.fixedbytes<32>
  sol.func @encodedAndHashed() -> (!sol.string<Memory>, !sol.fixedbytes<32>) {
    %0 = sol.string_lit "abc" -> !sol.string<Memory>
    %1 = sol.encode %0, %0 : (!sol.string<Memory>, !sol.string<Memory>) -> !sol.string<Memory>
    %2 = "sol.keccak256"(%0) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
    sol.return %1, %2 : !sol.string<Memory>, !sol.fixedbytes<32>
  }

  sol.state_var @s slot 0 offset 0 : !sol.string<Storage>

  // A copy takes a constant string into a storage string, and not into a
  // memory one.
  // CHECK-LABEL: sol.func @copied(
  // CHECK:         %[[STORED:.*]] = sol.constant_string "abc"
  // CHECK:         sol.copy %[[STORED]], %{{.*}} : !sol.constant_string, !sol.string<Storage>
  // CHECK:         %[[COPIED:.*]] = sol.string_lit "abc" -> !sol.string<Memory>
  // CHECK:         sol.copy %[[COPIED]], %arg0 : !sol.string<Memory>, !sol.string<Memory>
  sol.func @copied(%arg0: !sol.string<Memory>) {
    %0 = sol.string_lit "abc" -> !sol.string<Memory>
    %1 = sol.addr_of @s : !sol.string<Storage>
    sol.copy %0, %1 : !sol.string<Memory>, !sol.string<Storage>
    %2 = sol.string_lit "abc" -> !sol.string<Memory>
    sol.copy %2, %arg0 : !sol.string<Memory>, !sol.string<Memory>
    sol.return
  }

  // CHECK-LABEL: sol.func @otherBlocks(
  // CHECK-NEXT:    %[[LIT:.*]] = sol.constant_string "abc"
  // CHECK-NEXT:    cf.cond_br %arg0, ^[[THEN:.*]], ^[[ELSE:.*]]
  // CHECK-NEXT:  ^[[THEN]]:
  // CHECK-NEXT:    sol.encode %[[LIT]] : (!sol.constant_string) -> !sol.string<Memory>
  // CHECK:       ^[[ELSE]]:
  // CHECK-NEXT:    sol.encode %[[LIT]], %[[LIT]] : (!sol.constant_string, !sol.constant_string) -> !sol.string<Memory>
  sol.func @otherBlocks(%arg0: i1) -> !sol.string<Memory> {
    %0 = sol.string_lit "abc" -> !sol.string<Memory>
    cf.cond_br %arg0, ^bb1, ^bb2
  ^bb1:
    %1 = sol.encode %0 : (!sol.string<Memory>) -> !sol.string<Memory>
    sol.return %1 : !sol.string<Memory>
  ^bb2:
    %2 = sol.encode %0, %0 : (!sol.string<Memory>, !sol.string<Memory>) -> !sol.string<Memory>
    sol.return %2 : !sol.string<Memory>
  }

  // CHECK-LABEL: sol.func @nestedRegion(
  // CHECK-NEXT:    %[[LIT:.*]] = sol.constant_string "abc"
  // CHECK-NEXT:    sol.if %arg0 {
  // CHECK-NEXT:      sol.emit "E(string)" non_indexed = [%[[LIT]]] : !sol.constant_string
  sol.func @nestedRegion(%arg0: i1) {
    %0 = sol.string_lit "abc" -> !sol.string<Memory>
    sol.if %arg0 {
      sol.emit "E(string)" non_indexed = [%0] : !sol.string<Memory>
      sol.yield
    } else {
    }
    sol.return
  }

  // A use in a nested region that takes no constant string keeps the memory.
  // CHECK-LABEL: sol.func @nestedCopy(
  // CHECK-NEXT:    %[[LIT:.*]] = sol.string_lit "abc" -> !sol.string<Memory>
  // CHECK:         sol.copy %[[LIT]], %arg1
  // CHECK:         sol.encode %[[LIT]]
  sol.func @nestedCopy(%arg0: i1, %arg1: !sol.string<Memory>) -> !sol.string<Memory> {
    %0 = sol.string_lit "abc" -> !sol.string<Memory>
    sol.if %arg0 {
      sol.copy %0, %arg1 : !sol.string<Memory>, !sol.string<Memory>
      sol.yield
    } else {
    }
    %1 = sol.encode %0 : (!sol.string<Memory>) -> !sol.string<Memory>
    sol.return %1 : !sol.string<Memory>
  }

  // Two equal constant strings merge into one.
  // CHECK-LABEL: sol.func @indexedTopic(
  // CHECK-NEXT:    %[[LIT:.*]] = sol.constant_string "abc"
  // CHECK-NEXT:    sol.emit "E(string,string)" indexed = [%[[LIT]]] non_indexed = [%[[LIT]]] : !sol.constant_string, !sol.constant_string
  sol.func @indexedTopic() {
    %0 = sol.string_lit "abc" -> !sol.string<Memory>
    %1 = sol.string_lit "abc" -> !sol.string<Memory>
    sol.emit "E(string,string)" indexed = [%0] non_indexed = [%1] : !sol.string<Memory>, !sol.string<Memory>
    sol.return
  }

  // CHECK-LABEL: sol.func @concatenated(
  // CHECK-NEXT:    %[[HASH:.*]] = sol.constant 35286403120855365962805127237049809881669876751651884979611909062921250761797 : ui256
  // CHECK-NEXT:    %[[LIT:.*]] = sol.string_lit "abc" -> !sol.string<Memory>
  // CHECK-NEXT:    %[[BYTES:.*]] = sol.bytes_cast %[[HASH]] : ui256 to !sol.fixedbytes<32>
  // CHECK-NEXT:    sol.return %[[LIT]], %[[BYTES]] : !sol.string<Memory>, !sol.fixedbytes<32>
  sol.func @concatenated() -> (!sol.string<Memory>, !sol.fixedbytes<32>) {
    %0 = sol.string_lit "a" -> !sol.string<Memory>
    %1 = sol.string_lit "bc" -> !sol.string<Memory>
    %2 = sol.concat %0, %1 : !sol.string<Memory>, !sol.string<Memory> -> !sol.string<Memory>
    %3 = sol.string_lit "a" -> !sol.string<Memory>
    %4 = sol.string_lit "bc" -> !sol.string<Memory>
    %5 = sol.concat %3, %4 : !sol.string<Memory>, !sol.string<Memory> -> !sol.string<Memory>
    %6 = "sol.keccak256"(%5) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
    sol.return %2, %6 : !sol.string<Memory>, !sol.fixedbytes<32>
  }

  // CHECK-LABEL: sol.func @concatenatedWithValue(
  // CHECK-NEXT:    %[[LIT:.*]] = sol.constant_string "abc"
  // CHECK-NEXT:    sol.concat %[[LIT]], %arg0 : !sol.constant_string, !sol.string<Memory> -> <Memory>
  sol.func @concatenatedWithValue(%arg0: !sol.string<Memory>) -> !sol.string<Memory> {
    %0 = sol.string_lit "abc" -> !sol.string<Memory>
    %1 = sol.concat %0, %arg0 : !sol.string<Memory>, !sol.string<Memory> -> !sol.string<Memory>
    sol.return %1 : !sol.string<Memory>
  }

  // A packed encoding of constant strings is a literal of their bytes.
  // CHECK-LABEL: sol.func @encodedPacked(
  // CHECK-NEXT:    %[[LIT:.*]] = sol.string_lit "abc" -> !sol.string<Memory>
  // CHECK-NEXT:    sol.return %[[LIT]] : !sol.string<Memory>
  sol.func @encodedPacked() -> !sol.string<Memory> {
    %0 = sol.string_lit "a" -> !sol.string<Memory>
    %1 = sol.string_lit "bc" -> !sol.string<Memory>
    %2 = sol.encode %0, %1 : (!sol.string<Memory>, !sol.string<Memory>) -> !sol.string<Memory> {packed}
    sol.return %2 : !sol.string<Memory>
  }

  // CHECK-LABEL: sol.func @hashedPacked(
  // CHECK-NEXT:    %[[HASH:.*]] = sol.constant 35286403120855365962805127237049809881669876751651884979611909062921250761797 : ui256
  // CHECK-NEXT:    %[[BYTES:.*]] = sol.bytes_cast %[[HASH]] : ui256 to !sol.fixedbytes<32>
  // CHECK-NEXT:    sol.return %[[BYTES]] : !sol.fixedbytes<32>
  sol.func @hashedPacked() -> !sol.fixedbytes<32> {
    %0 = sol.string_lit "abc" -> !sol.string<Memory>
    %1 = sol.encode %0 : (!sol.string<Memory>) -> !sol.string<Memory> {packed}
    %2 = "sol.keccak256"(%1) : (!sol.string<Memory>) -> !sol.fixedbytes<32>
    sol.return %2 : !sol.fixedbytes<32>
  }

  // A packed encoding with a runtime value, and a standard encoding, stay.
  // CHECK-LABEL: sol.func @encodedWithValue(
  // CHECK:         sol.encode %{{.*}}, %arg0 : (!sol.constant_string, ui8) -> !sol.string<Memory> {packed}
  // CHECK:         sol.encode %{{.*}} : (!sol.constant_string) -> !sol.string<Memory>
  sol.func @encodedWithValue(%arg0: ui8) -> (!sol.string<Memory>, !sol.string<Memory>) {
    %0 = sol.string_lit "abc" -> !sol.string<Memory>
    %1 = sol.encode %0, %arg0 : (!sol.string<Memory>, ui8) -> !sol.string<Memory> {packed}
    %2 = sol.string_lit "abc" -> !sol.string<Memory>
    %3 = sol.encode %2 : (!sol.string<Memory>) -> !sol.string<Memory>
    sol.return %1, %3 : !sol.string<Memory>, !sol.string<Memory>
  }

  // The namespace slot of a literal is a constant: the ERC-7201 example.
  // CHECK-LABEL: sol.func @erc7201Literal(
  // CHECK-NEXT:    %[[SLOT:.*]] = sol.constant 10958655983261152271848436692291137275443024275653522991983264966744321209600 : ui256
  // CHECK-NEXT:    sol.return %[[SLOT]] : ui256
  sol.func @erc7201Literal() -> ui256 {
    %0 = sol.string_lit "example.main" -> !sol.string<Memory>
    %1 = "sol.erc7201"(%0) : (!sol.string<Memory>) -> ui256
    sol.return %1 : ui256
  }

  // CHECK-LABEL: sol.func @erc7201EmptyLiteral(
  // CHECK-NEXT:    %[[SLOT:.*]] = sol.constant 30348469548119976384149824193117947667795829812057172845188107037932402691072 : ui256
  // CHECK-NEXT:    sol.return %[[SLOT]] : ui256
  sol.func @erc7201EmptyLiteral() -> ui256 {
    %0 = sol.string_lit "" -> !sol.string<Memory>
    %1 = "sol.erc7201"(%0) : (!sol.string<Memory>) -> ui256
    sol.return %1 : ui256
  }

  // A literal with another use stays for it.
  // CHECK-LABEL: sol.func @erc7201UsedLiteral(
  // CHECK-NEXT:    %[[SLOT:.*]] = sol.constant 37439836327923360225337895871394760624280537466773280374265222508165906222592 : ui256
  // CHECK-NEXT:    %[[LITERAL:.*]] = sol.string_lit "openzeppelin.storage.ERC20" -> !sol.string<Memory>
  // CHECK-NEXT:    sol.return %[[SLOT]], %[[LITERAL]] : ui256, !sol.string<Memory>
  sol.func @erc7201UsedLiteral() -> (ui256, !sol.string<Memory>) {
    %0 = sol.string_lit "openzeppelin.storage.ERC20" -> !sol.string<Memory>
    %1 = "sol.erc7201"(%0) : (!sol.string<Memory>) -> ui256
    sol.return %1, %0 : ui256, !sol.string<Memory>
  }

  // CHECK-LABEL: sol.func @erc7201Argument(
  // CHECK-SAME:    %[[STRING:.*]]: !sol.string<Memory>
  // CHECK-NEXT:    %[[SLOT:.*]] = "sol.erc7201"(%[[STRING]]) : (!sol.string<Memory>) -> ui256
  // CHECK-NEXT:    sol.return %[[SLOT]] : ui256
  sol.func @erc7201Argument(%arg0: !sol.string<Memory>) -> ui256 {
    %0 = "sol.erc7201"(%arg0) : (!sol.string<Memory>) -> ui256
    sol.return %0 : ui256
  }
} {kind = #sol<ContractKind Contract>, runtime}
