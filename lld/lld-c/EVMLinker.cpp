//===--- EVMLinker.cpp - EVM assembling and linking -----------*- C++ -*---===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Implements 'LLVMAssembleEVM' and 'LLVMLinkEVM'.
//
// Linking an EVM contract asks for almost nothing of a general linker. Every
// input is a relocatable ELF32 big-endian object holding one '.text' section;
// there is a single relocation type, R_EVM_DATA, which writes a 32-bit
// big-endian absolute value; and the output is the concatenation of those
// sections at address zero, followed by the contract's metadata.
//
// Assembling lays the sections out, defines the '__dataoffset' and '__datasize'
// symbols the layout determines, and applies every relocation it can resolve.
// A library address is not known then, so the relocations against its five
// '__linker_symbol' sub-symbols are carried into the output together with the
// section naming the library. Linking substitutes the addresses it is given
// and produces the bytecode once none is missing.
//
// Both write their output straight into the buffer they return: the ELF is a
// few hundred bytes of headers around the code, so this file writes it itself.
//
//===----------------------------------------------------------------------===//

#include "lld-c/LLDAsLibraryC.h"

#include "llvm-c/Core.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/Object/ELFObjectFile.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/MemoryBuffer.h"

#include <cstring>
#include <string>

using namespace llvm;
using namespace llvm::object;
using namespace llvm::support::endian;

namespace llvm {
namespace EVM {
std::string getLinkerSymbolHash(StringRef SymName);
std::string getLinkerSymbolName(StringRef SymName);
std::string getSymbolIndexedName(StringRef Name, unsigned SubIdx);
bool isSymbolSectionName(StringRef Name);
std::string getDataSizeSymbol(StringRef SymbolName);
bool isDataOffsetSymbolName(StringRef Name);
std::string getDataOffsetSymbol(StringRef Name);
std::string extractDataOffseteName(StringRef SymbolName);
bool isLoadImmutableSymbolName(StringRef Name);
} // namespace EVM
} // namespace llvm

