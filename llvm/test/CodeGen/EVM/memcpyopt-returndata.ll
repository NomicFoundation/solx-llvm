; RUN: opt -passes=memcpyopt -aa-pipeline=evm-aa,basic-aa -S < %s | FileCheck %s

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare void @llvm.memcpy.p1.p3.i256(ptr addrspace(1) noalias nocapture writeonly, ptr addrspace(3) noalias nocapture readonly, i256, i1 immarg)
declare void @llvm.memcpy.p1.p1.i256(ptr addrspace(1) noalias nocapture writeonly, ptr addrspace(1) noalias nocapture readonly, i256, i1 immarg)
declare i256 @llvm.evm.create2(i256, ptr addrspace(1), i256, i256)

; CREATE2 replaces the return-data buffer, so the heap->heap copy of the saved
; bytes must not be forwarded back into a return-data (address space 3) read.
; The checks bind each pointer to its defining constant address so they assert
; the address spaces and sizes rather than exact SSA value names.

; CHECK-LABEL: define void @returndata_then_create2(
; CHECK-DAG:  [[RD:%[^ ]+]] = inttoptr i256 0 to ptr addrspace(3)
; CHECK-DAG:  [[TMP:%[^ ]+]] = inttoptr i256 128 to ptr addrspace(1)
; CHECK-DAG:  [[DST:%[^ ]+]] = inttoptr i256 256 to ptr addrspace(1)
define void @returndata_then_create2() {
  %rd   = inttoptr i256 0   to ptr addrspace(3)
  %tmp  = inttoptr i256 128 to ptr addrspace(1)
  %dst  = inttoptr i256 256 to ptr addrspace(1)
  %code = inttoptr i256 512 to ptr addrspace(1)

  ; Save 32 bytes of return data into the scratch heap buffer.
  ; CHECK: call void @llvm.memcpy.p1.p3.i256(ptr addrspace(1) [[TMP]], ptr addrspace(3) [[RD]], i256 32, i1 false)
  call void @llvm.memcpy.p1.p3.i256(ptr addrspace(1) %tmp, ptr addrspace(3) %rd, i256 32, i1 false)

  ; CREATE2 replaces the return-data buffer.
  ; CHECK: call i256 @llvm.evm.create2
  %r = call i256 @llvm.evm.create2(i256 0, ptr addrspace(1) %code, i256 0, i256 0)

  ; Must stay a heap->heap copy of 32 bytes reading the scratch buffer; it must
  ; NOT be rewritten into a return-data (addrspace 3) read of the destination.
  ; CHECK: call void @llvm.memcpy.p1.p1.i256(ptr addrspace(1) [[DST]], ptr addrspace(1) [[TMP]], i256 32, i1 false)
  ; CHECK-NOT: call void @llvm.memcpy.p1.p3.i256(ptr addrspace(1) [[DST]],
  call void @llvm.memcpy.p1.p1.i256(ptr addrspace(1) %dst, ptr addrspace(1) %tmp, i256 32, i1 false)
  ret void
}
