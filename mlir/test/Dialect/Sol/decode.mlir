// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK-LABEL: func @roundtrip
func.func @roundtrip(%data: !sol.string<Memory>) {
  // CHECK: sol.decode %{{.*}} : !sol.string<Memory> ->{{ *$}}
  sol.decode %data : !sol.string<Memory> ->
  // CHECK: sol.decode %{{.*}} : !sol.string<Memory> -> {foo}
  sol.decode %data : !sol.string<Memory> -> {foo}
  // CHECK: sol.decode %{{.*}} : !sol.string<Memory> -> ui256{{$}}
  %0 = sol.decode %data : !sol.string<Memory> -> ui256
  // CHECK: sol.decode %{{.*}} : !sol.string<Memory> -> ui256, !sol.address{{$}}
  %1:2 = sol.decode %data : !sol.string<Memory> -> ui256, !sol.address
  return
}
