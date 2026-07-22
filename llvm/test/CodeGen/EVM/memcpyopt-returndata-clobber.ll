; RUN: opt -passes=memcpyopt -aa-pipeline=evm-aa,basic-aa -S < %s | FileCheck %s

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare i256 @llvm.evm.call(i256, i256, i256, ptr addrspace(1), i256, ptr addrspace(1), i256)
declare i256 @llvm.evm.create2(i256, ptr addrspace(1), i256, i256)
declare void @llvm.memcpy.p1.p3.i256(ptr addrspace(1) noalias nocapture writeonly, ptr addrspace(3) noalias nocapture readonly, i256, i1 immarg)
declare void @llvm.memmove.p1.p1.i256(ptr addrspace(1) nocapture writeonly, ptr addrspace(1) nocapture readonly, i256, i1 immarg)
declare void @llvm.evm.return(ptr addrspace(1), i256)

; CHECK-LABEL: define void @__entry(
define void @__entry() {
  store i256 7749745057451750595669064617574929164710845881182427304103965511459427844096, ptr addrspace(1) inttoptr (i256 384 to ptr addrspace(1)), align 1

  ; Identity precompile call, return data now holds the 18 input bytes.
  ; CHECK: call i256 @llvm.evm.call
  %call = call i256 @llvm.evm.call(i256 100000, i256 4, i256 0, ptr addrspace(1) inttoptr (i256 384 to ptr addrspace(1)), i256 18, ptr addrspace(1) null, i256 0)

  ; returndatacopy(0x200, 0, 18): save the return data on the heap.
  ; CHECK: call void @llvm.memcpy.p1.p3.i256(ptr addrspace(1) {{[^,]*}}inttoptr (i256 512 to ptr addrspace(1)), ptr addrspace(3)
  call void @llvm.memcpy.p1.p3.i256(ptr addrspace(1) inttoptr (i256 512 to ptr addrspace(1)), ptr addrspace(3) null, i256 18, i1 false)

  store i256 43424463212337075766385468487936805306171777458530118583296749989969950408704, ptr addrspace(1) inttoptr (i256 768 to ptr addrspace(1)), align 1

  ; CREATE2 clobbers the return-data buffer.
  ; CHECK: call i256 @llvm.evm.create2
  %create2 = call i256 @llvm.evm.create2(i256 0, ptr addrspace(1) inttoptr (i256 768 to ptr addrspace(1)), i256 13, i256 0)

  ; mcopy(0x101, 0x200, 7): must read the SAVED heap bytes at 512, not return data.
  ; CHECK: call void @llvm.mem{{(cpy|move)}}.p1.p1.i256(ptr addrspace(1) {{[^,]*}}inttoptr (i256 257 to ptr addrspace(1)), ptr addrspace(1) {{[^,]*}}inttoptr (i256 512 to ptr addrspace(1)),
  ; CHECK-NOT: call void @llvm.memcpy.p1.p3.i256(ptr addrspace(1) {{[^,]*}}inttoptr (i256 257 to ptr addrspace(1))
  call void @llvm.memmove.p1.p1.i256(ptr addrspace(1) inttoptr (i256 257 to ptr addrspace(1)), ptr addrspace(1) inttoptr (i256 512 to ptr addrspace(1)), i256 7, i1 false)

  ; CHECK: call void @llvm.evm.return
  call void @llvm.evm.return(ptr addrspace(1) inttoptr (i256 257 to ptr addrspace(1)), i256 7)
  ret void
}
