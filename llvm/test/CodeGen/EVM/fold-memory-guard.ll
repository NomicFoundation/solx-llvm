; RUN: opt -passes=evm-fold-memory-guard -S < %s | FileCheck %s
; RUN: opt -passes='default<O0>' -S < %s | FileCheck %s
; RUN: not opt -passes=evm-verifier -S < %s 2>&1 | FileCheck --check-prefix=VERIFY %s

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare i256 @llvm.evm.memoryguard()

; With an empty region the free memory pointer keeps the guard the front end
; put on the module.

; CHECK-LABEL: define void @init(
; CHECK: store i256 128, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1))
; CHECK-NOT: llvm.evm.memoryguard

; VERIFY: EVM memoryguard must be folded before codegen, run evm-fold-memory-guard
; VERIFY: LLVM ERROR: Broken module found, compilation aborted!

define void @init() {
  %guard = call i256 @llvm.evm.memoryguard()
  store i256 %guard, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1))
  ret void
}

!llvm.module.flags = !{!0, !1}
!0 = !{i32 1, !"evm-memory-guard", i64 128}
!1 = !{i32 1, !"evm-stack-region-size", i64 0}