namespace {

/// The number of 32-bit sub-symbols a linker symbol is split into.
constexpr unsigned SubSymbolNum = LINKER_SYMBOL_SIZE / sizeof(uint32_t);

/// The prefix of the section holding a library's source name.
constexpr StringRef NameSectionPrefix = ".symbol_name";

/// A relocation that resolved, to be written into the output '.text'.
struct Patch {
  uint64_t Offset = 0;
  uint32_t Value = 0;
};

/// A relocation that did not resolve, to be carried into the output.
struct CarriedReloc {
  uint64_t Offset = 0; ///< Offset in the output '.text'.
  std::string Sym;     ///< The sub-symbol it refers to.
  int64_t Addend = 0;
};

/// A '.symbol_name...' section, whose contents is the library's source name.
struct NameSection {
  StringRef Name;
  StringRef Data;
};

/// A symbol of the output object.
struct OutSymbol {
  std::string Name;
  uint32_t Value = 0;
  uint16_t Shndx = ELF::SHN_UNDEF;
  uint8_t Info = 0; ///< (binding << 4) | type.
  uint8_t Other = 0;
};

/// A part of the output '.text', copied from an input.
struct Piece {
  StringRef Data;
  uint64_t Offset = 0;
};

/// Everything the output is made of.
struct Output {
  SmallVector<Piece, 4> Pieces;
  uint64_t TextSize = 0;
  SmallVector<Patch, 16> Patches;
  SmallVector<CarriedReloc, 8> Relocs;
  SmallVector<NameSection, 2> NameSections;
  SmallVector<OutSymbol, 4> Immutables;
};

/// One input object, read in place out of the caller's buffer. The binary is
/// held by pointer: ELFObjectFile is not safely movable, so it must not be
/// stored by value in a container.
struct Input {
  std::unique_ptr<Binary> Bin;
  const ObjectFile *File = nullptr;
  std::string IdHash;
  StringRef Text;          ///< '.text' contents, empty when absent.
  uint64_t TextOffset = 0; ///< Where '.text' lands in the output.
  bool Included = false;   ///< Whether the layout includes this object.
};

/// Fails with \p Why, which the caller owns.
bool fail(char **ErrorMessage, const Twine &Why) {
  *ErrorMessage = strdup(Why.str().c_str());
  return true;
}

/// Strips the sub-symbol index a linker symbol name ends with.
StringRef baseSymbolName(StringRef Name) {
  assert(!Name.empty() && Name.back() >= '0' &&
         Name.back() < '0' + static_cast<char>(SubSymbolNum));
  return Name.drop_back();
}

/// Returns the contents of the named section, or an empty reference when it is
/// absent.
StringRef findSection(const ObjectFile &File, StringRef Name) {
  for (const SectionRef &Sec : File.sections()) {
    if (cantFail(Sec.getName()) == Name)
      return cantFail(Sec.getContents());
  }
  return StringRef();
}

/// Returns the relocation section targeting '.text', or the end iterator.
section_iterator findTextRelocations(const ObjectFile &File) {
  for (section_iterator It = File.section_begin(), End = File.section_end();
       It != End; ++It) {
    if (It->relocations().empty())
      continue;
    Expected<section_iterator> Target = It->getRelocatedSection();
    if (!Target) {
      consumeError(Target.takeError());
      continue;
    }
    if (*Target != End && cantFail((*Target)->getName()) == ".text")
      return It;
  }
  return File.section_end();
}

/// Returns true when \p Sym is one of the sub-symbols a library address is
/// split into, which only the linker can define.
bool isReferenceSymbol(const SymbolRef &Sym) {
  return ELFSymbolRef(Sym).getOther() == ELF::STO_EVM_REFERENCE_SYMBOL;
}

/// Splits a 20-byte library address into the five 32-bit sub-symbol values the
/// MC layer emits relocations for, and records them in \p Values.
void defineLinkerSymbol(StringMap<uint32_t> &Values, StringRef Name,
                        const char Value[LINKER_SYMBOL_SIZE]) {
  std::string Base = EVM::getLinkerSymbolName(EVM::getLinkerSymbolHash(Name));
  for (unsigned Idx = 0; Idx < SubSymbolNum; ++Idx) {
    uint32_t Word = 0;
    for (unsigned Byte = 0; Byte < sizeof(uint32_t); ++Byte)
      Word = (Word << 8) |
             static_cast<uint8_t>(Value[Idx * sizeof(uint32_t) + Byte]);
    Values[EVM::getSymbolIndexedName(Base, Idx)] = Word;
  }
}

/// Resolves the relocations of \p In, placed at its offset in the output,
/// against \p Values or against the object itself. One that resolves becomes
/// a patch, one against a library address still unknown is carried.
bool resolve(const Input &In, const StringMap<uint32_t> &Values, Output &Out,
             char **ErrorMessage) {
  const section_iterator Rela = findTextRelocations(*In.File);
  if (Rela == In.File->section_end())
    return false;

  for (const RelocationRef &Rel : Rela->relocations()) {
    const uint64_t Type = Rel.getType();
    if (Type == ELF::R_EVM_NONE)
      continue;
    if (Type != ELF::R_EVM_DATA)
      return fail(ErrorMessage, "unexpected relocation type " + Twine(Type));

    const symbol_iterator Sym = Rel.getSymbol();
    if (Sym == In.File->symbol_end())
      return fail(ErrorMessage, "relocation without a symbol");
    const StringRef SymName = cantFail(Sym->getName());
    const uint32_t Flags = cantFail(Sym->getFlags());
    const int64_t Addend = cantFail(ELFRelocationRef(Rel).getAddend());
    const uint64_t Where = In.TextOffset + Rel.getOffset();
    if (Where + sizeof(uint32_t) > Out.TextSize)
      return fail(ErrorMessage, "relocation out of range");

    uint64_t Value = 0;
    if (Flags & SymbolRef::SF_Undefined) {
      const auto It = Values.find(SymName);
      if (It != Values.end()) {
        Value = It->second;
      } else if (isReferenceSymbol(*Sym)) {
        Out.Relocs.push_back(CarriedReloc{Where, SymName.str(), Addend});
        continue;
      } else {
        return fail(ErrorMessage, "non-ref undefined symbol: " + SymName);
      }
    } else if (Flags & SymbolRef::SF_Absolute) {
      Value = cantFail(Sym->getValue());
    } else {
      const section_iterator SymSec = cantFail(Sym->getSection());
      if (SymSec == In.File->section_end() ||
          cantFail(SymSec->getName()) != ".text")
        return fail(ErrorMessage,
                    "symbol " + SymName + " is defined outside .text");
      Value = In.TextOffset + cantFail(Sym->getValue());
    }
    Out.Patches.push_back(Patch{Where, static_cast<uint32_t>(Value + Addend)});
  }
  return false;
}

/// Fails on an undefined symbol of \p File that is neither a library address
/// nor defined by \p Values: a dependency the caller did not pass.
bool checkUndefined(const ObjectFile &File, const StringMap<uint32_t> &Values,
                    char **ErrorMessage) {
  for (const SymbolRef &Sym : File.symbols()) {
    if (!(cantFail(Sym.getFlags()) & SymbolRef::SF_Undefined) ||
        isReferenceSymbol(Sym))
      continue;
    const StringRef Name = cantFail(Sym.getName());
    if (!Name.empty() && !Values.contains(Name))
      return fail(ErrorMessage, "non-ref undefined symbol: " + Name);
  }
  return false;
}

/// Collects the '.symbol_name...' sections of \p File into \p Out, skipping
/// those already there. Several objects referring to the same library carry
/// the same section, and the output holds one of each.
void collectNameSections(const ObjectFile &File, StringSet<> &Seen,
                         Output &Out) {
  for (const SectionRef &Sec : File.sections()) {
    const StringRef Name = cantFail(Sec.getName());
    if (!EVM::isSymbolSectionName(Name) || !Seen.insert(Name).second)
      continue;
    Out.NameSections.push_back(NameSection{Name, cantFail(Sec.getContents())});
  }
}

/// Collects the defined immutable symbols of \p File into \p Out, placed at
/// \p TextOffset. A reader of the assembled object asks for those of the
/// object that sets the immutables.
void collectImmutables(const ObjectFile &File, uint64_t TextOffset,
                       Output &Out) {
  for (const SymbolRef &Sym : File.symbols()) {
    const StringRef Name = cantFail(Sym.getName());
    if (!EVM::isLoadImmutableSymbolName(Name) ||
        (cantFail(Sym.getFlags()) & SymbolRef::SF_Undefined))
      continue;
    OutSymbol Immutable;
    Immutable.Name = Name.str();
    Immutable.Value =
        static_cast<uint32_t>(TextOffset + cantFail(Sym.getValue()));
    Immutable.Shndx = 1; // '.text' is always the first section of the output.
    Immutable.Info = (ELF::STB_LOCAL << 4) | ELF::STT_NOTYPE;
    Out.Immutables.push_back(std::move(Immutable));
  }
}

/// Writes big-endian scalars and bytes at a cursor.
class Writer {
public:
  explicit Writer(char *Pos) : Pos(Pos) {}

