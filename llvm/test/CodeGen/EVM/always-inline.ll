; RUN: opt -passes=evm-always-inline -S < %s | FileCheck %s

target datalayout = "E-p:256:256-i256:256:256-S32-a:256:256"
target triple = "evm"

; CHECK: Function Attrs: alwaysinline
; CHECK-LABEL: @inline
define void @inline() {
  ret void
}

; CHECK-NOT: Function Attrs: alwaysinline
; CHECK-LABEL: @noinline
define void @noinline() {
  ret void
}

; CHECK-NOT: Function Attrs: alwaysinline
; CHECK-LABEL: @test
define void @test() {
  call void @inline()
  call void @noinline()
  call void @noinline()
  ret void
}

; CHECK-NOT: Function Attrs: alwaysinline
; CHECK-LABEL: @callattr
define void @callattr() {
  ret void
}

; CHECK-NOT: Function Attrs: alwaysinline
; CHECK-LABEL: @test_noinline_callattr
define void @test_noinline_callattr() {
  call void @callattr() noinline
  ret void
}

; A self-recursive function is kept out of line.
; CHECK: Function Attrs: noinline
; CHECK-NEXT: define void @test_noinline_recursion()
define void @test_noinline_recursion() {
  call void @test_noinline_recursion()
  ret void
}

; Both functions of a call graph cycle are kept out of line, although each
; has a single call site.
; CHECK: Function Attrs: noinline
; CHECK-NEXT: define void @mutual_a()
define void @mutual_a() {
  call void @mutual_b()
  ret void
}

; CHECK: Function Attrs: noinline
; CHECK-NEXT: define void @mutual_b()
define void @mutual_b() {
  call void @mutual_a()
  ret void
}

; A helper of the cycle with one call site is still inlined into its caller.
; CHECK: Function Attrs: alwaysinline
; CHECK-NEXT: define void @cycle_helper()
define void @cycle_helper() {
  ret void
}

; CHECK: Function Attrs: noinline
; CHECK-NEXT: define void @cycle_c()
define void @cycle_c() {
  call void @cycle_helper()
  call void @cycle_d()
  ret void
}

; CHECK: Function Attrs: noinline
; CHECK-NEXT: define void @cycle_d()
define void @cycle_d() {
  call void @cycle_c()
  ret void
}
