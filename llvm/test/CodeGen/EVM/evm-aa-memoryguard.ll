; RUN: opt -mtriple=evm -passes=gvn -aa-pipeline=evm-aa,basic-aa -S < %s | FileCheck %s
; RUN: opt -mtriple=evm -passes=instcombine -S < %s | FileCheck --check-prefix=KNOWNBITS %s

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare i256 @llvm.evm.memoryguard(i256)

; A store through the guard-derived pointer cannot clobber the free memory
; pointer slot (64): the guard value is at least its argument (128). The load
; of slot 64 is forwarded from the store above it.
define i256 @forward_free_ptr(i256 %v) {
; CHECK-LABEL: @forward_free_ptr
; CHECK-NOT: load
; CHECK: ret i256 %guard
  %guard = call i256 @llvm.evm.memoryguard(i256 128)
  store i256 %guard, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1)), align 64
  %p = inttoptr i256 %guard to ptr addrspace(1)
  store i256 %v, ptr addrspace(1) %p, align 1
  %fmp = load i256, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1)), align 64
  ret i256 %fmp
}

; The same holds for positive offsets from the guard.
define i256 @forward_free_ptr_offset(i256 %v) {
; CHECK-LABEL: @forward_free_ptr_offset
; CHECK-NOT: load
; CHECK: ret i256 %guard
  %guard = call i256 @llvm.evm.memoryguard(i256 128)
  store i256 %guard, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1)), align 64
  %addr = add i256 %guard, 32
  %p = inttoptr i256 %addr to ptr addrspace(1)
  store i256 %v, ptr addrspace(1) %p, align 1
  %fmp = load i256, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1)), align 64
  ret i256 %fmp
}

; A 32-byte access at address 96 extends exactly up to the guard bound (128)
; and is still disjoint from guard-derived memory.
define i256 @forward_zero_slot(i256 %v) {
; CHECK-LABEL: @forward_zero_slot
; CHECK-NOT: load
; CHECK: ret i256 0
  %guard = call i256 @llvm.evm.memoryguard(i256 128)
  store i256 0, ptr addrspace(1) inttoptr (i256 96 to ptr addrspace(1)), align 32
  %p = inttoptr i256 %guard to ptr addrspace(1)
  store i256 %v, ptr addrspace(1) %p, align 1
  %zero = load i256, ptr addrspace(1) inttoptr (i256 96 to ptr addrspace(1)), align 32
  ret i256 %zero
}

; Negative test: a constant access overlapping the guard bound (112 + 32 > 128)
; may alias guard-derived memory, so the load must stay.
define i256 @no_forward_overlapping(i256 %v) {
; CHECK-LABEL: @no_forward_overlapping
; CHECK: load i256
  %guard = call i256 @llvm.evm.memoryguard(i256 128)
  store i256 0, ptr addrspace(1) inttoptr (i256 112 to ptr addrspace(1)), align 16
  %p = inttoptr i256 %guard to ptr addrspace(1)
  store i256 %v, ptr addrspace(1) %p, align 1
  %r = load i256, ptr addrspace(1) inttoptr (i256 112 to ptr addrspace(1)), align 16
  ret i256 %r
}

; Negative test: a negative offset from the guard may address memory below
; the guard bound, so the load must stay.
define i256 @no_forward_negative_offset(i256 %v) {
; CHECK-LABEL: @no_forward_negative_offset
; CHECK: load i256
  %guard = call i256 @llvm.evm.memoryguard(i256 128)
  store i256 %guard, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1)), align 64
  %addr = sub i256 %guard, 96
  %p = inttoptr i256 %addr to ptr addrspace(1)
  store i256 %v, ptr addrspace(1) %p, align 1
  %fmp = load i256, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1)), align 64
  ret i256 %fmp
}

; The guard value is 32-byte aligned: its argument is and the spill area size
; is a multiple of 32.
define i256 @known_low_bits() {
; KNOWNBITS-LABEL: @known_low_bits
; KNOWNBITS: ret i256 0
  %guard = call i256 @llvm.evm.memoryguard(i256 128)
  %low = and i256 %guard, 31
  ret i256 %low
}

; The guard value is computed in 64-bit arithmetic, so the high bits are zero.
define i256 @known_high_bits() {
; KNOWNBITS-LABEL: @known_high_bits
; KNOWNBITS: ret i256 0
  %guard = call i256 @llvm.evm.memoryguard(i256 128)
  %high = lshr i256 %guard, 64
  ret i256 %high
}

; The facts are available through ValueTracking, so multi-use guards fold too.
define i256 @known_bits_multi_use() {
; KNOWNBITS-LABEL: @known_bits_multi_use
; KNOWNBITS: ret i256 0
  %guard = call i256 @llvm.evm.memoryguard(i256 128)
  %low = and i256 %guard, 31
  %high = lshr i256 %guard, 64
  %r = or i256 %low, %high
  ret i256 %r
}

; The guard value range is [C, 2^64): comparisons against the bounds fold.
define i1 @range_lower_bound() {
; KNOWNBITS-LABEL: @range_lower_bound
; KNOWNBITS: ret i1 false
  %guard = call i256 @llvm.evm.memoryguard(i256 128)
  %c = icmp ult i256 %guard, 128
  ret i1 %c
}

define i1 @range_upper_bound() {
; KNOWNBITS-LABEL: @range_upper_bound
; KNOWNBITS: ret i1 true
  %guard = call i256 @llvm.evm.memoryguard(i256 128)
  %c = icmp ult i256 %guard, 18446744073709551616
  ret i1 %c
}

; The guard value is not zero when its argument is not zero.
define i1 @known_non_zero() {
; KNOWNBITS-LABEL: @known_non_zero
; KNOWNBITS: ret i1 false
  %guard = call i256 @llvm.evm.memoryguard(i256 128)
  %c = icmp eq i256 %guard, 0
  ret i1 %c
}
