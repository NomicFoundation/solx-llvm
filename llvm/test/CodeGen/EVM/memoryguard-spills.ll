; RUN: llc -stop-after=evm-backward-propagation-stackification < %s | FileCheck --check-prefix=STACKIFIED %s
; RUN: llc < %s | FileCheck %s

; Generated from a Solidity function that locally computes more values than
; the EVM stack can hold, forcing the stackifier to spill two registers.
; The initial free memory pointer value (256) reaches codegen through the
; @llvm.evm.memoryguard intrinsic.

; Check that the intrinsic survives stackification as rematerialized
; MEMORYGUARD_S instructions and that the spill slots are relocated to the
; guard: slots at 256 (0x100) and 288 (0x120), and MEMORYGUARD is rewritten
; to a PUSH of guard + total stack size: 256 + 64 = 320 (0x140).

; STACKIFIED: MEMORYGUARD_S i256 256
; STACKIFIED: PUSH_FRAME %stack.0
; STACKIFIED: PUSH_FRAME %stack.1

; CHECK-LABEL: __entry:

; The free memory pointer is initialized with the adjusted guard:
; mstore(64, 320 + 256), where 256 is the size of the allocated memory array.
; The addition is constant-folded into a single push by the EVM peephole pass.
; CHECK: PUSH2 0x240
; CHECK-NEXT: PUSH1 0x40
; CHECK-NEXT: MSTORE
; CHECK: CALLDATACOPY

; Spill stores to the region [256, 288].
; CHECK: PUSH2 0x100
; CHECK-NEXT: MSTORE ; Reload Reuse
; CHECK: PUSH2 0x120
; CHECK-NEXT: MSTORE ; Reload Reuse

; Reloads from the same slots.
; CHECK: PUSH2 0x100
; CHECK-NEXT: MLOAD ; Reload Reuse
; CHECK: PUSH2 0x120
; CHECK-NEXT: MLOAD ; Reload Reuse

target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm-unknown-unknown"

; Function Attrs: nofree noreturn nounwind null_pointer_is_valid memory(readwrite, inaccessiblemem: read)
define void @__entry() local_unnamed_addr #0 {
  %1 = tail call i256 @llvm.evm.memoryguard(i256 256)
  %2 = tail call i256 @llvm.evm.calldatasize()
  %3 = icmp ugt i256 %2, 3
  br i1 %3, label %4, label %10

4:                                                ; preds = %0
  %5 = load i256, ptr addrspace(2) null, align 4294967296
  %.mask = and i256 %5, -26959946667150639794667015087019630673637144422540572481103610249216
  %cond = icmp eq i256 %.mask, -15477270140232187826189488257166405124817489414920985166399447707391042256896
  br i1 %cond, label %6, label %10

6:                                                ; preds = %4
  %7 = tail call i256 @llvm.evm.callvalue()
  %.not = icmp ne i256 %7, 0
  %8 = add i256 %2, -4
  %9 = icmp slt i256 %8, 32
  %or.cond = or i1 %.not, %9
  br i1 %or.cond, label %10, label %11

10:                                               ; preds = %6, %4, %0
  tail call void @llvm.evm.revert(ptr addrspace(1) null, i256 0)
  unreachable

11:                                               ; preds = %6
  %12 = load i256, ptr addrspace(2) inttoptr (i256 4 to ptr addrspace(2)), align 4
  %13 = icmp ugt i256 %1, 18446744073709551359
  br i1 %13, label %14, label %15

14:                                               ; preds = %11
  store i256 35408467139433450592217433187231851964531694900788300625387963629091585785856, ptr addrspace(1) null, align 4294967296
  store i256 65, ptr addrspace(1) inttoptr (i256 4 to ptr addrspace(1)), align 4
  tail call void @llvm.evm.revert(ptr addrspace(1) null, i256 36)
  unreachable

15:                                               ; preds = %11
  %16 = add nuw nsw i256 %1, 256
  store i256 %16, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1)), align 64
  %17 = inttoptr i256 %1 to ptr addrspace(1)
  %18 = inttoptr i256 %2 to ptr addrspace(2)
  tail call void @llvm.memcpy.p1.p2.i256(ptr addrspace(1) noundef align 1 dereferenceable(256) %17, ptr addrspace(2) noundef nonnull align 1 dereferenceable(256) %18, i256 256, i1 false)
  %19 = add i256 %12, 1
  %20 = icmp eq i256 %12, -1
  br i1 %20, label %.loopexit, label %21

.loopexit:                                        ; preds = %139, %136, %133, %130, %127, %124, %121, %118, %115, %112, %109, %106, %103, %100, %97, %94, %90, %g_15.exit, %80, %.preheader, %69, %66, %63, %60, %57, %54, %51, %48, %45, %42, %39, %36, %33, %30, %27, %24, %21, %15
  store i256 35408467139433450592217433187231851964531694900788300625387963629091585785856, ptr addrspace(1) null, align 4294967296
  store i256 17, ptr addrspace(1) inttoptr (i256 4 to ptr addrspace(1)), align 4
  tail call void @llvm.evm.revert(ptr addrspace(1) null, i256 36)
  unreachable

