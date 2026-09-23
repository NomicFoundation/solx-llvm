; RUN: opt -passes=evm-always-inline -evm-helper-noinline-min-insts=5 -S < %s | FileCheck %s

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

; CHECK-NOT: Function Attrs: alwaysinline
; CHECK-LABEL: @test_noinline_recursion
define void @test_noinline_recursion() {
  call void @test_noinline_recursion()
  ret void
}

; Compiler-generated helpers, marked by the frontend with "evm.sol_helper": a
; helper shared by two or more call sites is kept out of line once it is large
; enough; a small shared helper and a single-use helper are left to the usual
; rules. A function without the attribute is never marked noinline, whatever
; its name.

; CHECK: Function Attrs: noinline
; CHECK-LABEL: @__sol.shared_big
define void @__sol.shared_big(ptr addrspace(1) %p) "evm.sol_helper" {
  %a = load i256, ptr addrspace(1) %p
  %b = add i256 %a, 1
  %c = mul i256 %b, 3
  %d = xor i256 %c, 7
  store i256 %d, ptr addrspace(1) %p
  ret void
}

; CHECK-NOT: Function Attrs: noinline
; CHECK-NOT: Function Attrs: alwaysinline
; CHECK-LABEL: @__sol.shared_small
define void @__sol.shared_small(ptr addrspace(1) %p) "evm.sol_helper" {
  store i256 1, ptr addrspace(1) %p
  ret void
}

; CHECK: Function Attrs: alwaysinline
; CHECK-LABEL: @__sol.once
define void @__sol.once(ptr addrspace(1) %p) "evm.sol_helper" {
  %a = load i256, ptr addrspace(1) %p
  %b = add i256 %a, 1
  %c = mul i256 %b, 3
  %d = xor i256 %c, 7
  store i256 %d, ptr addrspace(1) %p
  ret void
}

; A recursive helper counts only its external call sites.
; CHECK: Function Attrs: noinline
; CHECK-LABEL: @__sol.shared_recursive
define void @__sol.shared_recursive(ptr addrspace(1) %p) "evm.sol_helper" {
  %a = load i256, ptr addrspace(1) %p
  %b = add i256 %a, 1
  %c = mul i256 %b, 3
  %d = xor i256 %c, 7
  store i256 %d, ptr addrspace(1) %p
  call void @__sol.shared_recursive(ptr addrspace(1) %p)
  ret void
}

; CHECK-NOT: Function Attrs: noinline
; CHECK-LABEL: @test_helpers
define void @test_helpers(ptr addrspace(1) %p) {
  call void @__sol.shared_big(ptr addrspace(1) %p)
  call void @__sol.shared_big(ptr addrspace(1) %p)
  call void @__sol.shared_small(ptr addrspace(1) %p)
  call void @__sol.shared_small(ptr addrspace(1) %p)
  call void @__sol.once(ptr addrspace(1) %p)
  call void @__sol.shared_recursive(ptr addrspace(1) %p)
  call void @__sol.shared_recursive(ptr addrspace(1) %p)
  ret void
}

; A shared, large, unmarked function that merely looks like a helper is left
; alone: the attribute is what identifies a helper, not the name.
; CHECK-NOT: Function Attrs: noinline
; CHECK-LABEL: @__sol.not_a_helper
define void @__sol.not_a_helper(ptr addrspace(1) %p) {
  %a = load i256, ptr addrspace(1) %p
  %b = add i256 %a, 1
  %c = mul i256 %b, 3
  %d = xor i256 %c, 7
  store i256 %d, ptr addrspace(1) %p
  ret void
}

; CHECK-NOT: Function Attrs: noinline
; CHECK-LABEL: @test_unmarked
define void @test_unmarked(ptr addrspace(1) %p) {
  call void @__sol.not_a_helper(ptr addrspace(1) %p)
  call void @__sol.not_a_helper(ptr addrspace(1) %p)
  ret void
}
