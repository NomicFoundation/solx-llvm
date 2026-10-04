// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK:      yul.func @none : () -> () {
// CHECK-NEXT:   yul.func_return{{$}}
yul.func @none : () -> () {
  yul.func_return
}

// CHECK:      yul.func @one : (i256) -> i256 {
// CHECK-NEXT: ^bb0(%{{.*}}: i256):
// CHECK-NEXT:   yul.func_return %{{.*}} : i256{{$}}
yul.func @one : (i256) -> i256 {
^bb0(%a: i256):
  yul.func_return %a : i256
}

// CHECK:      yul.func @many : (i256, i256) -> (i256, i256) {
// CHECK-NEXT: ^bb0(%{{.*}}: i256, %{{.*}}: i256):
// CHECK-NEXT:   yul.func_call @none() : () -> (){{$}}
// CHECK-NEXT:   yul.func_call @one(%{{.*}}) : (i256) -> i256{{$}}
// CHECK-NEXT:   yul.func_call @many(%{{.*}}, %{{.*}}) {foo} : (i256, i256) -> (i256, i256){{$}}
// CHECK-NEXT:   yul.func_return {bar} %{{.*}}#0, %{{.*}}#1 : i256, i256{{$}}
// CHECK-NEXT: } {unsafe_asm}
yul.func @many : (i256, i256) -> (i256, i256) {
^bb0(%a: i256, %b: i256):
  yul.func_call @none() : () -> ()
  %0 = yul.func_call @one(%a) : (i256) -> i256
  %1:2 = yul.func_call @many(%a, %b) {foo} : (i256, i256) -> (i256, i256)
  yul.func_return {bar} %1#0, %1#1 : i256, i256
} {unsafe_asm}
