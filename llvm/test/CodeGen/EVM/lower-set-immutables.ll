; RUN: opt -passes=evm-lower-set-immutables -S < %s | FileCheck %s
; RUN: opt -passes='default<O0>' -S < %s | FileCheck %s
; RUN: not opt -passes=evm-verifier -S < %s 2>&1 | FileCheck --check-prefix=VERIFY %s
; RUN: opt -passes='default<O2>' -debug-pass-manager -disable-output < %s 2>&1 \
; RUN:   | FileCheck --check-prefix=PIPELINE %s

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare void @llvm.evm.setimmutable(i256, i256, metadata)

; An immutable is stored at each offset the runtime loads it from, and one the
; runtime never loads is not stored.

; CHECK-NOT:   @llvm.evm.setimmutable
; CHECK-LABEL: define void @deploy(
; CHECK-SAME:  i256 [[ADDR:%.*]], i256 [[X:%.*]], i256 [[Y:%.*]], i256 [[Z:%.*]])
; CHECK-NEXT:  [[OFFSET1:%.*]] = add i256 [[ADDR]], 85
; CHECK-NEXT:  [[PTR1:%.*]] = inttoptr i256 [[OFFSET1]] to ptr addrspace(1)
; CHECK-NEXT:  store i256 [[X]], ptr addrspace(1) [[PTR1]], align 1
; CHECK-NEXT:  [[OFFSET2:%.*]] = add i256 [[ADDR]], 312
; CHECK-NEXT:  [[PTR2:%.*]] = inttoptr i256 [[OFFSET2]] to ptr addrspace(1)
; CHECK-NEXT:  store i256 [[X]], ptr addrspace(1) [[PTR2]], align 1
; CHECK-NEXT:  [[OFFSET3:%.*]] = add i256 [[ADDR]], 200
; CHECK-NEXT:  [[PTR3:%.*]] = inttoptr i256 [[OFFSET3]] to ptr addrspace(1)
; CHECK-NEXT:  store i256 [[Z]], ptr addrspace(1) [[PTR3]], align 1
; CHECK-NEXT:  ret void
; CHECK-NOT:   @llvm.evm.setimmutable
; CHECK-NOT:   !evm.immutables

; VERIFY: EVM setimmutable must be lowered before codegen, run evm-lower-set-immutables
; VERIFY: LLVM ERROR: Broken module found, compilation aborted!

; The stores are optimized like any other.

; PIPELINE: Running pass: EVMLowerSetImmutablesPass
; PIPELINE: Running pass: InstCombinePass

define void @deploy(i256 %addr, i256 %x, i256 %y, i256 %z) {
  call void @llvm.evm.setimmutable(i256 %addr, i256 %x, metadata !1)
  call void @llvm.evm.setimmutable(i256 %addr, i256 %y, metadata !2)
  call void @llvm.evm.setimmutable(i256 %addr, i256 %z, metadata !4)
  ret void
}

!evm.immutables = !{!0, !3}
!0 = !{!"40", i64 85, i64 312}
!1 = !{!"40"}
!2 = !{!"7"}
!3 = !{!"41", i64 200}
!4 = !{!"41"}
