//===-- EVMLinkerQueries.cpp - Queries over EVM ELF objects ----*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Implements the query functions of the EVM linker C API. They inspect an
// ELF object without changing it: 'LLVMGetImmutablesEVM' and its dispose
// counterpart.
//
// The C API hands arrays to the caller, who frees them through the dispose
// functions, so the allocations here are malloc and strdup by contract.
//
//===----------------------------------------------------------------------===//

#include "llvm-c/EVMLinker.h"

#include "MCTargetDesc/EVMMCTargetDesc.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/Object/Binary.h"
#include "llvm/Object/ObjectFile.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/MemoryBuffer.h"

#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <memory>

using namespace llvm;
using namespace object;

/// Returns the immutable symbol names and their offsets from the ELF
/// object file provided in \p inBuffer.
uint64_t LLVMGetImmutablesEVM(LLVMMemoryBufferRef inBuffer,
                              char ***immutableIDs,
                              uint64_t **immutableOffsets) {
  std::unique_ptr<Binary> InBinary =
      cantFail(createBinary(unwrap(inBuffer)->getMemBufferRef()));
  const auto &File = *cast<ObjectFile>(InBinary.get());

  // Maps immutable IDs to their references in the object code.
  StringMap<SmallVector<uint64_t>> ImmutablesMap;
  for (const SymbolRef &Sym : File.symbols()) {
    const StringRef SymName = cantFail(Sym.getName());
    if (!EVM::isLoadImmutableSymbolName(SymName))
      continue;
    const uint64_t SymOffset = cantFail(Sym.getValue());
    // The symbol points to the beginning of a PUSH32 instruction.
    // We have to add 1 (opcode size) to get offset to the PUSH32
    // instruction operand.
    ImmutablesMap[EVM::getImmutableId(SymName)].push_back(SymOffset + 1);
  }

  if (ImmutablesMap.empty()) {
    *immutableIDs = nullptr;
    *immutableOffsets = nullptr;
    return 0;
  }

  uint64_t NumOfImmutables = 0;
  for (const auto &Entry : ImmutablesMap)
    NumOfImmutables += Entry.second.size();

  *immutableIDs =
      reinterpret_cast<char **>(std::malloc(NumOfImmutables * sizeof(char *)));
  *immutableOffsets = reinterpret_cast<uint64_t *>(
      std::malloc(NumOfImmutables * sizeof(uint64_t)));

  unsigned Idx = 0;
  for (const auto &[Id, Offsets] : ImmutablesMap) {
    for (const uint64_t Offset : Offsets) {
      assert(Idx < NumOfImmutables);
      (*immutableIDs)[Idx] = strdup(Id.str().c_str());
      (*immutableOffsets)[Idx++] = Offset;
    }
  }

  return NumOfImmutables;
}

/// Disposes of the immutable names and their offsets returned by
/// 'LLVMGetImmutablesEVM'.
void LLVMDisposeImmutablesEVM(char **immutableIDs, uint64_t *immutableOffsets,
                              uint64_t numOfImmutables) {
  for (unsigned Idx = 0; Idx < numOfImmutables; ++Idx)
    std::free(immutableIDs[Idx]);

  std::free(immutableIDs);
  std::free(immutableOffsets);
}
