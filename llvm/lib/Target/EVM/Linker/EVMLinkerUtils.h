//===-- EVMLinkerUtils.h - Shared helpers of the EVM linker -----*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Helpers shared by EVMLinker.cpp and EVMLinkerQueries.cpp.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_EVM_LINKER_EVMLINKERUTILS_H
#define LLVM_LIB_TARGET_EVM_LINKER_EVMLINKERUTILS_H

#include "llvm/BinaryFormat/ELF.h"
#include "llvm/Object/ELFObjectFile.h"

namespace llvm {
namespace EVM {

/// Returns the contents of the named section, or an empty reference when it
/// is absent.
inline StringRef findSection(const object::ObjectFile &File, StringRef Name) {
  for (const object::SectionRef &Sec : File.sections()) {
    if (cantFail(Sec.getName()) == Name)
      return cantFail(Sec.getContents());
  }
  return StringRef();
}

/// Returns true when \p Sym is a library address symbol, which only the
/// linker can define.
inline bool isReferenceSymbol(const object::SymbolRef &Sym) {
  return object::ELFSymbolRef(Sym).getOther() == ELF::STO_EVM_REFERENCE_SYMBOL;
}

} // namespace EVM
} // namespace llvm

#endif // LLVM_LIB_TARGET_EVM_LINKER_EVMLINKERUTILS_H
