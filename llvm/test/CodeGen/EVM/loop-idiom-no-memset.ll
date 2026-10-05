; RUN: opt -passes=loop-idiom -S < %s | FileCheck %s

; EVM has no memset libcall and TargetLibraryInfo disables every libcall for
; the evm triple. LoopIdiomRecognize must therefore leave memset candidates
; alone: a store loop must not become a memset, and a memset inside a loop must
; not be widened into one memset over the whole range.

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare void @llvm.memset.p1.i256(ptr addrspace(1), i8, i256, i1)

; A byte store loop into heap memory: the store-to-memset candidate.
define void @heap_zero(ptr addrspace(1) %p, i256 %n) {
; CHECK-LABEL: @heap_zero(
; CHECK-NOT:     llvm.memset
; CHECK:       loop:
; CHECK:         store i8 0, ptr addrspace(1) %{{.*}}, align 1
; CHECK-NOT:     llvm.memset
entry:
  br label %loop

loop:
  %i = phi i256 [ 0, %entry ], [ %inc, %loop ]
  %a = getelementptr inbounds i8, ptr addrspace(1) %p, i256 %i
  store i8 0, ptr addrspace(1) %a, align 1
  %inc = add nuw i256 %i, 1
  %c = icmp eq i256 %inc, %n
  br i1 %c, label %exit, label %loop

exit:
  ret void
}

; A slot store loop into storage: a memset here would be malformed, since
; storage is not byte addressable.
define void @storage_zero(ptr addrspace(5) %p, i256 %n) {
; CHECK-LABEL: @storage_zero(
; CHECK-NOT:     llvm.memset
; CHECK:       loop:
; CHECK:         store i256 0, ptr addrspace(5) %{{.*}}, align 1
; CHECK-NOT:     llvm.memset
entry:
  br label %loop

loop:
  %i = phi i256 [ 0, %entry ], [ %inc, %loop ]
  %a = getelementptr inbounds i256, ptr addrspace(5) %p, i256 %i
  store i256 0, ptr addrspace(5) %a, align 1
  %inc = add nuw i256 %i, 1
  %c = icmp eq i256 %inc, %n
  br i1 %c, label %exit, label %loop

exit:
  ret void
}

; A memset inside a loop: the memset widening candidate. It must stay in the
; loop with its original 32 byte length.
define void @widen_memset(ptr addrspace(1) %p, i256 %n) {
; CHECK-LABEL: @widen_memset(
; CHECK-NOT:     llvm.memset
; CHECK:       loop:
; CHECK:         call void @llvm.memset.p1.i256(ptr addrspace(1) %{{.*}}, i8 0, i256 32, i1 false)
; CHECK-NOT:     llvm.memset
entry:
  br label %loop

loop:
  %i = phi i256 [ 0, %entry ], [ %inc, %loop ]
  %a = getelementptr inbounds i256, ptr addrspace(1) %p, i256 %i
  call void @llvm.memset.p1.i256(ptr addrspace(1) %a, i8 0, i256 32, i1 false)
  %inc = add nuw i256 %i, 1
  %c = icmp eq i256 %inc, %n
  br i1 %c, label %exit, label %loop

exit:
  ret void
}
