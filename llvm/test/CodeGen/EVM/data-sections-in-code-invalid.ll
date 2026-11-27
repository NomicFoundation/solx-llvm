; RUN: split-file %s %t
; RUN: not --crash llc < %t/nonzero.ll 2>&1 | FileCheck %s --check-prefix=NONZERO
; RUN: not --crash llc < %t/zero.ll 2>&1 | FileCheck %s --check-prefix=ZERO
; RUN: not --crash llc < %t/undef.ll 2>&1 | FileCheck %s --check-prefix=UNDEF

;--- nonzero.ll
target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

; NONZERO: unsupported initializer of the code data section global 'bad'

@bad = private unnamed_addr addrspace(4) constant [2 x i256] [i256 1, i256 2]

define void @test() noreturn {
  call void @llvm.evm.revert(ptr addrspace(1) null, i256 0)
  unreachable
}

;--- zero.ll
target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

; ZERO: unsupported initializer of the code data section global 'bad_zero'

@bad_zero = private unnamed_addr addrspace(4) constant [2 x i256] zeroinitializer

define void @test() noreturn {
  call void @llvm.evm.revert(ptr addrspace(1) null, i256 0)
  unreachable
}

;--- undef.ll
target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

; UNDEF: unsupported initializer of the code data section global 'bad_undef'

@bad_undef = private unnamed_addr addrspace(4) constant [66 x i8] undef

define void @test() noreturn {
  call void @llvm.evm.revert(ptr addrspace(1) null, i256 0)
  unreachable
}
