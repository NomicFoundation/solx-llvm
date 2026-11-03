#include "lld-c/LLDAsLibraryC.h"
#include "llvm-c/Core.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/Object/Binary.h"
#include "llvm/Object/ELFObjectFile.h"
#include "llvm/Object/ObjectFile.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/MemoryBuffer.h"

#include <algorithm>
#include <array>
#include <cassert>
#include <cstdint>
#include <cstring>
#include <memory>
#include <string>

using namespace llvm;
using namespace object;

namespace llvm {
namespace EVM {
std::string getLinkerSymbolHash(StringRef SymName);
bool isLinkerSymbolName(StringRef Name);
std::string getLinkerSymbolName(StringRef SymName);
std::string getSymbolSectionName(StringRef Name);
std::string getSymbolIndexedName(StringRef Name, unsigned SubIdx);
std::string getNonIndexedSymbolName(StringRef Name);
bool isLoadImmutableSymbolName(StringRef Name);
std::string getImmutableId(StringRef Name);
} // namespace EVM
} // namespace llvm

enum class ReferenceSymbolType { Linker };

constexpr static unsigned subSymbolRelocSize = sizeof(uint32_t);

/// Returns reference to the section content. The section is expected
/// the be present in the file.
static StringRef getSectionContent(const ObjectFile &file,
                                   StringRef sectionName) {
  section_iterator si = std::find_if(file.section_begin(), file.section_end(),
                                     [&sectionName](const SectionRef &sec) {
                                       StringRef curSecName =
                                           cantFail(sec.getName());
                                       return curSecName == sectionName;
                                     });
  if (si == file.section_end())
    report_fatal_error(Twine("lld: expected ") + sectionName +
                       " in object file");

  return cantFail(si->getContents());
}

static std::string getLinkerSubSymbolName(StringRef name, unsigned idx) {
  return EVM::getSymbolIndexedName(
      EVM::getLinkerSymbolName(EVM::getLinkerSymbolHash(name)), idx);
}

/// Returns an array of names of undefined reference symbols in the
/// ELF object.
static char **LLVMGetUndefinedSymbols(const ObjectFile *oFile,
                                      uint64_t *numSymbols,
                                      ReferenceSymbolType symbolType) {
  StringSet<> undefSymbols;
  StringSet<> undefSubSymbols;
  for (const SymbolRef &sym : oFile->symbols()) {
    uint32_t symFlags = cantFail(sym.getFlags());
    uint8_t other = ELFSymbolRef(sym).getOther();
    if ((other == ELF::STO_EVM_REFERENCE_SYMBOL) &&
        (symFlags & object::SymbolRef::SF_Undefined)) {
      StringRef subName = cantFail(sym.getName());
      if (symbolType == ReferenceSymbolType::Linker &&
          EVM::isLinkerSymbolName(subName)) {
        undefSubSymbols.insert(subName);
        std::string symName = EVM::getNonIndexedSymbolName(subName);
        undefSymbols.insert(symName);
      }
    }
  }

  *numSymbols = undefSymbols.size();
  if (!undefSymbols.size())
    return nullptr;

  char **undefSymbolNames = reinterpret_cast<char **>(
      std::malloc(undefSymbols.size() * sizeof(char *)));
  unsigned undefSymIdx = 0;
  for (const StringSet<>::value_type &entry : undefSymbols) {
    StringRef symName = entry.first();
    // Check that 'undefSubSymbols' forms a set of groups each consisting of
    // five or eight sub-symbols depending on the symbol type.
    for (unsigned idx = 0; idx < LINKER_SYMBOL_SIZE / subSymbolRelocSize;
         idx++) {
      std::string subSymName = EVM::getSymbolIndexedName(symName, idx);
      if (!undefSubSymbols.contains(subSymName)) {
        report_fatal_error(Twine("lld: missing reference symbol ") +
                           subSymName);
      }
    }
    std::string secName = EVM::getSymbolSectionName(symName);
    undefSymbolNames[undefSymIdx++] =
        strdup(getSectionContent(*oFile, secName).str().c_str());
  }

  // Sort the returned names in lexicographical order.
  std::sort(
      undefSymbolNames, undefSymbolNames + *numSymbols,
      [](const char *s1, const char *s2) { return std::strcmp(s1, s2) < 0; });

  return undefSymbolNames;
}

/// Disposes an array with symbols returned by the
/// LLVMGetUndefinedReferences* functions.
void LLVMDisposeUndefinedReferences(char *symbolNames[], uint64_t numSymbols) {
  for (unsigned idx = 0; idx < numSymbols; ++idx)
    std::free(symbolNames[idx]);
  std::free(symbolNames);
}

/// Returns true if the \p inBuffer contains an EVM ELF object file.
LLVMBool LLVMIsELFEVM(LLVMMemoryBufferRef inBuffer) {
  Expected<ELFObjectFile<ELF32BE>> inBinaryOrErr =
      ELFObjectFile<ELF32BE>::create(unwrap(inBuffer)->getMemBufferRef());
  if (!inBinaryOrErr) {
    handleAllErrors(inBinaryOrErr.takeError(), [](const ErrorInfoBase &EI) {});
    return false;
  }
  return inBinaryOrErr.get().getArch() == Triple::evm;
}

