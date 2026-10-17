// RUN: mlir-translate --mlir-to-llvmir %s | FileCheck %s

// CHECK-LABEL: define void @__entry()
// CHECK-SAME:    !dbg ![[$ENTRY:[0-9]+]]
// CHECK-NEXT:    load i256, ptr addrspace(2) null, align 1, !dbg ![[$ENTRY_LOC:[0-9]+]]
// CHECK-NEXT:    call i256 @f(i256 %{{[0-9]+}}), !dbg ![[$ENTRY_LOC]]
// CHECK-NEXT:    call void @llvm.evm.return(ptr addrspace(1) null, i256 %{{[0-9]+}}), !dbg ![[$ENTRY_LOC]]
// CHECK-NEXT:    unreachable, !dbg ![[$ENTRY_LOC]]

// CHECK-LABEL: define private i256 @f(i256 %0)
// CHECK-SAME:    !dbg ![[$F:[0-9]+]]
// CHECK-NEXT:    %[[CMP:[0-9]+]] = icmp ugt i256 %0, 3, !dbg ![[$CMP_LOC:[0-9]+]]
// CHECK-NEXT:    zext i1 %[[CMP]] to i256, !dbg ![[$CMP_LOC]]
// CHECK-NEXT:    br i1 %[[CMP]], label %[[THEN:[0-9]+]], label %[[ELSE:[0-9]+]], !dbg ![[$IF_LOC:[0-9]+]]
// CHECK:       [[ELSE]]:
// CHECK-NEXT:    br label %[[CONT:[0-9]+]], !dbg ![[$ELSE_LOC:[0-9]+]]
// CHECK:       [[THEN]]:
// CHECK-NEXT:    %[[MUL:[0-9]+]] = mul i256 %0, 2, !dbg ![[$THEN_LOC:[0-9]+]]
// CHECK-NEXT:    br label %[[CONT]], !dbg ![[$THEN_LOC]]
// CHECK:       [[CONT]]:
// CHECK-NEXT:    %[[PHI:[0-9]+]] = phi i256 [ 2, %[[ELSE]] ], [ %[[MUL]], %[[THEN]] ], !dbg ![[$IF_LOC]]
// CHECK-NEXT:    ret i256 %[[PHI]], !dbg ![[$RET_LOC:[0-9]+]]

// CHECK-DAG: !llvm.dbg.cu = !{![[CU:[0-9]+]]}
// CHECK-DAG: ![[CU]] = distinct !DICompileUnit(language: DW_LANG_Assembly, file: ![[FILE:[0-9]+]], isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug)
// CHECK-DAG: ![[FILE]] = !DIFile(filename: "a.sol", directory: "")
// CHECK-DAG: ![[$ENTRY]] = distinct !DISubprogram(name: "__entry", linkageName: "__entry", scope: ![[FILE]], file: ![[FILE]], line: 1, type: !{{[0-9]+}}, scopeLine: 1, flags: DIFlagArtificial, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: ![[CU]])
// CHECK-DAG: ![[$ENTRY_LOC]] = !DILocation(line: 1, column: 1, scope: ![[$ENTRY]])
// CHECK-DAG: ![[$F]] = distinct !DISubprogram(name: "f", linkageName: "f", scope: ![[FILE]], file: ![[FILE]], line: 2, type: !{{[0-9]+}}, scopeLine: 2, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: ![[CU]])
// CHECK-DAG: ![[$CMP_LOC]] = !DILocation(line: 3, column: 9, scope: ![[$F]])
// CHECK-DAG: ![[$IF_LOC]] = !DILocation(line: 3, column: 5, scope: ![[$F]])
// CHECK-DAG: ![[$ELSE_LOC]] = !DILocation(line: 3, column: 28, scope: ![[$F]])
// CHECK-DAG: ![[$THEN_LOC]] = !DILocation(line: 3, column: 20, scope: ![[$F]])
// CHECK-DAG: ![[$RET_LOC]] = !DILocation(line: 4, column: 3, scope: ![[$F]])

// A function's subprogram is the one fused onto its location; its ops carry
// their own locations, the lowering's instructions those of the op they come
// from, and the phis of a region op's results its location.
#di_file = #llvm.di_file<"a.sol" in "">
#di_subroutine_type = #llvm.di_subroutine_type<>
#di_compile_unit = #llvm.di_compile_unit<id = distinct[0]<>, sourceLanguage = DW_LANG_Assembly, file = #di_file, producer = "", isOptimized = true, emissionKind = Full>
#di_subprogram = #llvm.di_subprogram<id = distinct[1]<>, compileUnit = #di_compile_unit, scope = #di_file, name = "__entry", linkageName = "__entry", file = #di_file, line = 1, scopeLine = 1, subprogramFlags = "LocalToUnit|Definition", type = #di_subroutine_type, flags = Artificial>
#di_subprogram1 = #llvm.di_subprogram<id = distinct[2]<>, compileUnit = #di_compile_unit, scope = #di_file, name = "f", linkageName = "f", file = #di_file, line = 2, scopeLine = 2, subprogramFlags = "LocalToUnit|Definition", type = #di_subroutine_type>
#loc = loc("a.sol":1:1)
#loc2 = loc("a.sol":2:3)
#loc3 = loc("a.sol":3:9)
#loc4 = loc("a.sol":3:5)
#loc5 = loc("a.sol":3:20)
#loc6 = loc("a.sol":3:28)
#loc7 = loc("a.sol":4:3)
#loc11 = loc(fused<#di_compile_unit>[#loc])
#loc12 = loc(fused<#di_subprogram>[#loc])
#loc13 = loc(fused<#di_subprogram1>[#loc2])
module {
  llvm.module_flags [#llvm.mlir.module_flag<warning, "Dwarf Version", 5 : i32>] loc(#loc11)
  yul.object @Test {
    yul.func @__entry : () -> () {
      %c0 = yul.constant 0 loc(#loc)
      %0 = yul.calldataload %c0 loc(#loc)
      %1 = yul.func_call @f(%0) : (i256) -> i256 loc(#loc)
      yul.return %c0, %1 loc(#loc)
      yul.func_return loc(#loc)
    } loc(#loc12)
    yul.func @f : (i256) -> i256 {
    ^bb0(%x: i256 loc("a.sol":2:14)):
      %c2 = yul.constant 2 loc(unknown)
      %c3 = yul.constant 3 loc(unknown)
      %0 = yul.cmp ugt, %x, %c3 loc(#loc3)
      %1 = yul.if %0 -> i256 {
        %2 = yul.mul %x, %c2 loc(#loc5)
        yul.yield %2 : i256 loc(#loc5)
      } else {
        yul.yield %c2 : i256 loc(#loc6)
      } loc(#loc4)
      yul.func_return %1 : i256 loc(#loc7)
    } loc(#loc13)
  } loc(#loc)
} loc(#loc11)
