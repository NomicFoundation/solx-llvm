// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK-LABEL: func @roundtrip
func.func @roundtrip(%a: !sol.string<Memory>, %b: !sol.fixedbytes<16>) {
  // CHECK: sol.concat -> <Memory>
  %0 = sol.concat -> <Memory>
  // CHECK: sol.concat {foo} -> <Memory>
  %1 = sol.concat {foo} -> <Memory>
  // CHECK: sol.concat %{{.*}} : !sol.string<Memory> -> <Memory>
  %2 = sol.concat %a : !sol.string<Memory> -> <Memory>
  // CHECK: sol.concat %{{.*}}, %{{.*}} : !sol.string<Memory>, !sol.fixedbytes<16> {foo} -> <Memory>
  %3 = sol.concat %a, %b : !sol.string<Memory>, !sol.fixedbytes<16> {foo} -> <Memory>
  return
}