  void u8(uint8_t V) { *Pos++ = static_cast<char>(V); }
  void u16(uint16_t V) {
    write16be(Pos, V);
    Pos += 2;
  }
  void u32(uint32_t V) {
    write32be(Pos, V);
    Pos += 4;
  }
  void bytes(StringRef Data) {
    std::memcpy(Pos, Data.data(), Data.size());
    Pos += Data.size();
  }
  void zero(size_t Count) {
    std::memset(Pos, 0, Count);
    Pos += Count;
  }
  char *pos() const { return Pos; }

private:
  char *Pos;
};

/// Copies the pieces of the output '.text' to \p Text and applies the patches.
void writeText(char *Text, const Output &Out) {
  for (const Piece &P : Out.Pieces) {
    if (!P.Data.empty())
      std::memcpy(Text + P.Offset, P.Data.data(), P.Data.size());
  }
  for (const Patch &P : Out.Patches)
    write32be(Text + P.Offset, P.Value);
}

/// Writes the bytecode of \p Out, which has nothing left unresolved.
std::unique_ptr<WritableMemoryBuffer> writeBytecode(const Output &Out,
                                                    StringRef Name) {
  std::unique_ptr<WritableMemoryBuffer> Buf =
      WritableMemoryBuffer::getNewUninitMemBuffer(Out.TextSize, Name);
  writeText(Buf->getBufferStart(), Out);
  return Buf;
}

/// A section header of the output object.
struct Section {
  StringRef Name;
  uint32_t Type = 0;
  uint32_t Flags = 0;
  uint32_t Link = 0;
  uint32_t Info = 0;
  uint32_t EntSize = 0;
  uint32_t Align = 1;
  uint32_t Size = 0;
  uint32_t NameOffset = 0;
  uint32_t FileOffset = 0;
};

/// Writes \p Out as a relocatable ELF32 big-endian EVM object: '.text', its
/// relocations, the sections naming the libraries they refer to, the symbol
/// table and the string tables.
///
/// The symbol table holds the immutable symbols, which are local, and then the
/// undefined sub-symbols of every library still to be resolved, which are
/// global. All five sub-symbols of a library are present even when the code
/// refers to fewer, because a reader of the object expects the group whole.
std::unique_ptr<WritableMemoryBuffer> writeObject(const Output &Out,
                                                  StringRef Name) {
  // The symbols, locals first, as the ELF symbol table requires.
  SmallVector<OutSymbol, 16> Symbols;
  Symbols.push_back(OutSymbol());
  for (const OutSymbol &Sym : Out.Immutables)
    Symbols.push_back(Sym);
  const unsigned NumLocals = Symbols.size();

  SmallVector<StringRef, 4> Bases;
  StringSet<> SeenBase;
  for (const CarriedReloc &Rel : Out.Relocs) {
    const StringRef Base = baseSymbolName(Rel.Sym);
    if (SeenBase.insert(Base).second)
      Bases.push_back(Base);
  }
  sort(Bases);
  StringMap<uint32_t> SymbolIndex;
  for (const StringRef Base : Bases) {
    for (unsigned Idx = 0; Idx < SubSymbolNum; ++Idx) {
      OutSymbol Sym;
      Sym.Name = EVM::getSymbolIndexedName(Base, Idx);
      Sym.Info = (ELF::STB_GLOBAL << 4) | ELF::STT_NOTYPE;
      Sym.Other = ELF::STO_EVM_REFERENCE_SYMBOL;
      SymbolIndex[Sym.Name] = Symbols.size();
      Symbols.push_back(std::move(Sym));
    }
  }

  // The name sections of the libraries still referred to.
  SmallVector<const NameSection *, 2> NameSections;
  for (const NameSection &Sec : Out.NameSections) {
    if (SeenBase.contains(Sec.Name.drop_front(NameSectionPrefix.size())))
      NameSections.push_back(&Sec);
  }

  SmallString<512> StrTab;
  StrTab.push_back('\0');
  SmallVector<uint32_t, 16> SymNameOffsets(Symbols.size());
  for (unsigned Idx = 1; Idx < Symbols.size(); ++Idx) {
    SymNameOffsets[Idx] = StrTab.size();
    StrTab.append(Symbols[Idx].Name);
    StrTab.push_back('\0');
  }

  // The section headers, in file order, and the string table naming them.
  constexpr uint32_t EhdrSize = 52;
  constexpr uint32_t ShdrSize = 40;
  constexpr uint32_t SymSize = 16;
  constexpr uint32_t RelaSize = 12;
  SmallVector<Section, 8> Sections;
  SmallString<256> ShStrTab;
  ShStrTab.push_back('\0');
  auto add = [&](Section Sec) {
    Sec.NameOffset = ShStrTab.size();
    ShStrTab.append(Sec.Name);
    ShStrTab.push_back('\0');
    Sections.push_back(Sec);
    return Sections.size() - 1;
  };
  Sections.push_back(Section());

  Section Text;
  Text.Name = ".text";
  Text.Type = ELF::SHT_PROGBITS;
  Text.Flags = ELF::SHF_ALLOC | ELF::SHF_EXECINSTR;
  Text.Size = Out.TextSize;
  const uint32_t TextIdx = add(Text);

  const bool HasRelocs = !Out.Relocs.empty();
  uint32_t RelaIdx = 0;
  if (HasRelocs) {
    Section Rela;
    Rela.Name = ".rela.text";
    Rela.Type = ELF::SHT_RELA;
    Rela.Flags = ELF::SHF_INFO_LINK;
    Rela.Info = TextIdx;
    Rela.EntSize = RelaSize;
    Rela.Align = 4;
    Rela.Size = Out.Relocs.size() * RelaSize;
    RelaIdx = add(Rela);
  }

  const uint32_t FirstNameIdx = Sections.size();
  for (const NameSection *Sec : NameSections) {
    Section S;
    S.Name = Sec->Name;
    S.Type = ELF::SHT_PROGBITS;
    S.Flags = ELF::SHF_STRINGS;
    S.Size = Sec->Data.size();
    add(S);
  }

  Section SymTab;
  SymTab.Name = ".symtab";
  SymTab.Type = ELF::SHT_SYMTAB;
  SymTab.Info = NumLocals;
  SymTab.EntSize = SymSize;
  SymTab.Align = 4;
  SymTab.Size = Symbols.size() * SymSize;
  const uint32_t SymTabIdx = add(SymTab);
  Sections[SymTabIdx].Link = SymTabIdx + 1;
  if (HasRelocs)
    Sections[RelaIdx].Link = SymTabIdx;

  Section StrTabSec;
  StrTabSec.Name = ".strtab";
  StrTabSec.Type = ELF::SHT_STRTAB;
  StrTabSec.Size = StrTab.size();
  add(StrTabSec);

  Section ShStrTabSec;
  ShStrTabSec.Name = ".shstrtab";
  ShStrTabSec.Type = ELF::SHT_STRTAB;
  const uint32_t ShStrTabIdx = add(ShStrTabSec);
  Sections[ShStrTabIdx].Size = ShStrTab.size();

  // The file: the header, the section contents, the section headers.
  uint32_t Offset = EhdrSize;
  for (Section &Sec : drop_begin(Sections)) {
    Offset = alignTo(Offset, Sec.Align);
    Sec.FileOffset = Offset;
    Offset += Sec.Size;
  }
  const uint32_t ShOff = alignTo(Offset, 4);
  const uint32_t FileSize = ShOff + Sections.size() * ShdrSize;

  std::unique_ptr<WritableMemoryBuffer> Buf =
      WritableMemoryBuffer::getNewUninitMemBuffer(FileSize, Name);
  char *const Start = Buf->getBufferStart();
  Writer W(Start);
  W.u8(0x7f);
  W.u8('E');
  W.u8('L');
  W.u8('F');
  W.u8(ELF::ELFCLASS32);
  W.u8(ELF::ELFDATA2MSB);
  W.u8(ELF::EV_CURRENT);
  W.u8(ELF::ELFOSABI_STANDALONE);
  W.zero(8);
  W.u16(ELF::ET_REL);
  W.u16(ELF::EM_EVM);
  W.u32(ELF::EV_CURRENT);
  W.u32(0); // e_entry
  W.u32(0); // e_phoff
  W.u32(ShOff);
  W.u32(0); // e_flags
  W.u16(EhdrSize);
  W.u16(0); // e_phentsize
  W.u16(0); // e_phnum
  W.u16(ShdrSize);
  W.u16(static_cast<uint16_t>(Sections.size()));
  W.u16(static_cast<uint16_t>(ShStrTabIdx));
  assert(W.pos() == Start + EhdrSize);

  auto seek = [&](const Section &Sec) {
    W.zero(Start + Sec.FileOffset - W.pos());
  };

  seek(Sections[TextIdx]);
  writeText(W.pos(), Out);
  W = Writer(W.pos() + Out.TextSize);

  if (HasRelocs) {
    seek(Sections[RelaIdx]);
    for (const CarriedReloc &Rel : Out.Relocs) {
      W.u32(static_cast<uint32_t>(Rel.Offset));
      W.u32((SymbolIndex[Rel.Sym] << 8) | ELF::R_EVM_DATA);
      W.u32(static_cast<uint32_t>(Rel.Addend));
    }
  }

  for (const auto &[Idx, Sec] : enumerate(NameSections)) {
    seek(Sections[FirstNameIdx + Idx]);
    W.bytes(Sec->Data);
  }

  seek(Sections[SymTabIdx]);
  for (unsigned Idx = 0; Idx < Symbols.size(); ++Idx) {
    const OutSymbol &Sym = Symbols[Idx];
    W.u32(SymNameOffsets[Idx]);
    W.u32(Sym.Value);
    W.u32(0); // st_size
    W.u8(Sym.Info);
    W.u8(Sym.Other);
    W.u16(Sym.Shndx);
  }
  seek(Sections[SymTabIdx + 1]);
  W.bytes(StrTab);
  seek(Sections[ShStrTabIdx]);
  W.bytes(ShStrTab);

  W.zero(Start + ShOff - W.pos());
  for (const Section &Sec : Sections) {
    const bool Null = Sec.Type == ELF::SHT_NULL;
    W.u32(Sec.NameOffset);
    W.u32(Sec.Type);
    W.u32(Sec.Flags);
    W.u32(0); // sh_addr
    W.u32(Null ? 0 : Sec.FileOffset);
    W.u32(Sec.Size);
    W.u32(Sec.Link);
    W.u32(Sec.Info);
    W.u32(Null ? 0 : Sec.Align);
    W.u32(Sec.EntSize);
  }
  assert(W.pos() == Start + FileSize);
  return Buf;
}

} // namespace

