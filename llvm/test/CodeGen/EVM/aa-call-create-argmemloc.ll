; RUN: opt -passes=aa-eval -aa-pipeline=evm-aa,basic-aa -print-all-alias-modref-info -disable-output < %s 2>&1 | FileCheck %s

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare i256 @llvm.evm.create(i256, ptr addrspace(1), i256)
declare i256 @llvm.evm.create2(i256, ptr addrspace(1), i256, i256)
declare i256 @llvm.evm.call(i256, i256, i256, ptr addrspace(1), i256, ptr addrspace(1), i256)
declare i256 @llvm.evm.callcode(i256, i256, i256, ptr addrspace(1), i256, ptr addrspace(1), i256)
declare i256 @llvm.evm.delegatecall(i256, i256, ptr addrspace(1), i256, ptr addrspace(1), i256)
declare i256 @llvm.evm.staticcall(i256, i256, ptr addrspace(1), i256, ptr addrspace(1), i256)
declare void @llvm.evm.return(ptr addrspace(1), i256)

; CHECK-LABEL: Function: test_return
; CHECK: Just Ref: Ptr: i256* %buf <-> {{.*}}@llvm.evm.return
define void @test_return(ptr addrspace(1) noalias %buf) {
  %v = load i256, ptr addrspace(1) %buf, align 1
  call void @llvm.evm.return(ptr addrspace(1) %buf, i256 32)
  ret void
}

; CHECK-LABEL: Function: test_create
; CHECK: Just Ref: Ptr: i256* %buf <-> {{.*}}@llvm.evm.create
define void @test_create(ptr addrspace(1) noalias %buf) {
  %v = load i256, ptr addrspace(1) %buf, align 1
  %r = call i256 @llvm.evm.create(i256 0, ptr addrspace(1) %buf, i256 32)
  ret void
}

; CHECK-LABEL: Function: test_create2
; CHECK: Just Ref: Ptr: i256* %buf <-> {{.*}}@llvm.evm.create2
define void @test_create2(ptr addrspace(1) noalias %buf) {
  %v = load i256, ptr addrspace(1) %buf, align 1
  %r = call i256 @llvm.evm.create2(i256 0, ptr addrspace(1) %buf, i256 32, i256 0)
  ret void
}

; CHECK-LABEL: Function: test_call
; CHECK-DAG: Just Ref: Ptr: i256* %in <-> {{.*}}@llvm.evm.call
; CHECK-DAG: Just Mod: Ptr: i256* %out <-> {{.*}}@llvm.evm.call
define void @test_call(ptr addrspace(1) noalias %in, ptr addrspace(1) noalias %out) {
  %vi = load i256, ptr addrspace(1) %in, align 1
  %vo = load i256, ptr addrspace(1) %out, align 1
  %r = call i256 @llvm.evm.call(i256 0, i256 0, i256 0, ptr addrspace(1) %in, i256 32, ptr addrspace(1) %out, i256 32)
  ret void
}

; CHECK-LABEL: Function: test_callcode
; CHECK-DAG: Just Ref: Ptr: i256* %in <-> {{.*}}@llvm.evm.callcode
; CHECK-DAG: Just Mod: Ptr: i256* %out <-> {{.*}}@llvm.evm.callcode
define void @test_callcode(ptr addrspace(1) noalias %in, ptr addrspace(1) noalias %out) {
  %vi = load i256, ptr addrspace(1) %in, align 1
  %vo = load i256, ptr addrspace(1) %out, align 1
  %r = call i256 @llvm.evm.callcode(i256 0, i256 0, i256 0, ptr addrspace(1) %in, i256 32, ptr addrspace(1) %out, i256 32)
  ret void
}

; DELEGATECALL / STATICCALL read the input buffer (argument 2) and write the
; output buffer (argument 4).
; CHECK-LABEL: Function: test_delegatecall
; CHECK-DAG: Just Ref: Ptr: i256* %in <-> {{.*}}@llvm.evm.delegatecall
; CHECK-DAG: Just Mod: Ptr: i256* %out <-> {{.*}}@llvm.evm.delegatecall
define void @test_delegatecall(ptr addrspace(1) noalias %in, ptr addrspace(1) noalias %out) {
  %vi = load i256, ptr addrspace(1) %in, align 1
  %vo = load i256, ptr addrspace(1) %out, align 1
  %r = call i256 @llvm.evm.delegatecall(i256 0, i256 0, ptr addrspace(1) %in, i256 32, ptr addrspace(1) %out, i256 32)
  ret void
}

; CHECK-LABEL: Function: test_staticcall
; CHECK-DAG: Just Ref: Ptr: i256* %in <-> {{.*}}@llvm.evm.staticcall
; CHECK-DAG: Just Mod: Ptr: i256* %out <-> {{.*}}@llvm.evm.staticcall
define void @test_staticcall(ptr addrspace(1) noalias %in, ptr addrspace(1) noalias %out) {
  %vi = load i256, ptr addrspace(1) %in, align 1
  %vo = load i256, ptr addrspace(1) %out, align 1
  %r = call i256 @llvm.evm.staticcall(i256 0, i256 0, ptr addrspace(1) %in, i256 32, ptr addrspace(1) %out, i256 32)
  ret void
}