21:                                               ; preds = %15
  %22 = add i256 %12, 2
  %23 = icmp eq i256 %12, -2
  br i1 %23, label %.loopexit, label %24

24:                                               ; preds = %21
  %25 = add i256 %22, %19
  %26 = icmp ugt i256 %22, %25
  br i1 %26, label %.loopexit, label %27

27:                                               ; preds = %24
  %28 = add i256 %25, %22
  %29 = icmp ugt i256 %25, %28
  br i1 %29, label %.loopexit, label %30

30:                                               ; preds = %27
  %31 = add i256 %28, %25
  %32 = icmp ugt i256 %28, %31
  br i1 %32, label %.loopexit, label %33

33:                                               ; preds = %30
  %34 = add i256 %31, %28
  %35 = icmp ugt i256 %31, %34
  br i1 %35, label %.loopexit, label %36

36:                                               ; preds = %33
  %37 = add i256 %34, %31
  %38 = icmp ugt i256 %34, %37
  br i1 %38, label %.loopexit, label %39

39:                                               ; preds = %36
  %40 = add i256 %37, %34
  %41 = icmp ugt i256 %37, %40
  br i1 %41, label %.loopexit, label %42

42:                                               ; preds = %39
  %43 = add i256 %40, %37
  %44 = icmp ugt i256 %40, %43
  br i1 %44, label %.loopexit, label %45

45:                                               ; preds = %42
  %46 = add i256 %43, %40
  %47 = icmp ugt i256 %43, %46
  br i1 %47, label %.loopexit, label %48

48:                                               ; preds = %45
  %49 = add i256 %46, %43
  %50 = icmp ugt i256 %46, %49
  br i1 %50, label %.loopexit, label %51

51:                                               ; preds = %48
  %52 = add i256 %49, %46
  %53 = icmp ugt i256 %49, %52
  br i1 %53, label %.loopexit, label %54

54:                                               ; preds = %51
  %55 = add i256 %52, %49
  %56 = icmp ugt i256 %52, %55
  br i1 %56, label %.loopexit, label %57

57:                                               ; preds = %54
  %58 = add i256 %55, %52
  %59 = icmp ugt i256 %55, %58
  br i1 %59, label %.loopexit, label %60

60:                                               ; preds = %57
  %61 = add i256 %58, %55
  %62 = icmp ugt i256 %58, %61
  br i1 %62, label %.loopexit, label %63

63:                                               ; preds = %60
  %64 = add i256 %61, %58
  %65 = icmp ugt i256 %61, %64
  br i1 %65, label %.loopexit, label %66

66:                                               ; preds = %63
  %67 = add i256 %64, %61
  %68 = icmp ugt i256 %64, %67
  br i1 %68, label %.loopexit, label %69

69:                                               ; preds = %66
  %70 = add i256 %67, %64
  %71 = icmp ugt i256 %67, %70
  br i1 %71, label %.loopexit, label %.preheader

.preheader:                                       ; preds = %74, %69
  %.0.i2 = phi i256 [ %78, %74 ], [ 0, %69 ]
  %72 = add i256 %.0.i2, %12
  %73 = icmp ugt i256 %12, %72
  br i1 %73, label %.loopexit, label %74

74:                                               ; preds = %.preheader
  %75 = shl nuw nsw i256 %.0.i2, 5
  %76 = add nuw nsw i256 %75, %1
  %77 = inttoptr i256 %76 to ptr addrspace(1)
  store i256 %72, ptr addrspace(1) %77, align 1
  %78 = add nuw nsw i256 %.0.i2, 1
  %79 = icmp samesign ult i256 %.0.i2, 7
  br i1 %79, label %.preheader, label %80

80:                                               ; preds = %74
  %81 = mul i256 %12, 3
  %82 = icmp ne i256 %12, 0
  %83 = tail call i256 @llvm.evm.div(i256 %81, i256 %12)
  %84 = icmp ne i256 %83, 3
  %85 = and i1 %82, %84
  %86 = icmp eq i256 %12, 38597363079105398474523661669562635951089994888546854679819194669304376546645
  %or.cond4 = or i1 %85, %86
  br i1 %or.cond4, label %.loopexit, label %g_15.exit

g_15.exit:                                        ; preds = %80
  %87 = add i256 %81, 1
  %88 = icmp ugt i256 %19, %25
  %89 = icmp slt i256 %25, 0
  %or.cond5 = or i1 %88, %89
  br i1 %or.cond5, label %.loopexit, label %90

90:                                               ; preds = %g_15.exit
  %91 = shl nuw i256 %25, 1
  %92 = add i256 %91, %28
  %93 = icmp ugt i256 %91, %92
  br i1 %93, label %.loopexit, label %94

94:                                               ; preds = %90
  %95 = add i256 %92, %31
  %96 = icmp ugt i256 %92, %95
  br i1 %96, label %.loopexit, label %97

97:                                               ; preds = %94
  %98 = add i256 %95, %34
  %99 = icmp ugt i256 %95, %98
  br i1 %99, label %.loopexit, label %100

