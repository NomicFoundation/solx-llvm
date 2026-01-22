//===- EmitToMemoryBufferWithDbg.cpp --------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm-c/Core.h"
#include "llvm-c/IRReader.h"
#include "llvm-c/Target.h"
#include "llvm-c/TargetMachine.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Object/ObjectFile.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/raw_ostream.h"
#include "gtest/gtest.h"

using namespace llvm;

namespace {

class EmitToMemoryBufferWithDbgTest : public testing::Test {
public:
  static const char *IRStringWithDbg;
  static const char *IRStringWithoutDbg;
  LLVMTargetMachineRef TM = nullptr;
  LLVMContextRef Ctx = nullptr;
  LLVMModuleRef M = nullptr;
  LLVMMemoryBufferRef OutBuf = nullptr;
  LLVMMemoryBufferRef DbgBuf = nullptr;

  void createModuleAndCompile(StringRef IR, LLVMCodeGenFileType codegen) {
    LLVMMemoryBufferRef Buf = LLVMCreateMemoryBufferWithMemoryRange(
        IR.data(), IR.size(), "test", true);

    char *ErrMsg = nullptr;
    if (LLVMParseIRInContext(Ctx, Buf, &M, &ErrMsg))
      report_fatal_error("Failed to parse IR: " + StringRef(ErrMsg));

    if (LLVMTargetMachineEmitToMemoryBufferWithDbg(TM, M, codegen, &ErrMsg,
                                                   &OutBuf, &DbgBuf))
      report_fatal_error("EmitToMemoryBufferWithDbg failed: " +
                         StringRef(ErrMsg));
  }

  static void SetUpTestSuite() {
    LLVMInitializeEVMTargetInfo();
    LLVMInitializeEVMTarget();
    LLVMInitializeEVMTargetMC();
    LLVMInitializeEVMAsmPrinter();
  }

  void SetUp() override {
    LLVMTargetRef T = nullptr;
    char *ErrMsg = nullptr;
    if (LLVMGetTargetFromTriple("evm", &T, &ErrMsg))
      report_fatal_error("Failed to get target for triple 'evm': " +
                         StringRef(ErrMsg));

    TM = LLVMCreateTargetMachine(T, "evm",
                                 /*CPU=*/"",
                                 /*Features=*/"", LLVMCodeGenLevelDefault,
                                 LLVMRelocDefault, LLVMCodeModelDefault);
    if (!TM)
      report_fatal_error("Failed to create TargetMachine for EVM target");
    Ctx = LLVMContextCreate();
  }

  void TearDown() override {
    LLVMDisposeMemoryBuffer(OutBuf);
    LLVMDisposeMemoryBuffer(DbgBuf);
    LLVMDisposeModule(M);
    LLVMContextDispose(Ctx);
    LLVMDisposeTargetMachine(TM);
  }
};

const char *EmitToMemoryBufferWithDbgTest::IRStringWithDbg = R"IR(
target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

define i256 @foo(i256 %0, i256 %1) !dbg !4 {
  %add1 = add nsw i256 %0, 5, !dbg !7
  %add2 = add nsw i256 %1, 3, !dbg !8
  %mul = mul nsw i256 %add2, %add1, !dbg !9
  %add3 = add nsw i256 %add2, %add1, !dbg !10
  %add4 = add nsw i256 %add3, %mul, !dbg !11
  ret i256 %add4, !dbg !12
}

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3}

!0 = distinct !DICompileUnit(language: DW_LANG_Assembly, file: !1, isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false)
!1 = !DIFile(filename: "Test.sol", directory: "/tmp")
!2 = !{i32 7, !"Dwarf Version", i32 5}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = distinct !DISubprogram(name: "foo", scope: !1, file: !1, line: 1, type: !5, scopeLine: 1, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!5 = !DISubroutineType(types: !6)
!6 = !{}
!7 = !DILocation(line: 2, column: 7, scope: !4)
!8 = !DILocation(line: 3, column: 7, scope: !4)
!9 = !DILocation(line: 4, column: 17, scope: !4)
!10 = !DILocation(line: 5, column: 17, scope: !4)
!11 = !DILocation(line: 6, column: 16, scope: !4)
!12 = !DILocation(line: 6, column: 5, scope: !4)
)IR";

const char *EmitToMemoryBufferWithDbgTest::IRStringWithoutDbg = R"IR(
target datalayout = "E-p:256:256-i256:256:256-S256-a:256:256"
target triple = "evm"

define i256 @foo(i256 %0, i256 %1) {
  %add1 = add nsw i256 %0, 5
  %add2 = add nsw i256 %1, 3
  %mul = mul nsw i256 %add2, %add1
  %add3 = add nsw i256 %add2, %add1
  %add4 = add nsw i256 %add3, %mul
  ret i256 %add4
}
)IR";

bool objHasDbgSection(LLVMMemoryBufferRef B) {
  StringRef ObjBytes(LLVMGetBufferStart(B), LLVMGetBufferSize(B));
  auto Obj =
      object::ObjectFile::createObjectFile(MemoryBufferRef(ObjBytes, "dbg"));
  if (!Obj)
    report_fatal_error("Failed to parse object file from debug buffer");

  for (const auto &S : (*Obj)->sections()) {
    Expected<StringRef> Name = S.getName();
    if (Name && Name->contains(".debug"))
      return true;
  }
  return false;
}

TEST_F(EmitToMemoryBufferWithDbgTest, ObjWithDbg) {
  createModuleAndCompile(IRStringWithDbg, LLVMObjectFile);

  EXPECT_TRUE(LLVMGetBufferSize(OutBuf) > 0) << "Output buffer is empty";
  EXPECT_TRUE(LLVMGetBufferSize(DbgBuf) > 0) << "Debug output buffer is empty";
  EXPECT_FALSE(objHasDbgSection(OutBuf))
      << "Output buffer unexpectedly contained .debug sections";
  EXPECT_TRUE(objHasDbgSection(DbgBuf))
      << "Debug buffer did not appear to contain any .debug sections";
}

TEST_F(EmitToMemoryBufferWithDbgTest, ObjWithoutDbg) {
  createModuleAndCompile(IRStringWithoutDbg, LLVMObjectFile);

  EXPECT_TRUE(LLVMGetBufferSize(OutBuf) > 0) << "Output buffer is empty";
  EXPECT_TRUE(LLVMGetBufferSize(DbgBuf) > 0) << "Debug output buffer is empty";
  EXPECT_FALSE(objHasDbgSection(OutBuf))
      << "Output buffer unexpectedly contained .debug sections";
  EXPECT_FALSE(objHasDbgSection(DbgBuf))
      << "Debug buffer unexpectedly contained .debug sections";
}

TEST_F(EmitToMemoryBufferWithDbgTest, Asm) {
  createModuleAndCompile(IRStringWithDbg, LLVMAssemblyFile);

  EXPECT_TRUE(LLVMGetBufferSize(OutBuf) > 0) << "Output buffer is empty";
  EXPECT_FALSE(LLVMGetBufferSize(DbgBuf) > 0)
      << "Debug output buffer is not empty";
}

} // anonymous namespace
