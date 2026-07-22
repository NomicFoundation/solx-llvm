; RUN: opt -passes=aa-eval -aa-pipeline=evm-aa,basic-aa -print-all-alias-modref-info -disable-output < %s 2>&1 | FileCheck %s

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare i256 @llvm.evm.call(i256, i256, i256, ptr addrspace(1), i256, ptr addrspace(1), i256)
declare i256 @llvm.evm.callcode(i256, i256, i256, ptr addrspace(1), i256, ptr addrspace(1), i256)
declare i256 @llvm.evm.delegatecall(i256, i256, ptr addrspace(1), i256, ptr addrspace(1), i256)
declare i256 @llvm.evm.staticcall(i256, i256, ptr addrspace(1), i256, ptr addrspace(1), i256)
declare i256 @llvm.evm.create(i256, ptr addrspace(1), i256)
declare i256 @llvm.evm.create2(i256, ptr addrspace(1), i256, i256)
declare void @llvm.evm.return(ptr addrspace(1), i256)
declare void @llvm.evm.revert(ptr addrspace(1), i256)

; CHECK-LABEL: Function: rd_call
; CHECK: Just Mod: Ptr: i256* %rd <-> {{.*}}@llvm.evm.call
define void @rd_call(ptr addrspace(1) %io) {
  %rd = inttoptr i256 0 to ptr addrspace(3)
  %v = load i256, ptr addrspace(3) %rd, align 1
  %r = call i256 @llvm.evm.call(i256 0, i256 0, i256 0, ptr addrspace(1) %io, i256 0, ptr addrspace(1) %io, i256 0)
  ret void
}

; CHECK-LABEL: Function: rd_callcode
; CHECK: Just Mod: Ptr: i256* %rd <-> {{.*}}@llvm.evm.callcode
define void @rd_callcode(ptr addrspace(1) %io) {
  %rd = inttoptr i256 0 to ptr addrspace(3)
  %v = load i256, ptr addrspace(3) %rd, align 1
  %r = call i256 @llvm.evm.callcode(i256 0, i256 0, i256 0, ptr addrspace(1) %io, i256 0, ptr addrspace(1) %io, i256 0)
  ret void
}

; CHECK-LABEL: Function: rd_delegatecall
; CHECK: Just Mod: Ptr: i256* %rd <-> {{.*}}@llvm.evm.delegatecall
define void @rd_delegatecall(ptr addrspace(1) %io) {
  %rd = inttoptr i256 0 to ptr addrspace(3)
  %v = load i256, ptr addrspace(3) %rd, align 1
  %r = call i256 @llvm.evm.delegatecall(i256 0, i256 0, ptr addrspace(1) %io, i256 0, ptr addrspace(1) %io, i256 0)
  ret void
}

; CHECK-LABEL: Function: rd_staticcall
; CHECK: Just Mod: Ptr: i256* %rd <-> {{.*}}@llvm.evm.staticcall
define void @rd_staticcall(ptr addrspace(1) %io) {
  %rd = inttoptr i256 0 to ptr addrspace(3)
  %v = load i256, ptr addrspace(3) %rd, align 1
  %r = call i256 @llvm.evm.staticcall(i256 0, i256 0, ptr addrspace(1) %io, i256 0, ptr addrspace(1) %io, i256 0)
  ret void
}

; CHECK-LABEL: Function: rd_create
; CHECK: Just Mod: Ptr: i256* %rd <-> {{.*}}@llvm.evm.create
define void @rd_create(ptr addrspace(1) %io) {
  %rd = inttoptr i256 0 to ptr addrspace(3)
  %v = load i256, ptr addrspace(3) %rd, align 1
  %r = call i256 @llvm.evm.create(i256 0, ptr addrspace(1) %io, i256 0)
  ret void
}

; CHECK-LABEL: Function: rd_create2
; CHECK: Just Mod: Ptr: i256* %rd <-> {{.*}}@llvm.evm.create2
define void @rd_create2(ptr addrspace(1) %io) {
  %rd = inttoptr i256 0 to ptr addrspace(3)
  %v = load i256, ptr addrspace(3) %rd, align 1
  %r = call i256 @llvm.evm.create2(i256 0, ptr addrspace(1) %io, i256 0, i256 0)
  ret void
}

; RETURN/REVERT do not touch the return-data buffer of the current frame.
; CHECK-LABEL: Function: rd_return
; CHECK: NoModRef: Ptr: i256* %rd <-> {{.*}}@llvm.evm.return
define void @rd_return(ptr addrspace(1) %io) {
  %rd = inttoptr i256 0 to ptr addrspace(3)
  %v = load i256, ptr addrspace(3) %rd, align 1
  call void @llvm.evm.return(ptr addrspace(1) %io, i256 0)
  ret void
}

; CHECK-LABEL: Function: rd_revert
; CHECK: NoModRef: Ptr: i256* %rd <-> {{.*}}@llvm.evm.revert
define void @rd_revert(ptr addrspace(1) %io) {
  %rd = inttoptr i256 0 to ptr addrspace(3)
  %v = load i256, ptr addrspace(3) %rd, align 1
  call void @llvm.evm.revert(ptr addrspace(1) %io, i256 0)
  ret void
}
