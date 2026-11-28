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
#include <string>
#include <vector>

using namespace llvm;

extern const char *TestMainArgv0;

static std::string expand(const char *Path) {
  llvm::SmallString<128> ThisPath =
      llvm::unittest::getInputFileDirectory(TestMainArgv0);
  llvm::sys::path::append(ThisPath, Path);
  return ThisPath.str().str();
}

/// Returns true when \p Buf starts with the ELF magic.
static bool looksLikeELF(LLVMMemoryBufferRef Buf) {
  const StringRef Data(LLVMGetBufferStart(Buf), LLVMGetBufferSize(Buf));
  return Data.starts_with("\x7f"
                          "ELF");
}

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

namespace {

class EVMLinkerTest : public testing::Test {
protected:
  void SetUp() override {
    LLVMInitializeEVMTargetInfo();
    LLVMInitializeEVMTarget();
    LLVMInitializeEVMTargetMC();
    LLVMInitializeEVMAsmPrinter();

    LLVMTargetRef Target = nullptr;
    const char *Triple = "evm";
    char *ErrMsg = nullptr;
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
  LLVMEVMAssembleResult assemble(const std::vector<LLVMMemoryBufferRef> &Objs,
                                 const std::vector<const char *> &IDs,
                                 const std::vector<LLVMEVMLibrarySymbol> &Syms,
                                 bool WithMD = false) {
    LLVMEVMAssembleResult Result = LLVMAssembleEVM(
        Objs.data(), IDs.data(), Objs.size(), WithMD ? MD.data() : nullptr,
        WithMD ? MD.size() : 0, Syms.data(), Syms.size(),
        /*emitElfObject=*/true);
    EXPECT_TRUE(Result.Bytecode);
    EXPECT_FALSE(looksLikeELF(Result.Bytecode));
    EXPECT_TRUE(Result.ElfObject);
    EXPECT_TRUE(looksLikeELF(Result.ElfObject));
    return Result;
  }

  LLVMMemoryBufferRef compileIR(const char *FileName) const {
    auto Buf = MemoryBuffer::getFile(expand(FileName), /*IsText=*/false,
                                     /*RequiresNullTerminator=*/false);
    if (auto EC = Buf.getError())
      exit(1);

    LLVMMemoryBufferRef IrBuf = llvm::wrap(Buf.get().release());
    char *ErrMsg = nullptr;
    LLVMModuleRef Module = nullptr;
    if (LLVMParseIRInContext(Context, IrBuf, &Module, &ErrMsg)) {
      LLVMDisposeMessage(ErrMsg);
      exit(1);
    }

    // Run CodeGen to produce the buffers.
    LLVMMemoryBufferRef Result = nullptr;
    if (LLVMTargetMachineEmitToMemoryBuffer(TM, Module, LLVMObjectFile, &ErrMsg,
                                            &Result)) {
      LLVMDisposeModule(Module);
      LLVMDisposeMessage(ErrMsg);
      exit(1);
    }
    LLVMDisposeModule(Module);
    return Result;
  }

  static LLVMEVMLibrarySymbol symbol(const char *Name, char Fill) {
    LLVMEVMLibrarySymbol Sym;
    Sym.Name = Name;
    for (char &C : Sym.Value)
      C = Fill;
    return Sym;
  }

  LLVMTargetMachineRef TM = nullptr;
  LLVMContextRef Context = nullptr;
  std::array<char, 32> MD = {
      0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
      0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16,
      0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20,
  };
};

// The deploy object uses 'library_id' twice, its runtime object uses
// 'library_id2' once. Assembling with none, one and both addresses pins
// the unresolved reporting and the zero-filled slots.
TEST_F(EVMLinkerTest, UnresolvedReferences) {
  LLVMMemoryBufferRef DeployObj = compileIR("deployIr.ll");
  LLVMMemoryBufferRef RuntimeObj = compileIR("deployedIr.ll");
  EXPECT_TRUE(looksLikeELF(DeployObj));
  EXPECT_TRUE(looksLikeELF(RuntimeObj));

  // The runtime assembly leaves its one reference unresolved.
  LLVMEVMAssembleResult Runtime =
      assemble({RuntimeObj}, {"Test_26_deployed"}, {});
  ASSERT_EQ(Runtime.NumUnresolved, 1U);
  EXPECT_STREQ(Runtime.UnresolvedNames[0], "library_id2");

  // The raw runtime object carries one immutable.
  {
    char **Ids = nullptr;
    uint64_t *Offsets = nullptr;
    const uint64_t Count = LLVMGetImmutablesEVM(RuntimeObj, &Ids, &Offsets);
    EXPECT_EQ(Count, 1U);
    EXPECT_STREQ(Ids[0], "id");
    LLVMDisposeImmutablesEVM(Ids, Offsets, Count);
  }

  // No addresses: three zero-filled uses, deploy's first, in text order.
  LLVMEVMAssembleResult NoSyms = assemble({DeployObj, Runtime.ElfObject},
                                          {"Test_26", "Test_26_deployed"}, {});
  ASSERT_EQ(NoSyms.NumUnresolved, 3U);
  EXPECT_STREQ(NoSyms.UnresolvedNames[0], "library_id");
  EXPECT_STREQ(NoSyms.UnresolvedNames[1], "library_id");
  EXPECT_STREQ(NoSyms.UnresolvedNames[2], "library_id2");
  EXPECT_LT(NoSyms.UnresolvedOffsets[0], NoSyms.UnresolvedOffsets[1]);
  EXPECT_LT(NoSyms.UnresolvedOffsets[1], NoSyms.UnresolvedOffsets[2]);
  const StringRef NoSymsBin(LLVMGetBufferStart(NoSyms.Bytecode),
                            LLVMGetBufferSize(NoSyms.Bytecode));
  const std::string Zeros(LLVM_EVM_LINKER_SYMBOL_SIZE, '\0');
  for (uint64_t Idx = 0; Idx < NoSyms.NumUnresolved; ++Idx)
    EXPECT_EQ(NoSymsBin.substr(NoSyms.UnresolvedOffsets[Idx],
                               LLVM_EVM_LINKER_SYMBOL_SIZE),
              StringRef(Zeros));

  // One address: the other reference stays unresolved.
  const LLVMEVMLibrarySymbol First = symbol("library_id", 0x11);
  const LLVMEVMLibrarySymbol Second = symbol("library_id2", 0x22);
  LLVMEVMAssembleResult OneSym = assemble(
      {DeployObj, Runtime.ElfObject}, {"Test_26", "Test_26_deployed"}, {First});
  ASSERT_EQ(OneSym.NumUnresolved, 1U);
  EXPECT_STREQ(OneSym.UnresolvedNames[0], "library_id2");

  // Both addresses: nothing unresolved, both values in the bytecode.
  LLVMEVMAssembleResult Full =
      assemble({DeployObj, Runtime.ElfObject}, {"Test_26", "Test_26_deployed"},
               {First, Second});
  EXPECT_EQ(Full.NumUnresolved, 0U);
  const StringRef FullBin(LLVMGetBufferStart(Full.Bytecode),
                          LLVMGetBufferSize(Full.Bytecode));
  const std::string FirstVal(LLVM_EVM_LINKER_SYMBOL_SIZE, 0x11);
  const std::string SecondVal(LLVM_EVM_LINKER_SYMBOL_SIZE, 0x22);
  EXPECT_TRUE(FullBin.contains(FirstVal));
  EXPECT_TRUE(FullBin.contains(SecondVal));
  // The resolved bytecode has the addresses where the zero-filled one
  // reported the unresolved slots.
  for (uint64_t Idx = 0; Idx < 2; ++Idx)
    EXPECT_EQ(FullBin.substr(NoSyms.UnresolvedOffsets[Idx],
                             LLVM_EVM_LINKER_SYMBOL_SIZE),
              StringRef(FirstVal));
  EXPECT_EQ(
      FullBin.substr(NoSyms.UnresolvedOffsets[2], LLVM_EVM_LINKER_SYMBOL_SIZE),
      StringRef(SecondVal));

  LLVMDisposeAssembleResultEVM(&Runtime);
  LLVMDisposeAssembleResultEVM(&NoSyms);
  LLVMDisposeAssembleResultEVM(&OneSym);
  LLVMDisposeAssembleResultEVM(&Full);
  LLVMDisposeMemoryBuffer(DeployObj);
  LLVMDisposeMemoryBuffer(RuntimeObj);
}

TEST_F(EVMLinkerTest, Assembly) {
  const LLVMEVMLibrarySymbol Unused = symbol("unused_library_id", 0x01);
  const LLVMEVMLibrarySymbol Lib = symbol("library_id", 0x05);

  LLVMMemoryBufferRef A_deploy_obj = compileIR("A_deploy.ll");
  LLVMMemoryBufferRef A_deployed_obj = compileIR("A_deployed.ll");
  LLVMMemoryBufferRef D_deploy_obj = compileIR("D_deploy.ll");
  LLVMMemoryBufferRef D_deployed_obj = compileIR("D_deployed.ll");
  LLVMMemoryBufferRef R_deploy_obj = compileIR("R_deploy.ll");
  LLVMMemoryBufferRef R_deployed_obj = compileIR("R_deployed.ll");

  // A assemble.
  LLVMEVMAssembleResult A_deployed =
      assemble({A_deployed_obj}, {"A_38_deployed"}, {}, /*WithMD=*/true);
  LLVMEVMAssembleResult A = assemble({A_deploy_obj, A_deployed.ElfObject},
                                     {"A_38", "A_38_deployed"}, {});

  // D assemble.
  LLVMEVMAssembleResult D_deployed =
      assemble({D_deployed_obj}, {"D_38_deployed"}, {}, /*WithMD=*/true);
  LLVMEVMAssembleResult D = assemble({D_deploy_obj, D_deployed.ElfObject},
                                     {"D_51", "D_51_deployed"}, {});

  // R_deployed assemble.
  // A is not required here, but we add it intentionally to check
  // that it will be ignored (the total number of library references is 3).
  LLVMEVMAssembleResult R_deployed =
      assemble({R_deployed_obj, D.ElfObject, A.ElfObject, A_deployed.ElfObject},
               {"R_107_deployed", "D_51", "A_38", "A_38.A_38_deployed"}, {},
               /*WithMD=*/true);

  // R assemble, with an unused symbol, which has no effect, and the one
  // every reference uses.
  LLVMEVMAssembleResult R = assemble(
      {R_deploy_obj, R_deployed.ElfObject, A.ElfObject, A_deployed.ElfObject},
      {"R_107", "R_107_deployed", "A_38", "A_38.A_38_deployed"}, {Unused, Lib});
  EXPECT_EQ(R.NumUnresolved, 0U);

  const StringRef Binary(LLVMGetBufferStart(R.Bytecode),
                         LLVMGetBufferSize(R.Bytecode));
  const std::string LibAddr(LLVM_EVM_LINKER_SYMBOL_SIZE, 0x05);
  EXPECT_EQ(Binary.count(LibAddr), 3U);
  EXPECT_EQ(Binary.count(StringRef(MD.data(), MD.size())), 5U);

  // The layout reports each input's offset. Included inputs ascend in input
  // order starting at zero, the metadata ends the bytecode, and an input the
  // first object never references keeps UINT64_MAX as its offset.
  const auto CheckLayout = [](const LLVMEVMAssembleResult &Res,
                              uint64_t NumInputs, uint64_t MDSize) {
    EXPECT_EQ(Res.NumInputs, NumInputs);
    uint64_t PrevOffset = 0;
    for (uint64_t Idx = 0; Idx < Res.NumInputs; ++Idx) {
      if (Res.InputOffsets[Idx] == UINT64_MAX)
        continue;
      EXPECT_GE(Res.InputOffsets[Idx], PrevOffset);
      EXPECT_LT(Res.InputOffsets[Idx], Res.MetadataOffset);
      PrevOffset = Res.InputOffsets[Idx];
    }
    EXPECT_EQ(Res.InputOffsets[0], 0U);
    EXPECT_EQ(Res.MetadataOffset + MDSize, LLVMGetBufferSize(Res.Bytecode));
  };
  CheckLayout(A_deployed, 1, MD.size());
  CheckLayout(A, 2, 0);
  CheckLayout(R_deployed, 4, MD.size());
  CheckLayout(R, 4, 0);
  EXPECT_EQ(R_deployed.InputOffsets[2], UINT64_MAX);

  LLVMDisposeAssembleResultEVM(&A_deployed);
  LLVMDisposeAssembleResultEVM(&A);
  LLVMDisposeAssembleResultEVM(&D_deployed);
  LLVMDisposeAssembleResultEVM(&D);
  LLVMDisposeAssembleResultEVM(&R_deployed);
  LLVMDisposeAssembleResultEVM(&R);
  LLVMDisposeMemoryBuffer(A_deploy_obj);
  LLVMDisposeMemoryBuffer(A_deployed_obj);
  LLVMDisposeMemoryBuffer(D_deploy_obj);
  LLVMDisposeMemoryBuffer(D_deployed_obj);
  LLVMDisposeMemoryBuffer(R_deploy_obj);
  LLVMDisposeMemoryBuffer(R_deployed_obj);
}

#if GTEST_HAS_DEATH_TEST
// A '__dataoffset' or '__datasize' of an object the driver did not pass is a
// driver bug, and the linker aborts on it.
TEST_F(EVMLinkerTest, UndefNonRefSymbols) {
  LLVMMemoryBufferRef DeployObj = compileIR("undefDeployIr.ll");
  LLVMMemoryBufferRef DeployedObj = compileIR("undefDeployedIr.ll");

  EXPECT_TRUE(looksLikeELF(DeployObj));
  EXPECT_TRUE(looksLikeELF(DeployedObj));

  const std::array<LLVMMemoryBufferRef, 2> InObjs = {DeployObj, DeployedObj};
  const std::array<const char *, 2> IDs = {"Test_26", "Test_26_deployed"};
  // The EXPECT_DEATH expansion uses 'goto' and unbraced 'if'.
  // NOLINTBEGIN(cppcoreguidelines-avoid-goto)
  // NOLINTBEGIN(readability-inconsistent-ifelse-braces)
  EXPECT_DEATH(LLVMAssembleEVM(InObjs.data(), IDs.data(), IDs.size(), nullptr,
                               0, nullptr, 0, /*emitElfObject=*/false),
               "non-ref undefined symbol:");
  // NOLINTEND(readability-inconsistent-ifelse-braces)
  // NOLINTEND(cppcoreguidelines-avoid-goto)

  LLVMDisposeMemoryBuffer(DeployObj);
  LLVMDisposeMemoryBuffer(DeployedObj);
}
#endif

// Pins the values the linker writes: the big-endian '__dataoffset' and
// '__datasize' immediates, the bytecode length, the metadata tail, the
// reported unresolved offsets, and the invariant that the bytecode equals
// the object's '.text'.
TEST_F(EVMLinkerTest, RelocationValues) {
  LLVMMemoryBufferRef DeployObj = compileIR("deployIr.ll");
  LLVMMemoryBufferRef RuntimeObj = compileIR("deployedIr.ll");
  const std::string DeployText = textSection(DeployObj);
  const std::string RuntimeText = textSection(RuntimeObj);
  const StringRef Metadata(MD.data(), MD.size());

  // The runtime segment is its code plus the metadata.
  LLVMEVMAssembleResult Runtime =
      assemble({RuntimeObj}, {"Test_26_deployed"}, {}, /*WithMD=*/true);
  const std::string RuntimeAsmText = textSection(Runtime.ElfObject);
  EXPECT_EQ(RuntimeAsmText.size(), RuntimeText.size() + MD.size());
  EXPECT_EQ(StringRef(RuntimeAsmText).take_back(MD.size()), Metadata);

  // The deploy segment embeds it right after the deploy code, and the
  // addresses resolve in the same call.
  const LLVMEVMLibrarySymbol First = symbol("library_id", 0x11);
  const LLVMEVMLibrarySymbol Second = symbol("library_id2", 0x22);
  LLVMEVMAssembleResult Full =
      assemble({DeployObj, Runtime.ElfObject}, {"Test_26", "Test_26_deployed"},
               {First, Second});
  EXPECT_EQ(Full.NumUnresolved, 0U);
  const std::string FullText = textSection(Full.ElfObject);
  EXPECT_EQ(FullText.size(), DeployText.size() + RuntimeAsmText.size());

  // '__dataoffset' and '__datasize' resolve to the runtime's offset and
  // size, written big-endian into PUSH4 immediates.
  const std::string DataOffset =
      std::string(1, '\x63') + be32(DeployText.size());
  const std::string DataSize =
      std::string(1, '\x63') + be32(RuntimeAsmText.size());
  EXPECT_NE(FullText.find(DataOffset), std::string::npos);
  EXPECT_NE(FullText.find(DataSize), std::string::npos);

  // The bytecode is the object's '.text', byte for byte, and ends with the
  // embedded runtime's metadata.
  const StringRef Bin(LLVMGetBufferStart(Full.Bytecode),
                      LLVMGetBufferSize(Full.Bytecode));
  EXPECT_EQ(Bin, StringRef(FullText));
  EXPECT_EQ(Bin.take_back(MD.size()), Metadata);

  // The unresolved offsets of an address-less call point at the library
  // slots the resolved bytecode holds the addresses in.
  LLVMEVMAssembleResult NoSyms = assemble({DeployObj, Runtime.ElfObject},
                                          {"Test_26", "Test_26_deployed"}, {});
  ASSERT_EQ(NoSyms.NumUnresolved, 3U);
  const std::string FirstVal(LLVM_EVM_LINKER_SYMBOL_SIZE, 0x11);
  for (uint64_t Idx = 0; Idx < 2; ++Idx) {
    ASSERT_LE(NoSyms.UnresolvedOffsets[Idx] + LLVM_EVM_LINKER_SYMBOL_SIZE,
              Bin.size());
    EXPECT_EQ(
        Bin.substr(NoSyms.UnresolvedOffsets[Idx], LLVM_EVM_LINKER_SYMBOL_SIZE),
        StringRef(FirstVal));
  }

  LLVMDisposeAssembleResultEVM(&Runtime);
  LLVMDisposeAssembleResultEVM(&Full);
  LLVMDisposeAssembleResultEVM(&NoSyms);
  LLVMDisposeMemoryBuffer(DeployObj);
  LLVMDisposeMemoryBuffer(RuntimeObj);
}

// Pins the immutable offsets: they point at the PUSH32 immediate, one byte
// past the opcode, both in the raw object and in the assembled one.
TEST_F(EVMLinkerTest, ImmutableOffsets) {
  LLVMMemoryBufferRef RuntimeObj = compileIR("deployedIr.ll");
  const std::string Text = textSection(RuntimeObj);

  char **Ids = nullptr;
  uint64_t *Offsets = nullptr;
  uint64_t Count = LLVMGetImmutablesEVM(RuntimeObj, &Ids, &Offsets);
  ASSERT_EQ(Count, 1U);
  EXPECT_STREQ(Ids[0], "id");
  ASSERT_GT(Offsets[0], 0U);
  ASSERT_LE(Offsets[0] + 32, Text.size());
  EXPECT_EQ(static_cast<uint8_t>(Text[Offsets[0] - 1]), 0x7F); // PUSH32
  const uint64_t RawOffset = Offsets[0];
  LLVMDisposeImmutablesEVM(Ids, Offsets, Count);

  // The assembled runtime object carries the same immutable symbol.
  LLVMEVMAssembleResult Runtime =
      assemble({RuntimeObj}, {"Test_26_deployed"}, {}, /*WithMD=*/true);
  const std::string RuntimeAsmText = textSection(Runtime.ElfObject);
  Count = LLVMGetImmutablesEVM(Runtime.ElfObject, &Ids, &Offsets);
  ASSERT_EQ(Count, 1U);
  EXPECT_STREQ(Ids[0], "id");
  EXPECT_EQ(Offsets[0], RawOffset);
  EXPECT_EQ(static_cast<uint8_t>(RuntimeAsmText[Offsets[0] - 1]), 0x7F);
  LLVMDisposeImmutablesEVM(Ids, Offsets, Count);

  LLVMDisposeAssembleResultEVM(&Runtime);
  LLVMDisposeMemoryBuffer(RuntimeObj);
}

// Pins the layout fields of the object the linker writes: section order, the
// symbol table's locals count and link, the relocation section's shape and
// the aligned offsets.
TEST_F(EVMLinkerTest, AssembledObjectLayout) {
  using namespace llvm::object;
  LLVMMemoryBufferRef DeployObj = compileIR("deployIr.ll");
  LLVMMemoryBufferRef RuntimeObj = compileIR("deployedIr.ll");
  LLVMEVMAssembleResult Runtime =
      assemble({RuntimeObj}, {"Test_26_deployed"}, {}, /*WithMD=*/true);
  LLVMEVMAssembleResult Full = assemble({DeployObj, Runtime.ElfObject},
                                        {"Test_26", "Test_26_deployed"}, {});

  MemoryBufferRef Ref(StringRef(LLVMGetBufferStart(Full.ElfObject),
                                LLVMGetBufferSize(Full.ElfObject)),
                      "assembled");
  ELFObjectFile<ELF32BE> Obj = cantFail(ELFObjectFile<ELF32BE>::create(Ref));
  const ELFFile<ELF32BE> &EF = Obj.getELFFile();
  EXPECT_EQ(EF.getHeader().e_ehsize, sizeof(ELF::Elf32_Ehdr));
  EXPECT_EQ(EF.getHeader().e_shoff % 4, 0U);
  // The deploy assembly keeps the deploy kind, the runtime one its flag.
  EXPECT_EQ(EF.getHeader().e_flags, 0U);
  MemoryBufferRef RuntimeRef(StringRef(LLVMGetBufferStart(Runtime.ElfObject),
                                       LLVMGetBufferSize(Runtime.ElfObject)),
                             "runtime");
  ELFObjectFile<ELF32BE> RuntimeElf =
      cantFail(ELFObjectFile<ELF32BE>::create(RuntimeRef));
  EXPECT_EQ(RuntimeElf.getELFFile().getHeader().e_flags,
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

  LLVMDisposeAssembleResultEVM(&Runtime);
  LLVMDisposeAssembleResultEVM(&Full);
  LLVMDisposeMemoryBuffer(DeployObj);
  LLVMDisposeMemoryBuffer(RuntimeObj);
}

} // namespace