LLVMBool LLVMAssembleEVM(uint64_t codeSegment,
                         const LLVMMemoryBufferRef inBuffers[],
                         const char *const inBuffersIDs[],
                         uint64_t inBuffersNum, const char *metadata,
                         uint64_t metadataSize, LLVMMemoryBufferRef *outBuffer,
                         char **errorMessage) {
  *outBuffer = nullptr;
  if (inBuffersNum == 0)
    return fail(errorMessage, "assembly: no input");

  // Read every input in place. Nothing is copied here: the ELF reader keeps
  // references into the caller's buffers.
  SmallVector<Input, 4> Inputs(inBuffersNum);
  for (uint64_t Idx = 0; Idx < inBuffersNum; ++Idx) {
    Input &In = Inputs[Idx];
    In.IdHash = EVM::getLinkerSymbolHash(inBuffersIDs[Idx]);
    Expected<std::unique_ptr<Binary>> Bin =
        createBinary(*unwrap(inBuffers[Idx]));
    if (!Bin) {
      consumeError(Bin.takeError());
      return fail(errorMessage, "assembly: input " + Twine(inBuffersIDs[Idx]) +
                                    " is not an EVM ELF object");
    }
    if (!(*Bin)->isObject())
      return fail(errorMessage, "assembly: input " + Twine(inBuffersIDs[Idx]) +
                                    " is not an EVM ELF object");
    In.Bin = std::move(*Bin);
    In.File = static_cast<const ObjectFile *>(In.Bin.get());
    In.Text = findSection(*In.File, ".text");
  }

  // The first object names the dependencies it reaches through '__dataoffset';
  // the layout includes those and nothing else.
  StringSet<> Referenced;
  bool FirstSetsImmutables = false;
  for (const SymbolRef &Sym : Inputs[0].File->symbols()) {
    const StringRef Name = cantFail(Sym.getName());
    if (EVM::isLoadImmutableSymbolName(Name))
      FirstSetsImmutables = true;
    else if (EVM::isDataOffsetSymbolName(Name))
      Referenced.insert(EVM::extractDataOffseteName(Name));
  }

  // A 'codeSegment' of 0 means the first object holds the deploy code, so the
  // first dependency holds the runtime code it deploys. One of the two sets
  // the immutables and the other loads them; both at once is a codegen bug.
  if (codeSegment == 0 && inBuffersNum > 1 && FirstSetsImmutables) {
    for (const SymbolRef &Sym : Inputs[1].File->symbols()) {
      if ((cantFail(Sym.getFlags()) & SymbolRef::SF_Undefined) ||
          !EVM::isLoadImmutableSymbolName(cantFail(Sym.getName())))
        continue;
      report_fatal_error("assembly both sets up and loads immutables");
    }
  }

  // Lay the sections out at address zero, in input order, and define the
  // '__dataoffset' and '__datasize' symbols the layout determines. The
  // metadata follows the code, and the first object's '__datasize' covers it
  // all.
  Output Out;
  StringMap<uint32_t> Values;
  for (uint64_t Idx = 1; Idx < inBuffersNum; ++Idx)
    Values[EVM::getDataSizeSymbol(Inputs[Idx].IdHash)] =
        static_cast<uint32_t>(Inputs[Idx].Text.size());
  for (uint64_t Idx = 0; Idx < inBuffersNum; ++Idx) {
    Input &In = Inputs[Idx];
    if (Idx != 0 && !Referenced.contains(In.IdHash))
      continue;
    In.Included = true;
    In.TextOffset = Out.TextSize;
    Values[EVM::getDataOffsetSymbol(In.IdHash)] =
        static_cast<uint32_t>(Out.TextSize);
    Out.Pieces.push_back(Piece{In.Text, Out.TextSize});
    Out.TextSize += In.Text.size();
  }
  Out.Pieces.push_back(Piece{StringRef(metadata, metadataSize), Out.TextSize});
  Out.TextSize += metadataSize;
  Values[EVM::getDataSizeSymbol(Inputs[0].IdHash)] =
      static_cast<uint32_t>(Out.TextSize);

  StringSet<> SeenNameSections;
  for (const Input &In : Inputs) {
    if (!In.Included)
      continue;
    if (checkUndefined(*In.File, Values, errorMessage) ||
        resolve(In, Values, Out, errorMessage))
      return true;
    collectNameSections(*In.File, SeenNameSections, Out);
  }
  collectImmutables(*Inputs[0].File, Inputs[0].TextOffset, Out);

  *outBuffer = wrap(writeObject(Out, Inputs[0].IdHash).release());
  return false;
}

