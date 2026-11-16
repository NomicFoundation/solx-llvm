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
//    Lays out a contract's objects and resolves the symbols the layout defines
//
//  - 'LLVMLinkEVM'
//    Resolves the library addresses and produces the bytecode
//
//  - 'LLVMIsELFEVM'
//    Checks if the given memory buffer contains an ELF EVM object file
//
//  - 'LLVMGetUndefinedReferencesEVM'
//    Returns an array of undefined linker symbols
//
//  - 'LLVMDisposeUndefinedReferencesEVM'
//    Disposes an array returned by the 'LLVMGetUndefinedReferencesEVM'
//
// These functions use a notion of the 'Linker Symbol': a library whose
// 20-byte address is unknown at compile time. For a library named 'name',
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
// 'Linker Symbols' are resolved, i.e they receive their final 20-byte
// values, at the linkage stage when calling LLVMLinkEVM.
// For this, the 'LLVMLinkEVM' has parameters:
//  - \p linkerSymbolNames, array of null-terminated linker symbol names
//  - \p linkerSymbolValues, array of symbol values
//
// For example, if linkerSymbolNames[0] points to a string 'name', the 20-byte
// linkerSymbolValues[0] value is written over every relocation of the symbol
// '__linker_symbol__$keccak256(name)$__'.
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

/** Returns true if the \p inBuffer contains an EVM ELF object file. */
LLVM_C_ABI LLVMBool LLVMIsELFEVM(LLVMMemoryBufferRef inBuffer);

/**
 * Performs the following steps, which are based on Ethereum's
 * Assembly::assemble() logic:
 *   - Concatenates the .text sections of input ELF files referenced
 *     by __dataoffset* symbols from the first file, and appends
 *     \p metadata to them.
 *   - Resolves undefined __dataoffset* and __datasize* symbols.
 *   - Gathers the undefined linker symbols (library references) of
 *     the files the layout includes.
 *   - Ensures that the first file does not load and set
 *     immutables simultaneously.
 *
 * Returns the resulting relocatable object file. Every failure is a bug in
 * the compiler or in the driver, so it aborts instead of returning.
 *
 * Whether an object holds deploy or runtime code is read from its ELF
 * header: the compiler sets EF_EVM_RUNTIME in 'e_flags' for the runtime
 * code segment, from the 'evm.runtime' module flag.
 *
 * \p inBuffers - relocatable ELF files to be assembled, the first of which
 *                is the object being assembled
 * \p inBuffersIDs - their IDs
 * \p metadata - the bytes that end the code, \p metadataSize of them,
 *               which is 0 when there are none */
LLVM_C_ABI LLVMMemoryBufferRef LLVMAssembleEVM(
    const LLVMMemoryBufferRef inBuffers[], const char *const inBuffersIDs[],
    uint64_t inBuffersNum, const char *metadata, uint64_t metadataSize);

/** Returns an array of undefined linker symbol names
 *  from the ELF object provided in \p inBuffer. */
LLVM_C_ABI void LLVMGetUndefinedReferencesEVM(LLVMMemoryBufferRef inBuffer,
                                              char ***linkerSymbols,
                                              uint64_t *numLinkerSymbols);

/** Disposes of the array of symbols returned by the
 *  'LLVMGetUndefinedReferencesEVM' function. */
LLVM_C_ABI void LLVMDisposeUndefinedReferencesEVM(char *symbolNames[],
                                                  uint64_t numSymbols);

/** Resolves undefined linker symbols in the ELF object file \p inBuffer.
 *  Returns the ELF object file if any linker symbols remain unresolved;
 *  otherwise, returns the bytecode. Every failure is a bug in the compiler
 *  or in the driver, so it aborts instead of returning. */
LLVM_C_ABI LLVMMemoryBufferRef
LLVMLinkEVM(LLVMMemoryBufferRef inBuffer, const char *const *linkerSymbolNames,
            const char linkerSymbolValues[][LLVM_EVM_LINKER_SYMBOL_SIZE],
            uint64_t numLinkerSymbols);

/** Returns the immutable symbol names and their offsets from the ELF
 *  object file provided in \p inBuffer. */
LLVM_C_ABI uint64_t LLVMGetImmutablesEVM(LLVMMemoryBufferRef inBuffer,
                                         char ***immutableIDs,
                                         uint64_t **immutableOffsets);

/** Returns an array of offsets of the linker symbol relocations form the
 *  ELF object file provided in \p inBuffer. */
LLVM_C_ABI uint64_t LLVMGetSymbolOffsetsEVM(LLVMMemoryBufferRef inBuffer,
                                            const char *symbolName,
                                            uint64_t **symbolOffsets);

/** Disposes of the immutable names and their offsets returned by
 *  'LLVMGetImmutablesEVM'. */
LLVM_C_ABI void LLVMDisposeImmutablesEVM(char **immutableIDs,
                                         uint64_t *immutableOffsets,
                                         uint64_t numOfImmutables);

/** Releases the array of linker symbol offsets. */
LLVM_C_ABI void LLVMDisposeSymbolOffsetsEVM(uint64_t *offsets);

LLVM_C_EXTERN_C_END

#endif // LLVM_C_EVMLINKER_H
