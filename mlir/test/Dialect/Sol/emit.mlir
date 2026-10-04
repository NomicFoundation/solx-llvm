// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK-LABEL: func @roundtrip
func.func @roundtrip(%a: ui256, %b: !sol.string<Memory>) {
  // CHECK:      sol.emit{{$}}
  // CHECK-NEXT: sol.constant 1
  sol.emit
  %c1 = sol.constant 1 : ui256
  // CHECK:      sol.emit "E()"{{$}}
  // CHECK-NEXT: sol.constant 2
  sol.emit "E()"
  %c2 = sol.constant 2 : ui256
  // CHECK: sol.emit indexed = [%{{.*}}] : ui256
  sol.emit indexed = [%a] : ui256
  // CHECK: sol.emit "E(string)" non_indexed = [%{{.*}}] : !sol.string<Memory>
  sol.emit "E(string)" non_indexed = [%b] : !sol.string<Memory>
  // CHECK: sol.emit "E(uint256,uint256,string)" indexed = [%{{.*}}, %{{.*}}] non_indexed = [%{{.*}}] : ui256, ui256, !sol.string<Memory>
  sol.emit "E(uint256,uint256,string)" indexed = [%a, %a] non_indexed = [%b] : ui256, ui256, !sol.string<Memory>
  // CHECK: sol.emit "E(uint256)" indexed = [%{{.*}}] {foo} : ui256
  sol.emit "E(uint256)" indexed = [%a] {foo} : ui256
  return
}
