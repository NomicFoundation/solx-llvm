// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK-LABEL: yul.func @if
yul.func @if : (i256, i256) -> () {
^bb0(%c: i256, %a: i256):
  // CHECK:      yul.if %{{.*}} {
  // CHECK-NEXT:   yul.yield{{$}}
  // CHECK-NEXT: } else {
  // CHECK-NEXT: }
  yul.if %c {
    yul.yield
  } else {
  }
  // CHECK:      yul.if %{{.*}} -> i256 {
  // CHECK-NEXT:   yul.yield %{{.*}} : i256{{$}}
  // CHECK-NEXT: } else {
  // CHECK-NEXT:   yul.yield %{{.*}} : i256{{$}}
  // CHECK-NEXT: }
  %0 = yul.if %c -> i256 {
    yul.yield %a : i256
  } else {
    yul.yield %c : i256
  }
  // CHECK:      yul.if %{{.*}} -> i256, i256 {
  // CHECK-NEXT:   yul.yield %{{.*}}, %{{.*}} : i256, i256 {foo}{{$}}
  // CHECK-NEXT: } else {
  // CHECK-NEXT:   yul.yield %{{.*}}, %{{.*}} : i256, i256{{$}}
  // CHECK-NEXT: } {bar}
  %1:2 = yul.if %c -> i256, i256 {
    yul.yield %a, %c : i256, i256 {foo}
  } else {
    yul.yield %c, %a : i256, i256
  } {bar}
  yul.func_return
}

// CHECK-LABEL: yul.func @while
yul.func @while : (i256, i256) -> () {
^bb0(%c: i256, %a: i256):
  // CHECK:      yul.while {
  // CHECK-NEXT:   yul.condition %{{.*}}{{$}}
  // CHECK-NEXT: } do {
  // CHECK-NEXT:   yul.yield{{$}}
  // CHECK-NEXT: }
  yul.while {
    yul.condition %c
  } do {
    yul.yield
  }
  // CHECK:      yul.while %{{.*}} : i256 -> i256 {
  // CHECK-NEXT: ^bb0(%{{.*}}: i256):
  // CHECK-NEXT:   yul.condition %{{.*}}, %{{.*}} : i256{{$}}
  // CHECK-NEXT: } do {
  // CHECK-NEXT: ^bb0(%{{.*}}: i256):
  // CHECK-NEXT:   yul.yield %{{.*}} : i256{{$}}
  // CHECK-NEXT: }
  %0 = yul.while %a : i256 -> i256 {
  ^bb0(%x: i256):
    yul.condition %x, %x : i256
  } do {
  ^bb0(%x: i256):
    yul.yield %x : i256
  }
  // CHECK:      yul.while %{{.*}}, %{{.*}} : i256, i256 -> i256, i256 {
  // CHECK-NEXT: ^bb0(%{{.*}}: i256, %{{.*}}: i256):
  // CHECK-NEXT:   yul.condition %{{.*}}, %{{.*}}, %{{.*}} : i256, i256 {foo}{{$}}
  // CHECK-NEXT: } do {
  // CHECK-NEXT: ^bb0(%{{.*}}: i256, %{{.*}}: i256):
  // CHECK-NEXT:   yul.yield %{{.*}}, %{{.*}} : i256, i256{{$}}
  // CHECK-NEXT: } {bar}
  %1:2 = yul.while %a, %c : i256, i256 -> i256, i256 {
  ^bb0(%x: i256, %y: i256):
    yul.condition %y, %x, %y : i256, i256 {foo}
  } do {
  ^bb0(%x: i256, %y: i256):
    yul.yield %x, %y : i256, i256
  } {bar}
  yul.func_return
}

// CHECK-LABEL: yul.func @for
yul.func @for : (i256, i256) -> () {
^bb0(%c: i256, %a: i256):
  // CHECK:      yul.for cond {
  // CHECK-NEXT:   yul.condition %{{.*}}{{$}}
  // CHECK-NEXT: } body {
  // CHECK-NEXT:   yul.yield{{$}}
  // CHECK-NEXT: } step {
  // CHECK-NEXT:   yul.yield{{$}}
  // CHECK-NEXT: }
  yul.for cond {
    yul.condition %c
  } body {
    yul.yield
  } step {
    yul.yield
  }
  // CHECK:      yul.for %{{.*}} : i256 -> i256 cond {
  // CHECK-NEXT: ^bb0(%{{.*}}: i256):
  // CHECK-NEXT:   yul.condition %{{.*}}, %{{.*}} : i256{{$}}
  // CHECK-NEXT: } body {
  // CHECK-NEXT: ^bb0(%{{.*}}: i256):
  // CHECK-NEXT:   yul.yield %{{.*}} : i256{{$}}
  // CHECK-NEXT: } step {
  // CHECK-NEXT: ^bb0(%{{.*}}: i256):
  // CHECK-NEXT:   yul.yield %{{.*}} : i256{{$}}
  // CHECK-NEXT: } {full_unroll}
  %0 = yul.for %a : i256 -> i256 cond {
  ^bb0(%i: i256):
    yul.condition %i, %i : i256
  } body {
  ^bb0(%i: i256):
    yul.yield %i : i256
  } step {
  ^bb0(%i: i256):
    yul.yield %i : i256
  } {full_unroll}
  // CHECK:      yul.for %{{.*}}, %{{.*}} : i256, i256 -> i256, i256 cond {
  // CHECK-NEXT: ^bb0(%{{.*}}: i256, %{{.*}}: i256):
  // CHECK-NEXT:   yul.condition %{{.*}}, %{{.*}}, %{{.*}} : i256, i256{{$}}
  // CHECK-NEXT: } body {
  // CHECK-NEXT: ^bb0(%{{.*}}: i256, %{{.*}}: i256):
  // CHECK-NEXT:   yul.yield %{{.*}}, %{{.*}} : i256, i256{{$}}
  // CHECK-NEXT: } step {
  // CHECK-NEXT: ^bb0(%{{.*}}: i256, %{{.*}}: i256):
  // CHECK-NEXT:   yul.yield %{{.*}}, %{{.*}} : i256, i256{{$}}
  // CHECK-NEXT: }{{$}}
  %1:2 = yul.for %a, %c : i256, i256 -> i256, i256 cond {
  ^bb0(%i: i256, %j: i256):
    yul.condition %j, %i, %j : i256, i256
  } body {
  ^bb0(%i: i256, %j: i256):
    yul.yield %i, %j : i256, i256
  } step {
  ^bb0(%i: i256, %j: i256):
    yul.yield %i, %j : i256, i256
  }
  yul.func_return
}
