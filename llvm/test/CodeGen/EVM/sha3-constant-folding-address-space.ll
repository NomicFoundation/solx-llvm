; RUN: opt -O3 -memssa-check-limit=1 -S < %s | FileCheck %s

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

; Constant stores to storage and transient storage don't define heap memory.
define i256 @sha3_test_storage_store(i256 %x) nounwind {
; CHECK-LABEL: define i256 @sha3_test_storage_store
; CHECK-NEXT:  entry:
; CHECK-NEXT:    store i256 [[X:%.*]], ptr addrspace(1) null, align 4294967296
; CHECK-NEXT:    store i256 7, ptr addrspace(5) null, align 4294967296
; CHECK-NEXT:    store i256 8, ptr addrspace(6) null, align 4294967296
; CHECK-NEXT:    [[HASH:%.*]] = tail call i256 @llvm.evm.sha3(ptr addrspace(1) null, i256 32)
; CHECK-NEXT:    ret i256 [[HASH]]
;
entry:
  store i256 %x, ptr addrspace(1) null, align 1
  store i256 7, ptr addrspace(5) null, align 1
  store i256 8, ptr addrspace(6) null, align 1
  %hash = call i256 @llvm.evm.sha3(ptr addrspace(1) null, i256 32)
  ret i256 %hash
}

; Stores to storage and transient storage don't prevent folding.
define i256 @sha3_test_storage_store_skipped() nounwind {
; CHECK-LABEL: define noundef i256 @sha3_test_storage_store_skipped
; CHECK-NEXT:  entry:
; CHECK-NEXT:    store i256 5, ptr addrspace(1) null, align 4294967296
; CHECK-NEXT:    store i256 7, ptr addrspace(5) null, align 4294967296
; CHECK-NEXT:    store i256 8, ptr addrspace(6) null, align 4294967296
; CHECK-NEXT:    ret i256 1546678032441257452667456735582814959992782782816731922691272282333561699760
;
entry:
  store i256 5, ptr addrspace(1) null, align 1
  store i256 7, ptr addrspace(5) null, align 1
  store i256 8, ptr addrspace(6) null, align 1
  %hash = call i256 @llvm.evm.sha3(ptr addrspace(1) null, i256 32)
  ret i256 %hash
}

declare i256 @llvm.evm.sha3(ptr addrspace(1), i256)
