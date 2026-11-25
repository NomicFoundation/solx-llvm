; RUN: llc < %s | FileCheck %s

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

@zeros = private unnamed_addr addrspace(4) constant [66 x i8] zeroinitializer
@zeros_small = private unnamed_addr addrspace(4) constant [8 x i8] zeroinitializer
@data = private unnamed_addr addrspace(4) constant [5 x i8] c"world"

declare void @llvm.memcpy.p1.p4.i256(ptr addrspace(1) noalias nocapture writeonly, ptr addrspace(4) noalias nocapture readonly, i256, i1 immarg)

define void @test() noreturn {
; CHECK-LABEL: test:
; CHECK:       ; %bb.0:
; CHECK-NEXT:    JUMPDEST
; CHECK-NEXT:    PUSH1 0x42
; CHECK-NEXT:    PUSH4 @code_data_section
; CHECK-NEXT:    PUSH0
; CHECK-NEXT:    CODECOPY
; CHECK-NEXT:    PUSH1 0x8
; CHECK-NEXT:    PUSH4 @code_data_section
; CHECK-NEXT:    PUSH1 0x60
; CHECK-NEXT:    CODECOPY
; CHECK-NEXT:    PUSH1 0x5
; CHECK-NEXT:    PUSH4 @code_data_section+66
; CHECK-NEXT:    PUSH1 0x80
; CHECK-NEXT:    CODECOPY
; CHECK-NEXT:    PUSH1 0xA0
; CHECK-NEXT:    PUSH0
; CHECK-NEXT:    REVERT
; CHECK:         INVALID
; CHECK-LABEL:  code_data_section:
; CHECK-COUNT-16: .byte 0x00, 0x00, 0x00, 0x00
; CHECK-NEXT:    .byte 0x00, 0x00, 0x77, 0x6f
; CHECK-NEXT:    .byte 0x72, 0x6c, 0x64

  call void @llvm.memcpy.p1.p4.i256(ptr addrspace(1) null, ptr addrspace(4) @zeros, i256 66, i1 false)
  %dst2 = inttoptr i256 96 to ptr addrspace(1)
  call void @llvm.memcpy.p1.p4.i256(ptr addrspace(1) %dst2, ptr addrspace(4) @zeros_small, i256 8, i1 false)
  %dst3 = inttoptr i256 128 to ptr addrspace(1)
  call void @llvm.memcpy.p1.p4.i256(ptr addrspace(1) %dst3, ptr addrspace(4) @data, i256 5, i1 false)
  call void @llvm.evm.revert(ptr addrspace(1) null, i256 160)
  unreachable
}