100:                                              ; preds = %97
  %101 = add i256 %98, %37
  %102 = icmp ugt i256 %98, %101
  br i1 %102, label %.loopexit, label %103

103:                                              ; preds = %100
  %104 = add i256 %101, %40
  %105 = icmp ugt i256 %101, %104
  br i1 %105, label %.loopexit, label %106

106:                                              ; preds = %103
  %107 = add i256 %104, %43
  %108 = icmp ugt i256 %104, %107
  br i1 %108, label %.loopexit, label %109

109:                                              ; preds = %106
  %110 = add i256 %107, %46
  %111 = icmp ugt i256 %107, %110
  br i1 %111, label %.loopexit, label %112

112:                                              ; preds = %109
  %113 = add i256 %110, %49
  %114 = icmp ugt i256 %110, %113
  br i1 %114, label %.loopexit, label %115

115:                                              ; preds = %112
  %116 = add i256 %113, %52
  %117 = icmp ugt i256 %113, %116
  br i1 %117, label %.loopexit, label %118

118:                                              ; preds = %115
  %119 = add i256 %116, %55
  %120 = icmp ugt i256 %116, %119
  br i1 %120, label %.loopexit, label %121

121:                                              ; preds = %118
  %122 = add i256 %119, %58
  %123 = icmp ugt i256 %119, %122
  br i1 %123, label %.loopexit, label %124

124:                                              ; preds = %121
  %125 = add i256 %122, %61
  %126 = icmp ugt i256 %122, %125
  br i1 %126, label %.loopexit, label %127

127:                                              ; preds = %124
  %128 = add i256 %125, %64
  %129 = icmp ugt i256 %125, %128
  br i1 %129, label %.loopexit, label %130

130:                                              ; preds = %127
  %131 = add i256 %128, %67
  %132 = icmp ugt i256 %128, %131
  br i1 %132, label %.loopexit, label %133

133:                                              ; preds = %130
  %134 = add i256 %131, %70
  %135 = icmp ugt i256 %131, %134
  br i1 %135, label %.loopexit, label %136

136:                                              ; preds = %133
  %137 = add i256 %134, %87
  %138 = icmp ugt i256 %87, %137
  br i1 %138, label %.loopexit, label %139

139:                                              ; preds = %136
  %140 = load i256, ptr addrspace(1) %17, align 1
  %141 = add i256 %140, %137
  %142 = icmp ugt i256 %140, %141
  br i1 %142, label %.loopexit, label %spillWithHeap_203.exit

spillWithHeap_203.exit:                           ; preds = %139
  store i256 %141, ptr addrspace(1) %17, align 1
  %143 = load i256, ptr addrspace(1) inttoptr (i256 64 to ptr addrspace(1)), align 64
  br label %144

144:                                              ; preds = %144, %spillWithHeap_203.exit
  %145 = phi i256 [ %1, %spillWithHeap_203.exit ], [ %152, %144 ]
  %146 = phi i256 [ %143, %spillWithHeap_203.exit ], [ %151, %144 ]
  %147 = phi i256 [ 0, %spillWithHeap_203.exit ], [ %153, %144 ]
  %148 = inttoptr i256 %145 to ptr addrspace(1)
  %149 = load i256, ptr addrspace(1) %148, align 1
  %150 = inttoptr i256 %146 to ptr addrspace(1)
  store i256 %149, ptr addrspace(1) %150, align 1
  %151 = add i256 %146, 32
  %152 = add i256 %145, 32
  %153 = add nuw nsw i256 %147, 1
  %154 = icmp samesign ult i256 %147, 7
  br i1 %154, label %144, label %155

155:                                              ; preds = %144
  %156 = inttoptr i256 %143 to ptr addrspace(1)
  tail call void @llvm.evm.return(ptr addrspace(1) %156, i256 256)
  unreachable
}

; Function Attrs: nounwind willreturn memory(none)
declare i256 @llvm.evm.memoryguard(i256) #1

; Function Attrs: nounwind willreturn memory(none)
declare i256 @llvm.evm.calldatasize() #1

; Function Attrs: nounwind willreturn memory(none)
declare i256 @llvm.evm.callvalue() #1

; Function Attrs: noreturn nounwind memory(argmem: read)
declare void @llvm.evm.revert(ptr addrspace(1) readonly, i256) #2

; Function Attrs: noreturn nounwind memory(read)
declare void @llvm.evm.return(ptr addrspace(1) readonly, i256) #3

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p1.p2.i256(ptr addrspace(1) noalias writeonly captures(none), ptr addrspace(2) noalias readonly captures(none), i256, i1 immarg) #4

; Function Attrs: nounwind willreturn memory(none)
declare i256 @llvm.evm.div(i256, i256) #1

attributes #0 = { nofree noreturn nounwind null_pointer_is_valid memory(readwrite, inaccessiblemem: read) }
attributes #1 = { nounwind willreturn memory(none) }
attributes #2 = { noreturn nounwind memory(argmem: read) }
attributes #3 = { noreturn nounwind memory(read) }
attributes #4 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