/// Returns an array of undefined linker symbol names
/// from the ELF object provided in \p inBuffer.
void LLVMGetUndefinedReferencesEVM(LLVMMemoryBufferRef inBuffer,
                                   char ***linkerSymbols,
                                   uint64_t *numLinkerSymbols) {
  assert(linkerSymbols && numLinkerSymbols);
  *linkerSymbols = nullptr;
  *numLinkerSymbols = 0;
  if (!LLVMIsELFEVM(inBuffer))
    return;

  std::unique_ptr<Binary> inBinary =
      cantFail(createBinary(unwrap(inBuffer)->getMemBufferRef()));
  const auto *oFile = static_cast<const ObjectFile *>(inBinary.get());

  *linkerSymbols = LLVMGetUndefinedSymbols(oFile, numLinkerSymbols,
                                           ReferenceSymbolType::Linker);
}

/// Returns an array of offsets for the linker symbol relocations.
/// These are the symbol offsets in the generated bytecode.
uint64_t LLVMGetSymbolOffsetsEVM(LLVMMemoryBufferRef inBuffer,
                                 const char *symbolName,
                                 uint64_t **symbolOffsets) {
  std::unique_ptr<Binary> inBinary =
      cantFail(createBinary(unwrap(inBuffer)->getMemBufferRef()));
  auto *elfFile = static_cast<ELFObjectFileBase *>(inBinary.get());

  SmallVector<uint64_t> Offsets;
  // The relocation of a linker symbol is expressed as a sequence of
  // five consecutive 32-bit relocations. We need only the first one.
  std::string subSymName = getLinkerSubSymbolName(symbolName, 0);
  for (const ELFSectionRef relocsSec : elfFile->sections()) {
    // Find the relocation section. It should be .rela.text.
    if (relocsSec.relocations().empty() ||
        !cantFail(relocsSec.getRelocatedSection())->isText())
      continue;

    // Check relocations of the specified type.
    for (const ELFRelocationRef rel : relocsSec.relocations()) {
      if (rel.getType() != ELF::R_EVM_DATA)
        continue;

      elf_symbol_iterator sym = rel.getSymbol();
      uint32_t symFlags = cantFail(sym->getFlags());
      StringRef symName = cantFail(sym->getName());
      if ((sym->getOther() == llvm::ELF::STO_EVM_REFERENCE_SYMBOL) &&
          (symFlags & object::SymbolRef::SF_Undefined) &&
          (symName == subSymName))
        Offsets.push_back(rel.getOffset());
    }
  }

  *symbolOffsets = reinterpret_cast<uint64_t *>(
      std::malloc(Offsets.size() * sizeof(uint64_t)));

  sort(Offsets);
  copy(Offsets, *symbolOffsets);

  return Offsets.size();
}

/// Returns the immutable symbol names and their offsets from the ELF
/// object file provided in \p inBuffer.
uint64_t LLVMGetImmutablesEVM(LLVMMemoryBufferRef inBuffer,
                              char ***immutableIDs,
                              uint64_t **immutableOffsets) {
  std::unique_ptr<Binary> inBinary =
      cantFail(createBinary(unwrap(inBuffer)->getMemBufferRef()));
  const auto *objFile = static_cast<const ObjectFile *>(inBinary.get());

  // Maps immutable IDs to their references in the object code.
  StringMap<SmallVector<uint64_t>> immutablesMap;
  for (const SymbolRef &sym : objFile->symbols()) {
    section_iterator symSec = cantFail(sym.getSection());
    if (symSec == objFile->section_end())
      continue;

    StringRef symName = cantFail(sym.getName());
    if (EVM::isLoadImmutableSymbolName(symName)) {
      std::string Id = EVM::getImmutableId(symName);
      uint64_t symOffset = cantFail(sym.getValue());
      // The symbol points to the beginning of a PUSH32 instruction.
      // We have to add 1 (opcode size) to get offset to the PUSH32
      // instruction operand.
      immutablesMap[Id].push_back(symOffset + 1);
    }
  }

  if (immutablesMap.empty()) {
    *immutableIDs = nullptr;
    *immutableOffsets = nullptr;
    return 0;
  }

  uint64_t numOfImmutables = 0;
  for (const auto &[id, offsets] : immutablesMap) {
    numOfImmutables += offsets.size();
  };

  *immutableIDs =
      reinterpret_cast<char **>(std::malloc(numOfImmutables * sizeof(char *)));
  *immutableOffsets = reinterpret_cast<uint64_t *>(
      std::malloc(numOfImmutables * sizeof(uint64_t)));

  unsigned idx = 0;
  for (const auto &[id, offsets] : immutablesMap) {
    for (uint64_t offset : offsets) {
      assert(idx < numOfImmutables);
      (*immutableIDs)[idx] = strdup(id.str().c_str());
      (*immutableOffsets)[idx++] = offset;
    }
  }

  return numOfImmutables;
}

/// Disposes of the immutable names and their offsets returned by
/// 'LLVMGetImmutablesEVM'.
void LLVMDisposeImmutablesEVM(char **immutableIDs, uint64_t *immutableOffsets,
                              uint64_t numOfImmutables) {
  for (unsigned idx = 0; idx < numOfImmutables; ++idx)
    std::free(immutableIDs[idx]);

  std::free(immutableIDs);
  std::free(immutableOffsets);
}

void LLVMDisposeSymbolOffsetsEVM(uint64_t *offsets) { std::free(offsets); }
