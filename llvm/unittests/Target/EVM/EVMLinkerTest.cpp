//===---------- llvm/unittests/Target/EVM/EVMLinkerTest.cpp ---------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm-c/EVMLinker.h"
#include "llvm-c/Core.h"
#include "llvm-c/IRReader.h"
#include "llvm-c/TargetMachine.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/Object/ELFObjectFile.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/FileUtilities.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Testing/Support/SupportHelpers.h"
#include "gtest/gtest.h"
#include <array>

using namespace llvm;

extern const char *TestMainArgv0;

static std::string expand(const char *Path) {
  llvm::SmallString<128> ThisPath =
      llvm::unittest::getInputFileDirectory(TestMainArgv0);
  llvm::sys::path::append(ThisPath, Path);
  return ThisPath.str().str();
}

class EVMLinkerTest : public testing::Test {
  void SetUp() override {
    LLVMInitializeEVMTargetInfo();
    LLVMInitializeEVMTarget();
    LLVMInitializeEVMTargetMC();
    LLVMInitializeEVMAsmPrinter();

    LLVMTargetRef Target = 0;
    const char *Triple = "evm";
    char *ErrMsg = 0;
    if (LLVMGetTargetFromTriple(Triple, &Target, &ErrMsg)) {
      FAIL() << "Failed to create target from the triple (" << Triple
             << "): " << ErrMsg;
      return;
    }
    ASSERT_TRUE(Target);

    // Construct a TargetMachine.
    TM =
        LLVMCreateTargetMachine(Target, Triple, "", "", LLVMCodeGenLevelDefault,
                                LLVMRelocDefault, LLVMCodeModelDefault);

    Context = LLVMContextCreate();
  }

  void TearDown() override {
    LLVMDisposeTargetMachine(TM);
    LLVMContextDispose(Context);
  }

public:
  LLVMMemoryBufferRef link(LLVMMemoryBufferRef InAssembly, const char *Name,
                           const char *LinkerSyms[],
                           const char LinkerSymVals[][20], uint64_t NumSyms) {
    return LLVMLinkEVM(InAssembly, LinkerSyms, LinkerSymVals, NumSyms);
  }

  LLVMMemoryBufferRef assemble(const std::vector<LLVMMemoryBufferRef> &Objs,
                               const std::vector<const char *> &IDs,
                               bool WithMD = false) {
    LLVMMemoryBufferRef OutAssembly =
        LLVMAssembleEVM(Objs.data(), IDs.data(), Objs.size(),
                        WithMD ? MD.data() : nullptr, WithMD ? MD.size() : 0);
    EXPECT_TRUE(LLVMIsELFEVM(OutAssembly));
    return OutAssembly;
  }

  LLVMMemoryBufferRef compileIR(const char *FileName) {
    auto Buf = MemoryBuffer::getFile(expand(FileName), /*IsText=*/false,
                                     /*RequiresNullTerminator=*/false);
    if (auto EC = Buf.getError())
      exit(1);

    LLVMMemoryBufferRef IrBuf = llvm::wrap(Buf.get().release());
    char *ErrMsg = nullptr;
    LLVMModuleRef Module;
    if (LLVMParseIRInContext(Context, IrBuf, &Module, &ErrMsg)) {
      LLVMDisposeMessage(ErrMsg);
      exit(1);
    }

    // Run CodeGen to produce the buffers.
    LLVMMemoryBufferRef Result;
    if (LLVMTargetMachineEmitToMemoryBuffer(TM, Module, LLVMObjectFile, &ErrMsg,
                                            &Result)) {
      LLVMDisposeModule(Module);
      LLVMDisposeMessage(ErrMsg);
      exit(1);
    }
    LLVMDisposeModule(Module);
    return Result;
  }

  LLVMTargetMachineRef TM;
  LLVMContextRef Context;
  std::array<char, 32> MD = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                             0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
                             0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
                             0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20};
};

