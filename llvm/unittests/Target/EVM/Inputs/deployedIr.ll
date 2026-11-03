target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"
declare i256 @llvm.evm.linkersymbol(metadata)
declare i256 @llvm.evm.loadimmutable(metadata)

define i256 @foo() {
  %res = call i256 @llvm.evm.linkersymbol(metadata !1)
  %res2 = call i256 @llvm.evm.loadimmutable(metadata !2)
  %res3 = add i256 %res, %res2
  ret i256 %res3
}
!1 = !{!"library_id2"}
!2 = !{!"id"}
!llvm.module.flags = !{!100}
!100 = !{i32 1, !"evm.runtime", i32 1}