LLVMBool LLVMLinkEVM(LLVMMemoryBufferRef inBuffer,
                     LLVMMemoryBufferRef *outBuffer,
                     const char *const *linkerSymbolNames,
                     const char linkerSymbolValues[][LINKER_SYMBOL_SIZE],
                     uint64_t numLinkerSymbols, char **errorMessage) {
  *outBuffer = nullptr;
  if (!LLVMIsELFEVM(inBuffer))
    return fail(errorMessage, "Input binary is not an EVM ELF file");

  Input In;
  In.Bin = cantFail(createBinary(*unwrap(inBuffer)));
  In.File = static_cast<const ObjectFile *>(In.Bin.get());
  In.Text = findSection(*In.File, ".text");
  In.Included = true;

  StringMap<uint32_t> Values;
  for (uint64_t Idx = 0; Idx < numLinkerSymbols; ++Idx)
    defineLinkerSymbol(Values, linkerSymbolNames[Idx], linkerSymbolValues[Idx]);

  Output Out;
  Out.Pieces.push_back(Piece{In.Text, 0});
  Out.TextSize = In.Text.size();
  if (checkUndefined(*In.File, Values, errorMessage) ||
      resolve(In, Values, Out, errorMessage))
    return true;

  if (Out.Relocs.empty()) {
    *outBuffer = wrap(writeBytecode(Out, "result").release());
    return false;
  }
  StringSet<> Seen;
  collectNameSections(*In.File, Seen, Out);
  collectImmutables(*In.File, 0, Out);
  *outBuffer = wrap(writeObject(Out, "result").release());
  return false;
}
