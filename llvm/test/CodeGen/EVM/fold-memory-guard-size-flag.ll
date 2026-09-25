; RUN: opt -passes=evm-fold-memory-guard -S < %s | FileCheck %s

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare i256 @llvm.evm.memoryguard()

; The spill region is [guard, guard + size), so the free memory pointer is
; initialized past it. Both values come from module flags.

; CHECK-LABEL: define void @init(
; CHECK: store i256 160, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1))
; CHECK-NOT: llvm.evm.memoryguard

define void @init() {
  %guard = call i256 @llvm.evm.memoryguard()
  store i256 %guard, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1))
  ret void
}

!llvm.module.flags = !{!0, !1}
!0 = !{i32 1, !"evm-memory-guard", i64 128}
!1 = !{i32 1, !"evm-stack-region-size", i64 32}
