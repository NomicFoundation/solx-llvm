; RUN: llc -O2 < %s | FileCheck %s

; A jump target's JUMPDEST is in the line-table row of the block's first
; instruction, not in the row of the block laid out before it.

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

declare void @llvm.evm.revert(ptr addrspace(1), i256)

define i256 @foo(i256 %a, i256 %b) !dbg !4 {
; CHECK-LABEL: .BB0_2:
; CHECK-NEXT:    .loc 0 0 7
; CHECK-NEXT:    JUMPDEST
entry:
  %c = icmp ult i256 %a, %b, !dbg !7
  br i1 %c, label %fail, label %ok, !dbg !7

ok:
  %r = add i256 %a, %b, !dbg !8
  ret i256 %r, !dbg !8

fail:
  call void @llvm.evm.revert(ptr addrspace(1) null, i256 0), !dbg !9
  unreachable
}

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3}

!0 = distinct !DICompileUnit(language: DW_LANG_Assembly, file: !1, isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false)
!1 = !DIFile(filename: "Test.sol", directory: "/tmp")
!2 = !{i32 7, !"Dwarf Version", i32 5}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = distinct !DISubprogram(name: "foo", scope: !1, file: !1, line: 1, type: !5, scopeLine: 1, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!5 = !DISubroutineType(types: !6)
!6 = !{}
!7 = !DILocation(line: 2, column: 7, scope: !4)
!8 = !DILocation(line: 3, column: 7, scope: !4)
!9 = !DILocation(line: 5, column: 3, scope: !4)
