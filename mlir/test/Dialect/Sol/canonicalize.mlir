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
} {kind = #sol<ContractKind Contract>, runtime}
