; RUN: opt -passes=evm-fold-memory-guard -S < %s | FileCheck --check-prefixes=CHECK,NOSPILL %s
; RUN: opt -passes=evm-fold-memory-guard -evm-stack-region-size=32 -S < %s | FileCheck --check-prefixes=CHECK,SPILL %s
; RUN: opt -passes='default<O0>' -S < %s | FileCheck --check-prefixes=CHECK,NOSPILL %s
; RUN: not opt -passes=evm-verifier -S < %s 2>&1 | FileCheck --check-prefix=VERIFY %s

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare i256 @llvm.evm.memoryguard(i256)

; The spill region is placed at the guard, so the free memory pointer is
; initialized past it.

; CHECK-LABEL: define void @init(
; NOSPILL: store i256 128, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1))
; SPILL: store i256 160, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1))
; CHECK-NOT: llvm.evm.memoryguard

; CHECK: !{i32 1, !"evm-memory-guard", i64 128}

; VERIFY: EVM memoryguard must be folded before codegen, run evm-fold-memory-guard
; VERIFY: LLVM ERROR: Broken module found, compilation aborted!

define void @init() {
  %guard = call i256 @llvm.evm.memoryguard(i256 128)
  store i256 %guard, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1))
  ret void
}
