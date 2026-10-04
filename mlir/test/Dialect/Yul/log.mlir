// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK-LABEL: yul.func @roundtrip
yul.func @roundtrip : (i256, i256, i256) -> () {
^bb0(%addr: i256, %size: i256, %t: i256):
  // CHECK:      yul.log %{{.*}}, %{{.*}}
  // CHECK-NEXT: yul.log %{{.*}}, %{{.*}} topics(%{{.*}}){{$}}
  // CHECK-NEXT: yul.log %{{.*}}, %{{.*}} topics(%{{.*}}, %{{.*}}){{$}}
  // CHECK-NEXT: yul.log %{{.*}}, %{{.*}} topics(%{{.*}}, %{{.*}}, %{{.*}}){{$}}
  // CHECK-NEXT: yul.log %{{.*}}, %{{.*}} topics(%{{.*}}, %{{.*}}, %{{.*}}, %{{.*}}) {foo}{{$}}
  yul.log %addr, %size
  yul.log %addr, %size topics(%t)
  yul.log %addr, %size topics(%t, %t)
  yul.log %addr, %size topics(%t, %t, %t)
  yul.log %addr, %size topics(%t, %t, %t, %t) {foo}
  yul.func_return
}
