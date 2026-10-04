// RUN: mlir-opt %s --convert-sol-to-yul | FileCheck %s

// CHECK-LABEL: yul.func @origin : () -> i256
// CHECK:         %[[V:.*]] = yul.origin
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @gasprice : () -> i256
// CHECK:         %[[V:.*]] = yul.gasprice
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @callvalue : () -> i256
// CHECK:         %[[V:.*]] = yul.callvalue
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @caller : () -> i256
// CHECK:         %[[V:.*]] = yul.caller
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @this : () -> i256
// CHECK:         %[[V:.*]] = yul.address
// CHECK:         yul.func_return %[[V]] : i256

// msg.sig is the left-aligned first 4 bytes of calldata.
// CHECK-LABEL: yul.func @sig : () -> i256
// CHECK:         %[[W:.*]] = yul.calldataload
// CHECK:         %[[M:.*]] = yul.constant -26959946667150639794667015087019630673637144422540572481103610249216
// CHECK:         %[[V:.*]] = yul.and %[[W]], %[[M]]
// CHECK:         yul.func_return %[[V]] : i256

// msg.data is the calldata slice {0, calldatasize}.
// CHECK-LABEL: yul.func @data_len : () -> i256
// CHECK:         %[[Z:.*]] = yul.constant 0
// CHECK:         %[[SZ:.*]] = yul.calldatasize
// CHECK:         %[[D0:.*]] = llvm.insertvalue %[[Z]], %{{.*}}[0]
// CHECK:         %[[D:.*]] = llvm.insertvalue %[[SZ]], %[[D0]][1]
// CHECK:         %[[LEN:.*]] = llvm.extractvalue %[[D]][1]
// CHECK:         yul.func_return %[[LEN]] : i256

// CHECK-LABEL: yul.func @basefee : () -> i256
// CHECK:         %[[V:.*]] = yul.basefee
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @blobbasefee : () -> i256
// CHECK:         %[[V:.*]] = yul.blobbasefee
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @chainid : () -> i256
// CHECK:         %[[V:.*]] = yul.chainid
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @coinbase : () -> i256
// CHECK:         %[[V:.*]] = yul.coinbase
// CHECK:         yul.func_return %[[V]] : i256

// block.difficulty is prevrandao since Paris.
// CHECK-LABEL: yul.func @difficulty : () -> i256
// CHECK:         %[[V:.*]] = yul.prevrandao
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @gaslimit : () -> i256
// CHECK:         %[[V:.*]] = yul.gaslimit
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @blocknumber : () -> i256
// CHECK:         %[[V:.*]] = yul.number
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @prevrandao : () -> i256
// CHECK:         %[[V:.*]] = yul.prevrandao
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @timestamp : () -> i256
// CHECK:         %[[V:.*]] = yul.timestamp
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @gasleft : () -> i256
// CHECK:         %[[V:.*]] = yul.gas
// CHECK:         yul.func_return %[[V]] : i256

// CHECK-LABEL: yul.func @blockhash : (i256) -> i256
// CHECK:         %[[H:.*]] = yul.blockhash %arg0
// CHECK:         yul.func_return %[[H]] : i256

// CHECK-LABEL: yul.func @blobhash : (i256) -> i256
// CHECK:         %[[H:.*]] = yul.blobhash %arg0
// CHECK:         yul.func_return %[[H]] : i256

#Default = #sol<RevertStrings Default>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.revert_strings = #Default} {
  sol.func @origin() -> !sol.address {
    %0 = sol.origin : !sol.address
    sol.return %0 : !sol.address
  }
  sol.func @gasprice() -> ui256 {
    %0 = sol.gasprice : ui256
    sol.return %0 : ui256
  }
  sol.func @callvalue() -> ui256 {
    %0 = sol.callvalue : ui256
    sol.return %0 : ui256
  }
  sol.func @caller() -> !sol.address {
    %0 = sol.caller : !sol.address
    sol.return %0 : !sol.address
  }
  sol.func @this() -> !sol.address {
    %0 = sol.this : !sol.contract<"C">
    %1 = sol.address_cast %0 : !sol.contract<"C"> to !sol.address
    sol.return %1 : !sol.address
  }
  sol.func @sig() -> !sol.fixedbytes<4> {
    %0 = sol.sig : !sol.fixedbytes<4>
    sol.return %0 : !sol.fixedbytes<4>
  }
  sol.func @data_len() -> ui256 {
    %0 = sol.get_calldata : !sol.string<CallData>
    %1 = sol.length %0 : !sol.string<CallData>
    sol.return %1 : ui256
  }
  sol.func @basefee() -> ui256 {
    %0 = sol.basefee : ui256
    sol.return %0 : ui256
  }
  sol.func @blobbasefee() -> ui256 {
    %0 = sol.blobbasefee : ui256
    sol.return %0 : ui256
  }
  sol.func @chainid() -> ui256 {
    %0 = sol.chainid : ui256
    sol.return %0 : ui256
  }
  sol.func @coinbase() -> !sol.address<payable> {
    %0 = sol.coinbase : !sol.address<payable>
    sol.return %0 : !sol.address<payable>
  }
  sol.func @difficulty() -> ui256 {
    %0 = sol.difficulty : ui256
    sol.return %0 : ui256
  }
  sol.func @gaslimit() -> ui256 {
    %0 = sol.gaslimit : ui256
    sol.return %0 : ui256
  }
  sol.func @blocknumber() -> ui256 {
    %0 = sol.blocknumber : ui256
    sol.return %0 : ui256
  }
  sol.func @prevrandao() -> ui256 {
    %0 = sol.prevrandao : ui256
    sol.return %0 : ui256
  }
  sol.func @timestamp() -> ui256 {
    %0 = sol.timestamp : ui256
    sol.return %0 : ui256
  }
  sol.func @gasleft() -> ui256 {
    %0 = sol.gasleft : ui256
    sol.return %0 : ui256
  }
  sol.func @blockhash(%arg0: ui256) -> !sol.fixedbytes<32> {
    %0 = sol.blockhash %arg0 : <32>
    sol.return %0 : !sol.fixedbytes<32>
  }
  sol.func @blobhash(%arg0: ui256) -> !sol.fixedbytes<32> {
    %0 = sol.blobhash %arg0 : <32>
    sol.return %0 : !sol.fixedbytes<32>
  }
}
