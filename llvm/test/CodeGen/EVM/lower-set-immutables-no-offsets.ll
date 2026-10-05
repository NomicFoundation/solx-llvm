; RUN: opt -passes=evm-lower-set-immutables -S < %s | FileCheck %s

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare void @llvm.evm.setimmutable(i256, i256, metadata)

; Without the evm.immutables metadata, every setimmutable is erased.

; CHECK-NOT:   @llvm.evm.setimmutable
; CHECK-LABEL: define void @deploy(
; CHECK-NEXT:    ret void
; CHECK-NOT:   @llvm.evm.setimmutable

define void @deploy(i256 %addr, i256 %x) {
  call void @llvm.evm.setimmutable(i256 %addr, i256 %x, metadata !0)
  ret void
}

!0 = !{!"40"}
