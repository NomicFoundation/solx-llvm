//===- HelperSymbols.h - Symbols of out-of-line helpers ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares the generators of the `__sol.*` symbols under which the
// Sol-to-Yul lowering emits its shared helper functions.
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_CONVERSION_SOLTOYUL_HELPERSYMBOLS_H
#define MLIR_CONVERSION_SOLTOYUL_HELPERSYMBOLS_H

#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/IR/TypeRange.h"
#include <string>

namespace mlir {
namespace evm {

/// Typed generators for out-of-line helper symbols.
namespace helpersym {
/// `__sol.copy_string.<src>.storage`
///
/// Emitted when a string or bytes value is assigned into storage from
/// memory, calldata or storage. Takes the source reference and the slot.
std::string copyStringToStorage(mlir::sol::DataLocation src);

/// `__sol.copy_struct.<src>.storage.<src name or ty>.<dst name or ty>`
///
/// Emitted for every struct copy into storage.
std::string copyStructToStorage(mlir::sol::DataLocation src,
                                mlir::sol::StructType srcTy,
                                mlir::sol::StructType ty);

/// `__sol.clone_struct.<src>.memory.<name or ty>`
///
/// Emitted for every struct copy into memory. Allocates the memory struct,
/// copies member by member and returns the new pointer.
std::string cloneStructToMemory(mlir::sol::DataLocation src,
                                mlir::sol::StructType ty);

/// `__sol.clone_string.storage.memory`
///
/// Emitted for an allocating copy of a storage string into memory.
std::string cloneStringToMemory();

/// `__sol.clone_array.<src>.memory.<ty>`
///
/// Emitted for an allocating copy of an array into memory that needs a loop.
/// Allocates the memory array, fills it element by element and returns the
/// new pointer.
std::string cloneArrayToMemory(mlir::sol::DataLocation src,
                               mlir::sol::ArrayType ty);

/// `__sol.copy_array.<src>.<dst>.<src ty>.<dst ty>`
///
/// Emitted for an array copy that cannot be one bulk copy.
std::string copyArray(mlir::sol::DataLocation src, mlir::sol::DataLocation dst,
                      mlir::sol::ArrayType srcTy, mlir::sol::ArrayType dstTy);

/// `__sol.clear_storage_struct.<name or ty>`
///
/// Emitted for `delete` of a storage struct.
std::string clearStorageStruct(mlir::sol::StructType ty);

/// `__sol.clear_storage_array.<ty>`
///
/// Emitted for `delete` of a storage array.
std::string clearStorageArray(mlir::sol::ArrayType ty);

/// `__sol.clear_storage_string_tail`
///
/// Emitted for a storage string assignment that may shrink the string, and
/// for `delete` of a storage string.
std::string clearStorageStringTail();

/// `__sol.copy_string_bytes.storage.memory`
///
/// Emitted whenever a storage string is read into memory.
/// Copies the raw bytes for both the inline and the out-of-place layout,
/// without writing the length word.
std::string copyStringBytesStorageToMemory();

/// `__sol.storage_string_length`
///
/// Emitted for every length read of a storage string or bytes.
std::string storageStringLength();

/// `__sol.alloc`
///
/// Emitted for every memory allocation whose byte size is not a compile-time
/// constant.
std::string alloc();

/// `__sol.alloc_array.<zeroed|uninit>.memory.<ty>`
///
/// Emitted when allocating a memory array whose elements are reference
/// types and no initial values are given.
std::string allocMemoryArray(bool zeroInit, mlir::sol::ArrayType ty);

/// `__sol.abi_decode.<calldata|memory>.memory.<ty>`
///
/// Emitted for ABI decoding into memory of an identified struct or a type
/// that needs a loop.
/// Decodes the value at the given address into fresh memory with bounds
/// checks and returns the pointer.
std::string abiDecodeToMemory(mlir::sol::DataLocation src, mlir::Type ty);

/// `__sol.abi_decode_calldata_slice`
///
/// Emitted for every `bytes calldata` or `string calldata` value decoded
/// from calldata.
std::string abiDecodeCalldataSlice();

/// `__sol.abi_decode_tuple.<calldata|memory>.<ty>...`
///
/// Emitted for every non-empty ABI tuple decoded from calldata or memory.
/// Takes the tuple start, end and returns the decoded values.
std::string abiDecodeTuple(mlir::sol::DataLocation src, mlir::TypeRange tys);

/// `__sol.abi_encode_array.memory.<padded|packed>.<tail|inplace>.<ty>`
///
/// Emitted for ABI encoding of a memory array whose elements cannot be bulk
/// copied.
std::string abiEncodeMemoryArray(bool padded, bool dynamicInplace,
                                 mlir::sol::ArrayType ty);

/// `__sol.abi_encode_tuple.<padded|packed>.<tail|inplace>.<ty>...`
///
/// Emitted for every non-empty ABI tuple encoded into memory.
std::string abiEncodeTuple(bool padded, bool dynamicInplace,
                           mlir::TypeRange tys);

/// `__sol.index_storage_array.<ty>[.nopanic]`
///
/// Emitted when indexing a storage array with a bounds check.
std::string indexStorageArray(mlir::sol::ArrayType arrTy, bool noPanicBounds);

/// `__sol.push_storage_string[.zero]`
///
/// Emitted for every `push` on a storage string or bytes: with a value, or
/// `.zero`.
std::string pushStorageString(bool zero);

/// `__sol.pop_storage_string`
///
/// Emitted for every `pop` on a storage string or bytes.
std::string popStorageString();

/// `__sol.push_storage_array.<ty>`
///
/// Emitted for every `push` on a storage array that is not a string or
/// bytes.
std::string pushStorageArray(mlir::sol::ArrayType ty);

/// `__sol.pop_storage_array.<ty>`
///
/// Emitted for every `pop` on a storage array that is not a string or bytes.
std::string popStorageArray(mlir::sol::ArrayType ty);

/// `__sol.panic`
///
/// Emitted for every panic.
std::string panic();

/// `__sol.revert.<selector>.<ty>...`
///
/// Emitted for every `revert` and `require` with a custom error, keyed by the
/// error's selector in hex followed by the Sol types of its arguments.
std::string revertError(llvm::StringRef signature, mlir::TypeRange tys);

/// `__sol.internal_dispatch.<index>`
///
/// Emitted for the calls through an internal function pointer of one lowered
/// signature, Unlike the other helpers it is a `yul.func`.
std::string internalDispatch(unsigned index);
} // namespace helpersym

} // namespace evm
} // namespace mlir

#endif // MLIR_CONVERSION_SOLTOYUL_HELPERSYMBOLS_H
