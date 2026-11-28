//===------- EVMLinker.h - EVM linker public C interface -------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This header declares the EVM C interfaces:
//  - 'LLVMAssembleEVM'
//    Lays out a contract's objects, resolves the symbols the layout defines
//    and the library addresses the caller provides, and produces the bytecode
//
//  - 'LLVMDisposeAssembleResultEVM'
//    Disposes what 'LLVMAssembleEVM' returned
//
//  - 'LLVMGetImmutablesEVM' / 'LLVMDisposeImmutablesEVM'
//    Returns the immutable load sites of an object
//
// These functions use a notion of the 'Linker Symbol': a library whose
// 20-byte address may be unknown at compile time. For a library named 'name',
// the LLVM MC layer emits one undefined ELF symbol
//
//   '__linker_symbol__$keccak256(name)$__'
//
// with one R_EVM_DATA_160 relocation per use, which covers the 20 bytes of
// a PUSH20 immediate. The MC layer also sets the
// ELF::STO_EVM_REFERENCE_SYMBOL flag in the 'st_other' field of the symbol
// table entry to distinguish such symbols from all others.
// In EVM, only these symbols are allowed to be undefined in an object
// code. All other cases must be treated as unreachable and denote a bug
// in the FE/LLVM codegen/Linker implementation.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_C_EVMLINKER_H
#define LLVM_C_EVMLINKER_H

#include "llvm-c/ExternC.h"
#include "llvm-c/Types.h"
#include "llvm-c/Visibility.h"

LLVM_C_EXTERN_C_BEGIN

// Currently, the size of a linker symbol is limited to 20 bytes, as its the
// only usage is to represent Ethereum addresses which are of 160 bit width.
#define LLVM_EVM_LINKER_SYMBOL_SIZE 20

/** A library whose address is known: the source name, e.g. 'file.sol:L',
 *  and the 20 address bytes. */
typedef struct {
  const char *Name;
  char Value[LLVM_EVM_LINKER_SYMBOL_SIZE];
} LLVMEVMLibrarySymbol;

/** Everything 'LLVMAssembleEVM' produces.
 *
 *  'Bytecode' is the final code. A library reference whose address was not
 *  provided stays as 20 zero bytes in it, reported through the unresolved
 *  arrays: one (name, offset) pair per use, the name being the library's
 *  source name and the offset pointing at the 20-byte slot in 'Bytecode'.
 *
 *  'ElfObject' is the relocatable ELF carrying the same '.text' as
 *  'Bytecode', with a relocation per unresolved library use.
 *
 *  'InputOffsets' describes the layout of each input in 'Bytecode', in
 *  'inBuffers' order: 'InputOffsets[i]' is where the '.text' of
 *  'inBuffers[i]' starts in 'Bytecode', or UINT64_MAX when the first
 *  object never references the input through '__dataoffset' and the
 *  layout left it out. The first input is always at offset zero.
 *  'NumInputs' equals 'inBuffersNum', and 'MetadataOffset' is where the
 *  metadata starts, ending 'Bytecode'. */
typedef struct {
  LLVMMemoryBufferRef Bytecode;
  LLVMMemoryBufferRef ElfObject;
  char **UnresolvedNames;
  uint64_t *UnresolvedOffsets;
  uint64_t NumUnresolved;
  uint64_t *InputOffsets;
  uint64_t NumInputs;
  uint64_t MetadataOffset;
} LLVMEVMAssembleResult;

/**
 * Performs the following steps, which are based on Ethereum's
 * Assembly::assemble() logic:
 *   - Concatenates the .text sections of input ELF files referenced
 *     by __dataoffset* symbols from the first file, and appends
 *     \p metadata to them.
 *   - Resolves undefined __dataoffset* and __datasize* symbols.
 *   - Resolves every library reference that \p librarySymbols covers, and
 *     reports the rest through the unresolved arrays of \p result.
 *   - Ensures that the first file does not load immutables unless it is a
 *     runtime code segment.
 *
 * Every failure is a bug in the compiler or in the driver, so it aborts
 * instead of returning.
 *
 * Whether an object holds deploy or runtime code is read from its ELF
 * header: the compiler sets EF_EVM_RUNTIME in 'e_flags' for the runtime
 * code segment, from the 'evm.runtime' named metadata.
 *
 * \p inBuffers - relocatable ELF files to be assembled, the first of which
 *                is the object being assembled
 * \p inBuffersIDs - their IDs
 * \p metadata - the bytes that end the code, \p metadataSize of them,
 *               which is 0 when there are none
 * \p librarySymbols - the known library addresses, \p numLibrarySymbols
 *                     of them
 * \p emitElfObject - whether to produce the relocatable 'ElfObject'. */
LLVM_C_ABI LLVMEVMAssembleResult LLVMAssembleEVM(
    const LLVMMemoryBufferRef inBuffers[], const char *const inBuffersIDs[],
    uint64_t inBuffersNum, const char *metadata, uint64_t metadataSize,
    const LLVMEVMLibrarySymbol *librarySymbols, uint64_t numLibrarySymbols,
    LLVMBool emitElfObject);

/** Releases every field of \p result that is not NULL. A caller that keeps
 *  a buffer sets the field to NULL before this call. */
LLVM_C_ABI void LLVMDisposeAssembleResultEVM(LLVMEVMAssembleResult *result);

/** Returns the immutable symbol names and their offsets from the ELF
 *  object file provided in \p inBuffer. */
LLVM_C_ABI uint64_t LLVMGetImmutablesEVM(LLVMMemoryBufferRef inBuffer,
                                         char ***immutableIDs,
                                         uint64_t **immutableOffsets);

/** Disposes of the immutable names and their offsets returned by
 *  'LLVMGetImmutablesEVM'. */
LLVM_C_ABI void LLVMDisposeImmutablesEVM(char **immutableIDs,
                                         uint64_t *immutableOffsets,
                                         uint64_t numOfImmutables);

LLVM_C_EXTERN_C_END

#endif // LLVM_C_EVMLINKER_H