TEST_F(EVMLinkerTest, IterativeLinkage) {
  LLVMMemoryBufferRef DeployObjMemBuffer = compileIR("deployIr.ll");
  LLVMMemoryBufferRef DeployedObjMemBuffer = compileIR("deployedIr.ll");

  EXPECT_TRUE(LLVMIsELFEVM(DeployObjMemBuffer));
  EXPECT_TRUE(LLVMIsELFEVM(DeployedObjMemBuffer));

  const char *LinkerSymbol[2] = {"library_id", "library_id2"};
  const char LinkerSymbolVal[2][20] = {
      {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
      {'\x9f', 0x1E, '\xBB', '\xF1', 7, 7, 7, 7, 7, 7,
       7,      7,    7,      7,      7, 7, 7, 7, 7, 7}};
  StringRef SymVal1(LinkerSymbolVal[0], 20);
  StringRef SymVal2(LinkerSymbolVal[1], 20);

  const char *InIDs[] = {"Test_26", "Test_26_deployed"};
  std::array<LLVMMemoryBufferRef, 2> InData = {DeployObjMemBuffer,
                                               DeployedObjMemBuffer};
  LLVMMemoryBufferRef InMemBuf = nullptr;
  LLVMMemoryBufferRef OutMemBuf = nullptr;

  // Assemble deploy with deployed.
  {
    OutMemBuf = LLVMAssembleEVM(InData.data(), InIDs, 2, nullptr, 0);
    EXPECT_TRUE(LLVMIsELFEVM(OutMemBuf));
    std::swap(OutMemBuf, InMemBuf);
  }

  // Check load immutable references.
  {
    char **ImmutableIDs = nullptr;
    uint64_t *ImmutableOffsets = nullptr;
    uint64_t ImmCount =
        LLVMGetImmutablesEVM(InData[1], &ImmutableIDs, &ImmutableOffsets);
    EXPECT_TRUE(ImmCount == 1);
    EXPECT_TRUE(std::strcmp(ImmutableIDs[0], "id") == 0);
    LLVMDisposeImmutablesEVM(ImmutableIDs, ImmutableOffsets, ImmCount);
  }

  // No linker symbol definitions are provided, so we have to receive ELF
  // object file.
  OutMemBuf = LLVMLinkEVM(InMemBuf, nullptr, nullptr, 0);
  EXPECT_TRUE(LLVMIsELFEVM(OutMemBuf));

  char **UndefLinkerSyms = nullptr;
  uint64_t NumLinkerUndefs = 0;

  LLVMGetUndefinedReferencesEVM(OutMemBuf, &UndefLinkerSyms, &NumLinkerUndefs);

  EXPECT_TRUE(NumLinkerUndefs == 2);
  EXPECT_TRUE((std::strcmp(UndefLinkerSyms[0], LinkerSymbol[0]) == 0));
  EXPECT_TRUE((std::strcmp(UndefLinkerSyms[1], LinkerSymbol[1]) == 0));
  LLVMDisposeUndefinedReferencesEVM(UndefLinkerSyms, NumLinkerUndefs);

  std::swap(OutMemBuf, InMemBuf);
  LLVMDisposeMemoryBuffer(OutMemBuf);

  // The first linker symbol definitions is provided, so we still have
  // to receive an ELF object file
  OutMemBuf = LLVMLinkEVM(InMemBuf, LinkerSymbol, LinkerSymbolVal, 1);
  EXPECT_TRUE(LLVMIsELFEVM(OutMemBuf));

  LLVMGetUndefinedReferencesEVM(OutMemBuf, &UndefLinkerSyms, &NumLinkerUndefs);
  EXPECT_TRUE(NumLinkerUndefs == 1);
  EXPECT_TRUE((std::strcmp(UndefLinkerSyms[0], LinkerSymbol[1]) == 0));
  LLVMDisposeUndefinedReferencesEVM(UndefLinkerSyms, NumLinkerUndefs);

  std::swap(OutMemBuf, InMemBuf);
  LLVMDisposeMemoryBuffer(OutMemBuf);

  // Both linker symbol definitions are provided, so we have to receive
  // a bytecode.
  OutMemBuf = LLVMLinkEVM(InMemBuf, LinkerSymbol, LinkerSymbolVal, 2);
  EXPECT_TRUE(!LLVMIsELFEVM(OutMemBuf));

  LLVMGetUndefinedReferencesEVM(OutMemBuf, &UndefLinkerSyms, &NumLinkerUndefs);
  EXPECT_TRUE(NumLinkerUndefs == 0);
  LLVMDisposeUndefinedReferencesEVM(UndefLinkerSyms, NumLinkerUndefs);

  StringRef DeployBin(LLVMGetBufferStart(OutMemBuf),
                      LLVMGetBufferSize(OutMemBuf));

  EXPECT_TRUE(DeployBin.find(SymVal1) != StringRef::npos);
  EXPECT_TRUE(DeployBin.find(SymVal2) != StringRef::npos);

  LLVMDisposeMemoryBuffer(OutMemBuf);
  LLVMDisposeMemoryBuffer(InMemBuf);
}

TEST_F(EVMLinkerTest, Assembly) {
  const char *LinkerSymbol[2] = {"unused_library_id", "library_id"};
  const char LinkerSymbolVal[2][20] = {
      {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
      {5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9, 9}};

  LLVMMemoryBufferRef A_deploy_obj = compileIR("A_deploy.ll");
  LLVMMemoryBufferRef A_deployed_obj = compileIR("A_deployed.ll");
  LLVMMemoryBufferRef D_deploy_obj = compileIR("D_deploy.ll");
  LLVMMemoryBufferRef D_deployed_obj = compileIR("D_deployed.ll");
  LLVMMemoryBufferRef R_deploy_obj = compileIR("R_deploy.ll");
  LLVMMemoryBufferRef R_deployed_obj = compileIR("R_deployed.ll");

  // A assemble.
  LLVMMemoryBufferRef A_assembly_deployed =
      assemble({A_deployed_obj}, {"A_38_deployed"},
               /*WithMD=*/true);
  LLVMMemoryBufferRef A_assembly =
      assemble({A_deploy_obj, A_assembly_deployed}, {"A_38", "A_38_deployed"});

  // D assemble.
  LLVMMemoryBufferRef D_assembly_deployed =
      assemble({D_deployed_obj}, {"D_38_deployed"},
               /*WithMD=*/true);
  LLVMMemoryBufferRef D_assembly =
      assemble({D_deploy_obj, D_assembly_deployed}, {"D_51", "D_51_deployed"});

  // R_deployed assemble.
  // A_assembly is not required here, but we add it intentionaly to check
  // that it will be ignored (the total number of library reference is 3).
  LLVMMemoryBufferRef R_deployed_assemble =
      assemble({R_deployed_obj, D_assembly, A_assembly, A_assembly_deployed},
               {"R_107_deployed", "D_51", "A_38", "A_38.A_38_deployed"},
               /*WithMD=*/true);

  // R assemble.
  LLVMMemoryBufferRef R_assembly = assemble(
      {R_deploy_obj, R_deployed_assemble, A_assembly, A_assembly_deployed},
      {"R_107", "R_107_deployed", "A_38", "A_38.A_38_deployed"});

  // Get linker symbols offsets
  uint64_t *SymOffsets = nullptr;
  uint64_t NumOffsets =
      LLVMGetSymbolOffsetsEVM(R_assembly, LinkerSymbol[1], &SymOffsets);
  EXPECT_TRUE(NumOffsets == 3);
  LLVMDisposeSymbolOffsetsEVM(SymOffsets);

  // Linking with no linker symbols.
  LLVMMemoryBufferRef TmpAssembly = link(R_assembly, "R", nullptr, nullptr, 0);
  EXPECT_TRUE(LLVMIsELFEVM(TmpAssembly));

  // Linking with unused linker symbol. It has no effect.
  LLVMMemoryBufferRef TmpAssembly2 =
      link(TmpAssembly, "R", LinkerSymbol, LinkerSymbolVal, 1);
  EXPECT_TRUE(LLVMIsELFEVM(TmpAssembly2));

  // Linking with both linker symbols. The library reference should be resolved
  // and resulting object is a final bytecode.
  LLVMMemoryBufferRef Bytecode =
      link(TmpAssembly2, "R", LinkerSymbol, LinkerSymbolVal, 2);
  EXPECT_TRUE(!LLVMIsELFEVM(Bytecode));

  char **UndefLinkerSyms = nullptr;
  uint64_t NumLinkerUndefs = 0;

  LLVMGetUndefinedReferencesEVM(Bytecode, &UndefLinkerSyms, &NumLinkerUndefs);
  EXPECT_TRUE(NumLinkerUndefs == 0);
  LLVMDisposeUndefinedReferencesEVM(UndefLinkerSyms, NumLinkerUndefs);

  StringRef Binary(LLVMGetBufferStart(Bytecode), LLVMGetBufferSize(Bytecode));

  StringRef LibAddr(LinkerSymbolVal[1], 20);
  EXPECT_TRUE(Binary.count(LibAddr) == 3);
  EXPECT_TRUE(Binary.count(StringRef(MD.data(), MD.size())) == 5);

  LLVMDisposeMemoryBuffer(A_deploy_obj);
  LLVMDisposeMemoryBuffer(A_deployed_obj);
  LLVMDisposeMemoryBuffer(D_deploy_obj);
  LLVMDisposeMemoryBuffer(D_deployed_obj);
  LLVMDisposeMemoryBuffer(R_deploy_obj);
  LLVMDisposeMemoryBuffer(R_deployed_obj);
  LLVMDisposeMemoryBuffer(TmpAssembly);
  LLVMDisposeMemoryBuffer(TmpAssembly2);
  LLVMDisposeMemoryBuffer(Bytecode);
}

#if GTEST_HAS_DEATH_TEST
// A '__dataoffset' or '__datasize' of an object the driver did not pass is a
// driver bug, and the linker aborts on it.
TEST_F(EVMLinkerTest, UndefNonRefSymbols) {
  LLVMMemoryBufferRef DeployObj = compileIR("undefDeployIr.ll");
  LLVMMemoryBufferRef DeployedObj = compileIR("undefDeployedIr.ll");

  EXPECT_TRUE(LLVMIsELFEVM(DeployObj));
  EXPECT_TRUE(LLVMIsELFEVM(DeployedObj));

  const std::array<LLVMMemoryBufferRef, 2> InObjs = {DeployObj, DeployedObj};
  const std::array<const char *, 2> IDs = {"Test_26", "Test_26_deployed"};
  EXPECT_DEATH(
      LLVMAssembleEVM(InObjs.data(), IDs.data(), IDs.size(), nullptr, 0),
      "non-ref undefined symbol:");

  LLVMDisposeMemoryBuffer(DeployObj);
  LLVMDisposeMemoryBuffer(DeployedObj);
}
#endif

/// Parses \p Buf as an ELF object and returns a copy of its '.text' contents.
static std::string textSection(LLVMMemoryBufferRef Buf) {
  using namespace llvm::object;
  MemoryBufferRef Ref(
      StringRef(LLVMGetBufferStart(Buf), LLVMGetBufferSize(Buf)), "object");
  std::unique_ptr<Binary> Bin = cantFail(createBinary(Ref));
  const auto *File = cast<ObjectFile>(Bin.get());
  for (const SectionRef &Sec : File->sections()) {
    if (cantFail(Sec.getName()) == ".text")
      return cantFail(Sec.getContents()).str();
  }
  return {};
}

/// Returns the big-endian bytes of \p V.
static std::string be32(uint32_t V) {
  std::string S(4, '\0');
  llvm::support::endian::write32be(S.data(), V);
  return S;
}

// Pins the values the linker writes: the big-endian '__dataoffset' and
// '__datasize' immediates, the bytecode length, the metadata tail and the
// offsets 'LLVMGetSymbolOffsetsEVM' reports.
TEST_F(EVMLinkerTest, RelocationValues) {
  LLVMMemoryBufferRef DeployObj = compileIR("deployIr.ll");
  LLVMMemoryBufferRef DeployedObj = compileIR("deployedIr.ll");
  const std::string DeployText = textSection(DeployObj);
  const std::string DeployedText = textSection(DeployedObj);
  const StringRef Metadata(MD.data(), MD.size());

  // The runtime segment is its code plus the metadata.
  LLVMMemoryBufferRef Runtime =
      assemble({DeployedObj}, {"Test_26_deployed"}, /*WithMD=*/true);
  const std::string RuntimeText = textSection(Runtime);
  EXPECT_EQ(RuntimeText.size(), DeployedText.size() + MD.size());
  EXPECT_EQ(StringRef(RuntimeText).take_back(MD.size()), Metadata);

  // The deploy segment embeds it right after the deploy code.
  LLVMMemoryBufferRef Assembled =
      assemble({DeployObj, Runtime}, {"Test_26", "Test_26_deployed"});
  const std::string AssembledText = textSection(Assembled);
  EXPECT_EQ(AssembledText.size(), DeployText.size() + RuntimeText.size());

  // '__dataoffset' and '__datasize' resolve to the runtime's offset and
  // size, written big-endian into PUSH4 immediates.
  const std::string DataOffset =
      std::string(1, '\x63') + be32(DeployText.size());
  const std::string DataSize =
      std::string(1, '\x63') + be32(RuntimeText.size());
  EXPECT_NE(AssembledText.find(DataOffset), std::string::npos);
  EXPECT_NE(AssembledText.find(DataSize), std::string::npos);

  uint64_t *SymOffsets = nullptr;
  uint64_t NumOffsets =
      LLVMGetSymbolOffsetsEVM(Assembled, "library_id", &SymOffsets);
  ASSERT_EQ(NumOffsets, 2U);
  EXPECT_LT(SymOffsets[0], SymOffsets[1]);

  const char *LinkerSymbol[2] = {"library_id", "library_id2"};
  const char LinkerSymbolVal[2][20] = {
      {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
      {5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9, 9}};
  LLVMMemoryBufferRef Bytecode =
      link(Assembled, "Test_26", LinkerSymbol, LinkerSymbolVal, 2);
  EXPECT_TRUE(!LLVMIsELFEVM(Bytecode));
  const StringRef Bin(LLVMGetBufferStart(Bytecode),
                      LLVMGetBufferSize(Bytecode));

  // The bytecode is exactly the code plus the metadata, nothing after it.
  EXPECT_EQ(Bin.size(), AssembledText.size());
  EXPECT_EQ(Bin.take_back(MD.size()), Metadata);

  // Each reported offset holds the 20 bytes of the library address.
  for (uint64_t Idx = 0; Idx < NumOffsets; ++Idx) {
    ASSERT_LE(SymOffsets[Idx] + 20, Bin.size());
    EXPECT_EQ(Bin.substr(SymOffsets[Idx], 20),
              StringRef(LinkerSymbolVal[0], 20));
  }
  LLVMDisposeSymbolOffsetsEVM(SymOffsets);

  LLVMDisposeMemoryBuffer(DeployObj);
  LLVMDisposeMemoryBuffer(DeployedObj);
  LLVMDisposeMemoryBuffer(Runtime);
  LLVMDisposeMemoryBuffer(Assembled);
  LLVMDisposeMemoryBuffer(Bytecode);
}

// Pins the immutable offsets: they point at the PUSH32 immediate, one byte
// past the opcode, both in the raw object and in the assembled one.
TEST_F(EVMLinkerTest, ImmutableOffsets) {
  LLVMMemoryBufferRef DeployedObj = compileIR("deployedIr.ll");
  const std::string Text = textSection(DeployedObj);

  char **Ids = nullptr;
  uint64_t *Offsets = nullptr;
  uint64_t Count = LLVMGetImmutablesEVM(DeployedObj, &Ids, &Offsets);
  ASSERT_EQ(Count, 1U);
  EXPECT_STREQ(Ids[0], "id");
  ASSERT_GT(Offsets[0], 0U);
  ASSERT_LE(Offsets[0] + 32, Text.size());
  EXPECT_EQ(static_cast<uint8_t>(Text[Offsets[0] - 1]), 0x7F); // PUSH32
  const uint64_t RawOffset = Offsets[0];
  LLVMDisposeImmutablesEVM(Ids, Offsets, Count);

  // The assembled runtime object carries the same immutable symbol.
  LLVMMemoryBufferRef Runtime =
      assemble({DeployedObj}, {"Test_26_deployed"}, /*WithMD=*/true);
  const std::string RuntimeText = textSection(Runtime);
  Count = LLVMGetImmutablesEVM(Runtime, &Ids, &Offsets);
  ASSERT_EQ(Count, 1U);
  EXPECT_STREQ(Ids[0], "id");
  EXPECT_EQ(Offsets[0], RawOffset);
  EXPECT_EQ(static_cast<uint8_t>(RuntimeText[Offsets[0] - 1]), 0x7F);
  LLVMDisposeImmutablesEVM(Ids, Offsets, Count);

  LLVMDisposeMemoryBuffer(DeployedObj);
  LLVMDisposeMemoryBuffer(Runtime);
}

// Pins the layout fields of the object the linker writes: section order, the
// symbol table's locals count and link, the relocation section's shape and
// the aligned offsets.
TEST_F(EVMLinkerTest, AssembledObjectLayout) {
  using namespace llvm::object;
  LLVMMemoryBufferRef DeployObj = compileIR("deployIr.ll");
  LLVMMemoryBufferRef DeployedObj = compileIR("deployedIr.ll");
  LLVMMemoryBufferRef Runtime =
      assemble({DeployedObj}, {"Test_26_deployed"}, /*WithMD=*/true);
  LLVMMemoryBufferRef Assembled =
      assemble({DeployObj, Runtime}, {"Test_26", "Test_26_deployed"});

  MemoryBufferRef Ref(
      StringRef(LLVMGetBufferStart(Assembled), LLVMGetBufferSize(Assembled)),
      "assembled");
  ELFObjectFile<ELF32BE> Obj = cantFail(ELFObjectFile<ELF32BE>::create(Ref));
  const ELFFile<ELF32BE> &EF = Obj.getELFFile();
  EXPECT_EQ(EF.getHeader().e_ehsize, sizeof(ELF::Elf32_Ehdr));
  EXPECT_EQ(EF.getHeader().e_shoff % 4, 0U);
  // The deploy assembly keeps the deploy kind, the runtime one its flag.
  EXPECT_EQ(EF.getHeader().e_flags, 0U);
  MemoryBufferRef RuntimeRef(
      StringRef(LLVMGetBufferStart(Runtime), LLVMGetBufferSize(Runtime)),
      "runtime");
  ELFObjectFile<ELF32BE> RuntimeObj =
      cantFail(ELFObjectFile<ELF32BE>::create(RuntimeRef));
  EXPECT_EQ(RuntimeObj.getELFFile().getHeader().e_flags,
            unsigned(ELF::EF_EVM_RUNTIME));

  const auto Sections = cantFail(EF.sections());
  SmallVector<std::string, 8> Names;
  for (const auto &Sec : Sections)
    Names.push_back(cantFail(EF.getSectionName(Sec)).str());
  ASSERT_EQ(Names.size(), 8U);
  EXPECT_EQ(Names[1], ".text");
  EXPECT_EQ(Names[2], ".rela.text");
  EXPECT_TRUE(StringRef(Names[3]).starts_with(".symbol_name"));
  EXPECT_TRUE(StringRef(Names[4]).starts_with(".symbol_name"));
  EXPECT_EQ(Names[5], ".symtab");
  EXPECT_EQ(Names[6], ".strtab");
  EXPECT_EQ(Names[7], ".shstrtab");

  const auto &Rela = Sections[2];
  EXPECT_EQ(Rela.sh_type, static_cast<uint32_t>(ELF::SHT_RELA));
  EXPECT_EQ(Rela.sh_link, 5U);
  EXPECT_EQ(Rela.sh_info, 1U);
  EXPECT_EQ(Rela.sh_addralign, 4U);
  EXPECT_EQ(Rela.sh_entsize, sizeof(ELF::Elf32_Rela));
  EXPECT_EQ(Rela.sh_offset % 4, 0U);

  const auto &SymTab = Sections[5];
  EXPECT_EQ(SymTab.sh_type, static_cast<uint32_t>(ELF::SHT_SYMTAB));
  // One local: the null symbol. The deploy object loads no immutables.
  EXPECT_EQ(SymTab.sh_info, 1U);
  EXPECT_EQ(SymTab.sh_link, 6U);
  EXPECT_EQ(SymTab.sh_addralign, 4U);
  EXPECT_EQ(SymTab.sh_entsize, sizeof(ELF::Elf32_Sym));
  EXPECT_EQ(SymTab.sh_offset % 4, 0U);

  LLVMDisposeMemoryBuffer(DeployObj);
  LLVMDisposeMemoryBuffer(DeployedObj);
  LLVMDisposeMemoryBuffer(Runtime);
  LLVMDisposeMemoryBuffer(Assembled);
}
