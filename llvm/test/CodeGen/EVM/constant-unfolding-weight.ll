; RUN: llc -O3 < %s | FileCheck %s
target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare void @llvm.evm.revert(ptr addrspace(1), i256)

; The gas of an unfolded constant is weighted by how often the constant runs.
; The 64-bit mask is PUSH8, 9 bytes and 3 gas, or PUSH0 NOT PUSH1 SHR, 5 bytes
; and 11 gas. Outside a loop the gas weighs 0.19 of a byte and the mask unfolds.
; In a loop body it weighs 0.57 and the mask stays. A block that runs less than
; once per call is discounted by its frequency, and the body of a recursive
; function is charged two loop levels.

; CHECK-LABEL: flat:
; CHECK-NOT:     PUSH8
; CHECK:         PUSH0
; CHECK-NEXT:    NOT
; CHECK-NEXT:    PUSH1 0xC0
; CHECK-NEXT:    SHR
; CHECK-NEXT:    AND
define i256 @flat(i256 %x) {
  %m = and i256 %x, 18446744073709551615
  ret i256 %m
}

; The copy materialized before the loop unfolds, the one in the latch stays.
; CHECK-LABEL: loop:
; CHECK:         PUSH0
; CHECK-NEXT:    NOT
; CHECK-NEXT:    PUSH1 0xC0
; CHECK-NEXT:    SHR
; CHECK:         PUSH8 0xFFFFFFFFFFFFFFFF
; CHECK-NOT:     SHR
define i256 @loop(i256 %n, i256 %x) {
entry:
  br label %loop
loop:
  %i = phi i256 [ 0, %entry ], [ %i.next, %loop ]
  %acc = phi i256 [ %x, %entry ], [ %acc.next, %loop ]
  %t = and i256 %acc, 18446744073709551615
  %acc.next = add i256 %t, %i
  %i.next = add i256 %i, 1
  %c = icmp ult i256 %i.next, %n
  br i1 %c, label %loop, label %exit
exit:
  ret i256 %acc.next
}

; The revert block sits in the loop but almost never runs, so its mask unfolds
; while the loop body keeps its own.
; CHECK-LABEL: cold:
; CHECK:         PUSH8 0xFFFFFFFFFFFFFFFF
; CHECK-NOT:     SHR
; CHECK:         PUSH0
; CHECK-NEXT:    NOT
; CHECK-NEXT:    PUSH1 0xC0
; CHECK-NEXT:    SHR
; CHECK-NOT:     PUSH8
; CHECK:         REVERT
define i256 @cold(i256 %n, i256 %x) {
entry:
  br label %loop
loop:
  %i = phi i256 [ 0, %entry ], [ %i.next, %next ]
  %acc = phi i256 [ %x, %entry ], [ %t, %next ]
  %acc.next = add i256 %acc, %i
  %ovf = icmp ult i256 %acc.next, %acc
  br i1 %ovf, label %fail, label %next
fail:
  store i256 18446744073709551615, ptr addrspace(1) null
  call void @llvm.evm.revert(ptr addrspace(1) null, i256 32)
  unreachable
next:
  %t = and i256 %acc.next, 18446744073709551615
  %i.next = add i256 %i, 1
  %c = icmp ult i256 %i.next, %n
  br i1 %c, label %loop, label %exit
exit:
  ret i256 %t
}

; A self-recursive function has no loop, yet its body runs once per level.
; CHECK-LABEL: rec:
; CHECK:         PUSH8 0xFFFFFFFFFFFFFFFF
; CHECK-NOT:     SHR
define i256 @rec(i256 %n) {
entry:
  %m = and i256 %n, 18446744073709551615
  %z = icmp eq i256 %m, 0
  br i1 %z, label %done, label %call
call:
  %d = sub i256 %m, 1
  %r = call i256 @rec(i256 %d)
  %s = add i256 %r, 1
  ret i256 %s
done:
  ret i256 0
}

; Mutual recursion is found through the call graph cycle.
; CHECK-LABEL: even:
; CHECK:         PUSH8 0xFFFFFFFFFFFFFFFF
; CHECK-NOT:     SHR
define i256 @even(i256 %n) {
entry:
  %m = and i256 %n, 18446744073709551615
  %z = icmp eq i256 %m, 0
  br i1 %z, label %done, label %call
call:
  %d = sub i256 %m, 1
  %r = call i256 @odd(i256 %d)
  ret i256 %r
done:
  ret i256 1
}

; CHECK-LABEL: odd:
; CHECK:         PUSH8 0xFFFFFFFFFFFFFFFF
; CHECK-NOT:     SHR
define i256 @odd(i256 %n) {
entry:
  %m = and i256 %n, 18446744073709551615
  %z = icmp eq i256 %m, 0
  br i1 %z, label %done, label %call
call:
  %d = sub i256 %m, 1
  %r = call i256 @even(i256 %d)
  ret i256 %r
done:
  ret i256 0
}
