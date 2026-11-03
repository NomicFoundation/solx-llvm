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
// Every input is a relocatable ELF32 big-endian object holding one '.text'
// section. There are two relocation types: R_EVM_DATA, which writes a 32-bit
// big-endian absolute value, and R_EVM_DATA_160, which writes a 20-byte
// library address. The output is the concatenation of those sections at
// address zero, followed by the contract's metadata.
//
// Assembling lays the sections out, defines the '__dataoffset' and '__datasize'
// symbols the layout determines, and applies every relocation it can resolve.
// A library address is not known then, so the relocation against its
// '__linker_symbol' is carried into the output together with the section
// naming the library. Linking substitutes the addresses it is given and
// produces the bytecode once none is missing.
//
// The output object format
// ------------------------
// Every object written here is a relocatable ELF32 big-endian file (ET_REL,
// EM_EVM) holding these sections, in this order:
//
//   [0] null              The all-zero section the ELF reference requires at
//                         index 0 (SHN_UNDEF).
//   [1] .text             The bytecode: the laid-out code of every included
//                         object, followed by the metadata. Unresolved
//                         library addresses are zero bytes in it.
//   [2] .rela.text        Present only while library addresses remain
//                         unresolved. One R_EVM_DATA_160 record per use:
//                         'r_offset' names the 20 address bytes in '.text'
//                         and 'r_info' names the library's symbol. The addend
//                         is always zero.
//   ... .symbol_name<sym> One per unresolved library. The section name
//                         carries the mangled '__linker_symbol__$hash$__'
//                         and the contents the library's source name, which
//                         'LLVMGetUndefinedReferencesEVM' reports.
//   ... .symtab           The null symbol, then one local symbol per
//                         immutable load site ('__load_immutable__<id>.<n>',
//                         'st_value' is the PUSH32 offset in '.text'), then
//                         one global undefined symbol per unresolved library,
//                         sorted by name and marked with
//                         STO_EVM_REFERENCE_SYMBOL in 'st_other'.
//   ... .strtab           The symbol names.
//   ... .shstrtab         The section names, referenced by 'e_shstrndx'.
//
// The relations between them are the standard ELF ones. '.rela.text' links
// to '.symtab' ('sh_link') and applies to '.text' ('sh_info'). '.symtab'
// links to '.strtab' and counts its locals in 'sh_info'. The immutable
// symbols point into '.text' through 'st_shndx', and the library symbols are
// SHN_UNDEF because only linking defines them.
//
// The layout is: the ELF header at offset zero, the section contents in
// header order, each at the next offset aligned to its 'sh_addralign' (4 for
// '.rela.text' and '.symtab', 1 for the rest), and the section header table
// at 'e_shoff', word-aligned, at the end of the file.
//
// Once the last library address resolves, the ELF wrapper disappears: the
// output of 'LLVMLinkEVM' is then the raw '.text' bytes.
//
//===----------------------------------------------------------------------===//

#include "llvm-c/EVMLinker.h"
#include "EVMLinkerUtils.h"
#include "MCTargetDesc/EVMMCTargetDesc.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/MC/StringTableBuilder.h"
#include "llvm/Object/ELFObjectFile.h"
#include "llvm/Object/ELFTypes.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/raw_ostream.h"

#include <array>
#include <cstring>
#include <string>

using namespace llvm;
using namespace llvm::object;
using namespace llvm::support::endian;

namespace {

/// The bytes a resolved relocation writes, big-endian. The buffer fits the
/// widest kind, a 20-byte library address.
using RelocValue = std::array<uint8_t, LLVM_EVM_LINKER_SYMBOL_SIZE>;

/// A 20-byte library address, big-endian.
using LibraryAddress = RelocValue;

/// A relocation that resolved, to be written into the output '.text':
/// the first \p Size bytes of \p Value, big-endian. It holds either a
/// 20-byte library address or a 4-byte data offset or size.
struct Reloc {
  uint64_t Offset;
  uint64_t Size;
  RelocValue Value;

  Reloc(uint64_t Offset, uint64_t Size, const RelocValue &Value)
      : Offset(Offset), Size(Size), Value(Value) {}
};

/// A library address relocation that did not resolve, to be carried into
/// the output's '.rela.text'.
struct LibraryReloc {
  /// Offset in the output '.text'.
  uint64_t Offset;
  /// The '__linker_symbol' it refers to.
  std::string Sym;

