// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul | FileCheck %s

// zero_init bumps the free pointer, then zeroes value elements by copying from
// past calldata, points dynamic-array/string elements at the zero slot (0x60)
// and gives static-array/struct elements a fresh zeroed allocation.

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @static_1d : () -> i256
    // CHECK:         %[[SZ:.*]] = yul.constant 96{{$}}
    // CHECK:         %[[P:.*]] = yul.mload
    // CHECK:         %[[CDS:.*]] = yul.calldatasize
    // CHECK:         yul.calldatacopy %[[P]], %[[CDS]], %[[SZ]]
    // CHECK:         yul.func_return %[[P]] : i256
    sol.func @static_1d() -> !sol.array<3 x ui256, Memory> {
      %0 = sol.malloc zero_init : () -> !sol.array<3 x ui256, Memory>
      sol.return %0 : !sol.array<3 x ui256, Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @static_2d : () -> i256
    // CHECK:         %[[SZ:.*]] = yul.constant 128{{$}}
    // CHECK:         %[[P:.*]] = yul.mload
    // CHECK:         yul.for
    // CHECK:           yul.cmp ult, %arg0, %[[SZ]]
    // CHECK:         } body {
    // CHECK:           %[[SLOT:.*]] = yul.add %[[P]], %arg0
    // CHECK:           %[[ISZ:.*]] = yul.constant 96{{$}}
    // CHECK:           %[[IP:.*]] = yul.mload
    // CHECK:           %[[CDS:.*]] = yul.calldatasize
    // CHECK:           yul.calldatacopy %[[IP]], %[[CDS]], %[[ISZ]]
    // CHECK:           yul.mstore %[[SLOT]], %[[IP]]
    // CHECK:         } step {
    sol.func @static_2d() -> !sol.array<4 x !sol.array<3 x ui256, Memory>, Memory> {
      %0 = sol.malloc zero_init : () -> !sol.array<4 x !sol.array<3 x ui256, Memory>, Memory>
      sol.return %0 : !sol.array<4 x !sol.array<3 x ui256, Memory>, Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // A static array has no length word: the element slots start at the base.
    // CHECK-LABEL: yul.func @static_of_dyn : () -> i256
    // CHECK:         %[[SZ:.*]] = yul.constant 64{{$}}
    // CHECK:         %[[P:.*]] = yul.mload
    // CHECK:         yul.for
    // CHECK:           yul.cmp ult, %arg0, %[[SZ]]
    // CHECK:         } body {
    // CHECK:           %[[E:.*]] = yul.add %[[P]], %arg0
    // CHECK:           %[[ZERO:.*]] = yul.constant 96{{$}}
    // CHECK:           yul.mstore %[[E]], %[[ZERO]]
    // CHECK:         } step {
    // CHECK:         yul.func_return %[[P]] : i256
    sol.func @static_of_dyn() -> !sol.array<2 x !sol.array<? x ui256, Memory>, Memory> {
      %0 = sol.malloc zero_init : () -> !sol.array<2 x !sol.array<? x ui256, Memory>, Memory>
      sol.return %0 : !sol.array<2 x !sol.array<? x ui256, Memory>, Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @dyn_1d : () -> i256
    // CHECK:         %[[C5:.*]] = yul.constant 5{{$}}
    // CHECK:         %[[LEN:.*]] = yul.and %[[C5]], %{{.*}}
    // CHECK:         %[[DSZ:.*]] = yul.mul %[[LEN]], %{{.*}}
    // CHECK:         %[[P:.*]] = yul.mload
    // CHECK:         yul.mstore %[[P]], %[[LEN]]
    // CHECK:         %[[DATA:.*]] = yul.add %[[P]], %{{.*}}
    // CHECK:         %[[CDS:.*]] = yul.calldatasize
    // CHECK:         yul.calldatacopy %[[DATA]], %[[CDS]], %[[DSZ]]
    // CHECK:         yul.func_return %[[P]] : i256
    sol.func @dyn_1d() -> !sol.array<? x ui256, Memory> {
      %c5_ui8 = sol.constant 5 : ui8
      %0 = sol.malloc %c5_ui8 zero_init : (ui8) -> !sol.array<? x ui256, Memory>
      sol.return %0 : !sol.array<? x ui256, Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @dyn_2d : (i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[N:.*]]: i256):
    // CHECK:         %[[DSZ:.*]] = yul.mul %[[N]], %{{.*}}
    // CHECK:         %[[P:.*]] = yul.mload
    // CHECK:         yul.mstore %[[P]], %[[N]]
    // CHECK:         %[[DATA:.*]] = yul.add %[[P]], %{{.*}}
    // CHECK:         yul.for
    // CHECK:           yul.cmp ult, %arg1, %[[DSZ]]
    // CHECK:         } body {
    // CHECK:           %[[E:.*]] = yul.add %[[DATA]], %arg1
    // CHECK:           %[[ZERO:.*]] = yul.constant 96{{$}}
    // CHECK:           yul.mstore %[[E]], %[[ZERO]]
    // CHECK:         } step {
    // CHECK:         yul.func_return %[[P]] : i256
    sol.func @dyn_2d(%n: ui256) -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory> {
      %0 = sol.malloc %n zero_init : (ui256) -> !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
      sol.return %0 : !sol.array<? x !sol.array<? x ui256, Memory>, Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @dyn_of_struct : (i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[N:.*]]: i256):
    // CHECK:         %[[DSZ:.*]] = yul.mul %[[N]], %{{.*}}
    // CHECK:         %[[P:.*]] = yul.mload
    // CHECK:         yul.mstore %[[P]], %[[N]]
    // CHECK:         %[[DATA:.*]] = yul.add %[[P]], %{{.*}}
    // CHECK:         yul.for
    // CHECK:           yul.cmp ult, %arg1, %[[DSZ]]
    // CHECK:         } body {
    // CHECK:           %[[E:.*]] = yul.add %[[DATA]], %arg1
    // CHECK:           %[[S:.*]] = yul.mload
    // CHECK:           yul.mstore %c64_i256{{.*}}, %{{.*}}
    // CHECK-NEXT:      %[[Z0:.*]] = yul.constant 0{{$}}
    // CHECK-NEXT:      yul.mstore %[[S]], %[[Z0]]
    // CHECK:           %[[F1:.*]] = yul.add %[[S]], %{{.*}}
    // CHECK:           %[[Z1:.*]] = yul.constant 96{{$}}
    // CHECK:           yul.mstore %[[F1]], %[[Z1]]
    // CHECK:           %[[F2:.*]] = yul.add %[[S]], %{{.*}}
    // CHECK:           %[[Z2:.*]] = yul.constant 96{{$}}
    // CHECK:           yul.mstore %[[F2]], %[[Z2]]
    // CHECK:           yul.mstore %[[E]], %[[S]]
    // CHECK:         } step {
    sol.func @dyn_of_struct(%n: ui256) -> !sol.array<? x !sol.struct<(ui256, !sol.string<Memory>, !sol.array<? x ui256, Memory>), Memory>, Memory> {
      %0 = sol.malloc %n zero_init : (ui256) -> !sol.array<? x !sol.struct<(ui256, !sol.string<Memory>, !sol.array<? x ui256, Memory>), Memory>, Memory>
      sol.return %0 : !sol.array<? x !sol.struct<(ui256, !sol.string<Memory>, !sol.array<? x ui256, Memory>), Memory>, Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // CHECK-LABEL: yul.func @struct : () -> i256
    // CHECK:         %[[S:.*]] = yul.mload
    // CHECK:         yul.mstore %c64_i256{{.*}}, %{{.*}}
    // CHECK-NEXT:    %[[Z:.*]] = yul.constant 0{{$}}
    // CHECK-NEXT:    yul.mstore %[[S]], %[[Z]]
    // CHECK:         %[[F1:.*]] = yul.add %[[S]], %{{.*}}
    // CHECK:         %[[ASZ:.*]] = yul.constant 96{{$}}
    // CHECK:         %[[ARR:.*]] = yul.mload
    // CHECK:         %[[CDS:.*]] = yul.calldatasize
    // CHECK:         yul.calldatacopy %[[ARR]], %[[CDS]], %[[ASZ]]
    // CHECK:         yul.mstore %[[F1]], %[[ARR]]
    // CHECK:         yul.func_return %[[S]] : i256
    sol.func @struct() -> !sol.struct<(ui256, !sol.array<3 x ui256, Memory>), Memory> {
      %0 = sol.malloc zero_init : () -> !sol.struct<(ui256, !sol.array<3 x ui256, Memory>), Memory>
      sol.return %0 : !sol.struct<(ui256, !sol.array<3 x ui256, Memory>), Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}

// -----

module {
  sol.contract @C {
    // bytes(n) reserves round_up(n, 32) data bytes after the length word and
    // zero-fills all of them; a free-pointer overflow panics with 0x41.
    // CHECK-LABEL: yul.func @bytes : (i256) -> i256
    // CHECK-NEXT:  ^bb0(%[[N:.*]]: i256):
    // CHECK:         %[[N31:.*]] = yul.add %[[N]], %c31_i256
    // CHECK:         %[[DSZ:.*]] = yul.and %[[N31]], %c-32_i256
    // CHECK:         %[[SZ:.*]] = yul.add %[[DSZ]], %c32_i256
    // CHECK:         %[[P:.*]] = yul.mload %c64_i256
    // CHECK:         %[[SZ31:.*]] = yul.add %[[SZ]], %c31_i256
    // CHECK:         %[[ASZ:.*]] = yul.and %[[SZ31]], %c-32_i256
    // CHECK:         %[[END:.*]] = yul.add %[[P]], %[[ASZ]]
    // CHECK:         %[[OVF:.*]] = yul.cmp ugt, %[[END]], %c18446744073709551615_i256
    // CHECK:         %[[WRAP:.*]] = yul.cmp ult, %[[END]], %[[P]]
    // CHECK:         %[[BAD:.*]] = yul.or %[[OVF]], %[[WRAP]]
    // CHECK:         yul.if %[[BAD]] {
    // CHECK:           yul.mstore %{{.*}}, %c65_i256
    // CHECK:         yul.mstore %c64_i256{{.*}}, %[[END]]
    // CHECK:         yul.mstore %[[P]], %[[N]]
    // CHECK:         %[[DATA:.*]] = yul.add %[[P]], %c32_i256
    // CHECK:         %[[CDS:.*]] = yul.calldatasize
    // CHECK:         yul.calldatacopy %[[DATA]], %[[CDS]], %[[DSZ]]
    // CHECK:         yul.func_return %[[P]] : i256
    sol.func @bytes(%n: ui256) -> !sol.string<Memory> {
      %0 = sol.malloc %n zero_init : (ui256) -> !sol.string<Memory>
      sol.return %0 : !sol.string<Memory>
    }
  } {kind = #sol<ContractKind Contract>, runtime}
}
