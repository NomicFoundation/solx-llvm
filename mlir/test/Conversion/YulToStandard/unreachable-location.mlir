// RUN: mlir-opt %s -convert-yul-to-std -mlir-print-debuginfo \
// RUN:   -mlir-print-local-scope | FileCheck %s

// The .unreachable wrapper is shared by every caller, so its body is at line 0
// of the module hosting it, even when its first caller is in another file. The
// call keeps the caller's location.

module {
  func.func @imported() {
    %c0 = arith.constant 0 : i256 loc(#loc_revert)
    yul.revert %c0, %c0 loc(#loc_revert)
    return loc(#loc_revert)
  } loc(#loc_imported)
} loc(#loc_host)

#loc_host = loc("Host.sol":2:1)
#loc_imported = loc("Imported.sol":1:1)
#loc_revert = loc("Imported.sol":2:5)

// CHECK-LABEL: func.func @".unreachable"()
// CHECK-NEXT:    llvm.unreachable loc("Host.sol":0:0)
// CHECK-NEXT:  } loc("Host.sol":2:1)
// CHECK-LABEL: func.func @imported()
// CHECK:         call @".unreachable"() : () -> () loc("Imported.sol":2:5)