  LibraryReloc(uint64_t Offset, StringRef Sym)
      : Offset(Offset), Sym(Sym.str()) {}
};

/// A '.symbol_name...' section, whose contents is the library's source name.
struct NameSection {
  StringRef Name;
  StringRef Data;

  NameSection(StringRef Name, StringRef Data) : Name(Name), Data(Data) {}
};

/// An immutable load site of the output object: a local '.text' symbol.
struct Immutable {
  std::string Name;
  uint32_t Value;

  Immutable(StringRef Name, uint32_t Value) : Name(Name.str()), Value(Value) {}
};

/// A part of the output '.text', copied from an input.
struct OutTextSegment {
  StringRef Data;
  uint64_t Offset;

  OutTextSegment(StringRef Data, uint64_t Offset)
      : Data(Data), Offset(Offset) {}
};

/// Everything the output is made of.
struct Output {
  SmallVector<OutTextSegment, 4> Segments;
  uint64_t TextSize = 0;
  uint32_t EFlags = 0;
  SmallVector<Reloc, 16> Relocs;
  SmallVector<LibraryReloc, 8> LibraryRelocs;
  SmallVector<NameSection, 2> NameSections;
  SmallVector<Immutable, 4> Immutables;
};

/// One input object, read in place out of the caller's buffer.
struct Input {
  std::unique_ptr<Binary> Bin;
  const ObjectFile *File = nullptr;
  std::string IdHash;
  /// '.text' contents, empty when absent.
  StringRef Text;
  /// Where '.text' lands in the output.
  uint64_t OutTextOffset = 0;
  /// Whether the layout includes this object.
  bool Included = false;
};

/// Returns the relocation section targeting '.text', or the end iterator.
static section_iterator findTextRelocations(const ObjectFile &File) {
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

/// Returns true when \p File holds a runtime code segment, which the
/// compiler marks in the ELF header.
static bool isRuntimeObject(const ObjectFile &File) {
  return cast<ELFObjectFileBase>(&File)->getPlatformFlags() &
         ELF::EF_EVM_RUNTIME;
}

/// Records a 20-byte library address in \p LibraryAddresses, keyed by the
/// '__linker_symbol' name the MC layer emits the relocation against.
static void defineLinkerSymbol(StringMap<LibraryAddress> &LibraryAddresses,
                               StringRef Name,
                               const char Value[LLVM_EVM_LINKER_SYMBOL_SIZE]) {
  LibraryAddress &Addr = LibraryAddresses[EVM::getLinkerSymbolName(Name)];
  std::memcpy(Addr.data(), Value, LLVM_EVM_LINKER_SYMBOL_SIZE);
}

/// Resolves a library address relocation: 20 bytes at \p Where, written when
/// \p LibraryAddresses defines the symbol, carried into the output when it
/// does not or when it is null.
static void
resolveLibraryAddress(const StringMap<LibraryAddress> *LibraryAddresses,
                      const SymbolRef &Sym, const RelocationRef &Rel,
                      uint64_t Where, Output &Out) {
  assert(EVM::isReferenceSymbol(Sym) &&
         "library address relocation against a non-ref symbol");
  assert(cantFail(ELFRelocationRef(Rel).getAddend()) == 0 &&
         "library address relocation with an addend");
  const StringRef SymName = cantFail(Sym.getName());
  if (LibraryAddresses) {
    const auto It = LibraryAddresses->find(SymName);
    if (It != LibraryAddresses->end()) {
      Out.Relocs.emplace_back(Where, LLVM_EVM_LINKER_SYMBOL_SIZE, It->second);
      return;
    }
  }
  Out.LibraryRelocs.emplace_back(Where, SymName);
}

/// Resolves a '__dataoffset' or '__datasize' relocation: a 32-bit value
/// \p SymValues defined from the layout, written at \p Where. A miss means
/// the code references an object the driver did not pass, which is a bug in
/// the driver.
static void resolveDataSymbol(const StringMap<uint32_t> &SymValues,
                              const SymbolRef &Sym, const RelocationRef &Rel,
                              uint64_t Where, Output &Out) {
  const StringRef SymName = cantFail(Sym.getName());
  const auto It = SymValues.find(SymName);
  if (It == SymValues.end())
    report_fatal_error(Twine("non-ref undefined symbol: ") + SymName);
  assert(cantFail(ELFRelocationRef(Rel).getAddend()) == 0 &&
         "data relocation with an addend");
  RelocValue Value;
  write32be(Value.data(), It->second);
  Out.Relocs.emplace_back(Where, sizeof(uint32_t), Value);
}

/// Resolves the relocations of \p In, placed at its offset in the output,
/// against \p SymValues or \p LibraryAddresses, which is null at assembly
/// time, when no library address is known yet.
static void resolve(const Input &In, const StringMap<uint32_t> &SymValues,
                    const StringMap<LibraryAddress> *LibraryAddresses,
                    Output &Out) {
  const section_iterator Rela = findTextRelocations(*In.File);
  if (Rela == In.File->section_end())
    return;

  for (const RelocationRef &Rel : Rela->relocations()) {
    const uint64_t Type = Rel.getType();
    assert((Type == ELF::R_EVM_DATA || Type == ELF::R_EVM_DATA_160) &&
           "unexpected relocation type");
    const symbol_iterator Sym = Rel.getSymbol();
    assert(Sym != In.File->symbol_end() && "relocation without a symbol");
    assert((cantFail(Sym->getFlags()) & SymbolRef::SF_Undefined) &&
           "relocation against a defined symbol");
    const uint64_t Size = Type == ELF::R_EVM_DATA_160
                              ? LLVM_EVM_LINKER_SYMBOL_SIZE
                              : sizeof(uint32_t);
    // The patched bytes must lie inside the object's own code. The sum
    // cannot overflow: 'r_offset' is 32 bits and 'Size' is at most 20.
    if (Rel.getOffset() + Size > In.Text.size())
      report_fatal_error("relocation out of range");
    const uint64_t Where = In.OutTextOffset + Rel.getOffset();

    if (Type == ELF::R_EVM_DATA_160)
      resolveLibraryAddress(LibraryAddresses, *Sym, Rel, Where, Out);
    else
      resolveDataSymbol(SymValues, *Sym, Rel, Where, Out);
  }
}

/// Collects the '.symbol_name...' sections of \p File into \p Out, skipping
/// those already there. Several objects referring to the same library carry
/// the same section, and the output holds one of each.
static void collectNameSections(const ObjectFile &File, StringSet<> &Seen,
                                Output &Out) {
  for (const SectionRef &Sec : File.sections()) {
    const StringRef Name = cantFail(Sec.getName());
    if (!EVM::isSymbolSectionName(Name) || !Seen.insert(Name).second)
      continue;
    Out.NameSections.emplace_back(Name, cantFail(Sec.getContents()));
  }
}

/// Collects the immutable symbols of \p File into \p Out.
static void collectImmutables(const ObjectFile &File, Output &Out) {
  for (const SymbolRef &Sym : File.symbols()) {
    const StringRef Name = cantFail(Sym.getName());
    if (EVM::isLoadImmutableSymbolName(Name))
      Out.Immutables.emplace_back(
          Name, static_cast<uint32_t>(cantFail(Sym.getValue())));
  }
}

/// Copies the segments of the output '.text' to \p Text and writes the
/// resolved relocations over them.
static void writeText(char *Text, const Output &Out) {
  for (const OutTextSegment &S : Out.Segments) {
    if (!S.Data.empty())
      std::memcpy(Text + S.Offset, S.Data.data(), S.Data.size());
  }
  for (const Reloc &R : Out.Relocs)
    std::memcpy(Text + R.Offset, R.Value.data(), R.Size);
}

/// Writes the bytecode of \p Out, which has nothing left unresolved.
static std::unique_ptr<WritableMemoryBuffer> writeBytecode(const Output &Out,
                                                           StringRef Name) {
  std::unique_ptr<WritableMemoryBuffer> Buf =
      WritableMemoryBuffer::getNewUninitMemBuffer(Out.TextSize, Name);
  writeText(Buf->getBufferStart(), Out);
  return Buf;
}

/// Writes \p Out as a relocatable ELF32 big-endian EVM object: '.text', its
/// relocations, the sections naming the libraries they refer to, the symbol
/// table and the string tables. The records are the endian-aware structs of
/// ELFTypes.h, so a plain byte write of them is big-endian.
///
/// The symbol table holds the immutable symbols, which are local, and then one
/// undefined symbol per library still to be resolved, which is global.
///
/// The file has the shape the ELF reference defines for a relocatable object.
static std::unique_ptr<WritableMemoryBuffer> writeObject(const Output &Out,
                                                         StringRef Name) {
  using ELFT = object::ELF32BE;
  using Elf_Ehdr = ELFT::Ehdr;
  using Elf_Shdr = ELFT::Shdr;
  using Elf_Sym = ELFT::Sym;
  using Elf_Rela = ELFT::Rela;

  // The symbols. The ELF reference requires index 0 to be the all-zero null
  // symbol (STN_UNDEF) and every local symbol to precede every global one.
  std::vector<Elf_Sym> Symbols(1);
  std::memset(Symbols.data(), 0, sizeof(Elf_Sym));
  StringTableBuilder StrTab(StringTableBuilder::ELF);
  auto AddSymbol = [&](StringRef SymName) -> Elf_Sym & {
    StrTab.add(SymName);
    Elf_Sym &Sym = Symbols.emplace_back();
    std::memset(&Sym, 0, sizeof(Elf_Sym));
    return Sym;
  };
  for (const Immutable &Imm : Out.Immutables) {
    Elf_Sym &Sym = AddSymbol(Imm.Name);
    Sym.setBindingAndType(ELF::STB_LOCAL, ELF::STT_NOTYPE);
    Sym.st_value = Imm.Value;
  }
  const unsigned NumLocals = Symbols.size();

  SmallVector<StringRef, 4> LibrarySymbols;
  StringSet<> SeenLibrarySymbols;
  for (const LibraryReloc &Rel : Out.LibraryRelocs) {
    if (SeenLibrarySymbols.insert(Rel.Sym).second)
      LibrarySymbols.push_back(Rel.Sym);
  }
  sort(LibrarySymbols);
  StringMap<uint32_t> SymbolIndex;
  for (const StringRef LibrarySymbol : LibrarySymbols) {
    SymbolIndex[LibrarySymbol] = Symbols.size();
    Elf_Sym &Sym = AddSymbol(LibrarySymbol);
    Sym.setBindingAndType(ELF::STB_GLOBAL, ELF::STT_NOTYPE);
    Sym.st_other = ELF::STO_EVM_REFERENCE_SYMBOL;
  }
  // 'st_name' is not a string but an offset into '.strtab', known once the
  // table is final.
  StrTab.finalizeInOrder();
  {
    unsigned Idx = 1;
    for (const Immutable &Imm : Out.Immutables)
      Symbols[Idx++].st_name = StrTab.getOffset(Imm.Name);
    for (const StringRef LibrarySymbol : LibrarySymbols)
      Symbols[Idx++].st_name = StrTab.getOffset(LibrarySymbol);
  }

  // The relocation records of the library addresses still to be resolved.
  // 'r_offset' says where in '.text' to patch, and 'r_info' packs the symbol
  // table index with the relocation type.
  std::vector<Elf_Rela> Relas;
  for (const LibraryReloc &LibRel : Out.LibraryRelocs) {
    Elf_Rela &Rel = Relas.emplace_back();
    Rel.r_offset = static_cast<uint32_t>(LibRel.Offset);
    Rel.setSymbolAndType(SymbolIndex[LibRel.Sym], ELF::R_EVM_DATA_160,
                         /*IsMips64EL=*/false);
    Rel.r_addend = 0;
  }
  const bool HasRelocs = !Relas.empty();

  // The name sections of the libraries still referred to.
  StringSet<> WantedNames;
  for (const StringRef LibrarySymbol : LibrarySymbols)
    WantedNames.insert(EVM::getSymbolSectionName(LibrarySymbol));
  SmallVector<const NameSection *, 2> WantedSections;
  for (const NameSection &Sec : Out.NameSections) {
    if (WantedNames.contains(Sec.Name))
      WantedSections.push_back(&Sec);
  }

  // The section headers, in file order, and the string table naming them.
  // The ELF reference requires index 0 to be the all-zero null section
  // (SHN_UNDEF).
  SmallVector<Elf_Shdr, 8> Sections;
  SmallVector<StringRef, 8> SectionNames;
  StringTableBuilder ShStrTab(StringTableBuilder::ELF);
  auto AddSection = [&](StringRef SecName, uint32_t Type, uint32_t Flags,
                        uint32_t Size, uint32_t Align,
                        uint32_t EntSize) -> Elf_Shdr & {
    ShStrTab.add(SecName);
    SectionNames.push_back(SecName);
    Elf_Shdr &Sec = Sections.emplace_back();
    std::memset(&Sec, 0, sizeof(Elf_Shdr));
    Sec.sh_type = Type;
    Sec.sh_flags = Flags;
    Sec.sh_size = Size;
    Sec.sh_addralign = Align;
    Sec.sh_entsize = EntSize;
    return Sec;
  };

  // The all-zero null section the ELF reference requires at index 0: its
  // type is SHT_NULL and every field of it is zero.
  AddSection("", ELF::SHT_NULL, 0, 0, 0, 0);

  AddSection(".text", ELF::SHT_PROGBITS, ELF::SHF_ALLOC | ELF::SHF_EXECINSTR,
             static_cast<uint32_t>(Out.TextSize), 1, 0);
  const uint32_t TextIdx = Sections.size() - 1;

  // The immutable symbols point into the output '.text'.
  for (unsigned Idx = 1; Idx < NumLocals; ++Idx)
    Symbols[Idx].st_shndx = static_cast<uint16_t>(TextIdx);

  uint32_t RelaIdx = 0;
  if (HasRelocs) {
    Elf_Shdr &Rela =
        AddSection(".rela.text", ELF::SHT_RELA, ELF::SHF_INFO_LINK,
                   static_cast<uint32_t>(Relas.size() * sizeof(Elf_Rela)), 4,
                   sizeof(Elf_Rela));
    // For a relocation section, 'sh_info' holds the index of the section
    // to which the relocations apply.
    Rela.sh_info = TextIdx;
    RelaIdx = Sections.size() - 1;
  }

  const uint32_t FirstNameIdx = Sections.size();
  for (const NameSection *Sec : WantedSections)
    AddSection(Sec->Name, ELF::SHT_PROGBITS, ELF::SHF_STRINGS,
               static_cast<uint32_t>(Sec->Data.size()), 1, 0);

  Elf_Shdr &SymTab =
      AddSection(".symtab", ELF::SHT_SYMTAB, 0,
                 static_cast<uint32_t>(Symbols.size() * sizeof(Elf_Sym)), 4,
                 sizeof(Elf_Sym));
  const uint32_t SymTabIdx = Sections.size() - 1;
  // For a symbol table, 'sh_info' holds the index of the first non-local
  // symbol. The locals come first, so it equals their count.
  SymTab.sh_info = NumLocals;
  // For a relocation section, 'sh_link' holds the index of the associated
  // symbol table, which is only known now.
  if (HasRelocs)
    Sections[RelaIdx].sh_link = SymTabIdx;

  AddSection(".strtab", ELF::SHT_STRTAB, 0,
             static_cast<uint32_t>(StrTab.getSize()), 1, 0);
  const uint32_t StrTabIdx = Sections.size() - 1;
  // For a symbol table, 'sh_link' holds the index of the string table with
  // the symbol names.
  Sections[SymTabIdx].sh_link = StrTabIdx;

  Elf_Shdr &ShStrTabSec = AddSection(".shstrtab", ELF::SHT_STRTAB, 0, 0, 1, 0);
  const uint32_t ShStrTabIdx = Sections.size() - 1;
  ShStrTab.finalizeInOrder();
  ShStrTabSec.sh_size = static_cast<uint32_t>(ShStrTab.getSize());
  // 'sh_name' is an offset into '.shstrtab', which names every section,
  // itself included.
  for (unsigned Idx = 1; Idx < Sections.size(); ++Idx)
    Sections[Idx].sh_name = ShStrTab.getOffset(SectionNames[Idx]);

  // The layout: each section lands at the next offset aligned to its
  // 'sh_addralign', and the section header table follows the last one,
  // word-aligned, at what becomes 'e_shoff'.
  uint32_t Offset = sizeof(Elf_Ehdr);
  for (Elf_Shdr &Sec : drop_begin(Sections)) {
    Offset = alignTo(Offset, Sec.sh_addralign);
    Sec.sh_offset = Offset;
    Offset += Sec.sh_size;
  }
  const uint32_t ShOff = alignTo(Offset, 4);

  // The ELF header: a big-endian 32-bit relocatable object for the EVM
  // machine.
  Elf_Ehdr Header;
  std::memset(&Header, 0, sizeof(Header));
  Header.e_ident[ELF::EI_MAG0] = 0x7f;
  Header.e_ident[ELF::EI_MAG1] = 'E';
  Header.e_ident[ELF::EI_MAG2] = 'L';
  Header.e_ident[ELF::EI_MAG3] = 'F';
  Header.e_ident[ELF::EI_CLASS] = ELF::ELFCLASS32;
  Header.e_ident[ELF::EI_DATA] = ELF::ELFDATA2MSB;
  Header.e_ident[ELF::EI_VERSION] = ELF::EV_CURRENT;
  Header.e_ident[ELF::EI_OSABI] = ELF::ELFOSABI_STANDALONE;
  Header.e_type = ELF::ET_REL;
  Header.e_machine = ELF::EM_EVM;
  Header.e_version = ELF::EV_CURRENT;
  Header.e_flags = Out.EFlags;
  Header.e_shoff = ShOff;
  Header.e_ehsize = sizeof(Elf_Ehdr);
  Header.e_shentsize = sizeof(Elf_Shdr);
  Header.e_shnum = static_cast<uint16_t>(Sections.size());
  Header.e_shstrndx = static_cast<uint16_t>(ShStrTabIdx);

  // Write it out: the structs and tables as bytes, padding in the gaps.
  SmallString<1024> Bytes;
  raw_svector_ostream OS(Bytes);
  auto PadTo = [&](uint64_t Target) { OS.write_zeros(Target - OS.tell()); };
  auto WriteStruct = [&](const auto &Record) {
    OS.write(reinterpret_cast<const char *>(&Record), sizeof(Record));
  };
  WriteStruct(Header);

  PadTo(Sections[TextIdx].sh_offset);
  SmallVector<char, 1024> Text(Out.TextSize);
  writeText(Text.data(), Out);
  OS.write(Text.data(), Text.size());

  if (HasRelocs) {
    PadTo(Sections[RelaIdx].sh_offset);
    for (const Elf_Rela &Rel : Relas)
      WriteStruct(Rel);
  }

  for (const auto &[Idx, Sec] : enumerate(WantedSections)) {
    PadTo(Sections[FirstNameIdx + Idx].sh_offset);
    OS << Sec->Data;
  }

  PadTo(Sections[SymTabIdx].sh_offset);
  for (const Elf_Sym &Sym : Symbols)
    WriteStruct(Sym);

  PadTo(Sections[StrTabIdx].sh_offset);
  StrTab.write(OS);

  PadTo(Sections[ShStrTabIdx].sh_offset);
  ShStrTab.write(OS);

  PadTo(ShOff);
  for (const Elf_Shdr &Sec : Sections)
    WriteStruct(Sec);
  assert(Bytes.size() == ShOff + Sections.size() * sizeof(Elf_Shdr));

  std::unique_ptr<WritableMemoryBuffer> Buf =
      WritableMemoryBuffer::getNewUninitMemBuffer(Bytes.size(), Name);
  std::memcpy(Buf->getBufferStart(), Bytes.data(), Bytes.size());
  return Buf;
}

} // namespace

LLVMMemoryBufferRef LLVMAssembleEVM(const LLVMMemoryBufferRef inBuffers[],
                                    const char *const inBuffersIDs[],
                                    uint64_t inBuffersNum, const char *metadata,
                                    uint64_t metadataSize) {
  if (inBuffersNum == 0)
    report_fatal_error("assembly: no input");

  // Read every input in place. Nothing is copied here: the ELF reader keeps
  // references into the caller's buffers.
  SmallVector<Input, 4> Inputs(inBuffersNum);
  for (uint64_t Idx = 0; Idx < inBuffersNum; ++Idx) {
    Input &In = Inputs[Idx];
    In.IdHash = EVM::getLinkerSymbolHash(inBuffersIDs[Idx]);
    In.Bin = cantFail(createBinary(*unwrap(inBuffers[Idx])));
    In.File = cast<ObjectFile>(In.Bin.get());
    In.Text = EVM::findSection(*In.File, ".text");
  }

  // The first object names the dependencies it reaches through '__dataoffset';
  // the layout includes those and nothing else.
  StringSet<> Referenced;
  bool FirstLoadsImmutables = false;
  for (const SymbolRef &Sym : Inputs[0].File->symbols()) {
    const StringRef Name = cantFail(Sym.getName());
    if (EVM::isLoadImmutableSymbolName(Name))
      FirstLoadsImmutables = true;
    else if (EVM::isDataOffsetSymbolName(Name))
      Referenced.insert(EVM::extractDataOffseteName(Name));
  }

  // Deploy code cannot load immutables: nothing patches the deploy code
  // before it runs, so a load site in it is a codegen bug. The frontend
  // lowers creation-time immutable reads through memory instead.
  if (!isRuntimeObject(*Inputs[0].File) && FirstLoadsImmutables)
    report_fatal_error("assembly: the deploy code loads immutables");

  // Lay the sections out at address zero, in input order, and define the
  // '__dataoffset' and '__datasize' symbols the layout determines. The
  // metadata follows the code, and the first object's '__datasize' covers it
  // all.
  Output Out;
  Out.EFlags = cast<ELFObjectFileBase>(Inputs[0].File)->getPlatformFlags();
  StringMap<uint32_t> SymValues;
  for (uint64_t Idx = 0; Idx < inBuffersNum; ++Idx) {
    Input &In = Inputs[Idx];
    if (Idx != 0) {
      SymValues[EVM::getDataSizeSymbol(In.IdHash)] =
          static_cast<uint32_t>(In.Text.size());
      if (!Referenced.contains(In.IdHash))
        continue;
    }
    In.Included = true;
    In.OutTextOffset = Out.TextSize;
    SymValues[EVM::getDataOffsetSymbol(In.IdHash)] =
        static_cast<uint32_t>(Out.TextSize);
    Out.Segments.emplace_back(In.Text, Out.TextSize);
    Out.TextSize += In.Text.size();
  }
  Out.Segments.emplace_back(StringRef(metadata, metadataSize), Out.TextSize);
  Out.TextSize += metadataSize;
  // Every offset of the output object must fit in an ELF32 field. Half the
  // range leaves room for everything that follows '.text' in the file.
  if (Out.TextSize > UINT32_MAX / 2)
    report_fatal_error("assembly: code too large for ELF32");
  SymValues[EVM::getDataSizeSymbol(Inputs[0].IdHash)] =
      static_cast<uint32_t>(Out.TextSize);

  StringSet<> SeenNameSections;
  for (const Input &In : Inputs) {
    if (!In.Included)
      continue;
    resolve(In, SymValues, /*LibraryAddresses=*/nullptr, Out);
    collectNameSections(*In.File, SeenNameSections, Out);
  }
  collectImmutables(*Inputs[0].File, Out);

  return wrap(writeObject(Out, Inputs[0].IdHash).release());
}

LLVMMemoryBufferRef
LLVMLinkEVM(LLVMMemoryBufferRef inBuffer, const char *const *linkerSymbolNames,
            const char linkerSymbolValues[][LLVM_EVM_LINKER_SYMBOL_SIZE],
            uint64_t numLinkerSymbols) {
  Input In;
  In.Bin = cantFail(createBinary(*unwrap(inBuffer)));
  In.File = cast<ObjectFile>(In.Bin.get());
  In.Text = EVM::findSection(*In.File, ".text");

  StringMap<LibraryAddress> LibraryAddresses;
  for (uint64_t Idx = 0; Idx < numLinkerSymbols; ++Idx)
    defineLinkerSymbol(LibraryAddresses, linkerSymbolNames[Idx],
                       linkerSymbolValues[Idx]);

  Output Out;
  Out.EFlags = cast<ELFObjectFileBase>(In.File)->getPlatformFlags();
  Out.Segments.emplace_back(In.Text, 0);
  Out.TextSize = In.Text.size();
  const StringMap<uint32_t> SymValues;
  resolve(In, SymValues, &LibraryAddresses, Out);

  if (Out.LibraryRelocs.empty())
    return wrap(writeBytecode(Out, "result").release());

  StringSet<> Seen;
  collectNameSections(*In.File, Seen, Out);
  collectImmutables(*In.File, Out);
  return wrap(writeObject(Out, "result").release());
}
