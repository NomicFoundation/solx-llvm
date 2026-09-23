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
#include "llvm/ADT/ArrayRef.h"
#include <string>

namespace mlir {
namespace evm {

/// Typed generators for out-of-line helper symbols. Every helper symbol is
/// produced by one of these. A symbol is the helper's fixed spelling and its
/// '.'-joined fields after the reserved "__sol." prefix. Two different
/// helpers can never produce the same symbol: each generator uses a distinct
/// spelling, the parts are separated by '.', and no field may contain '.'
/// (asserted). Solidity identifiers cannot contain '.' either, so no user
/// symbol can collide with a helper symbol.
namespace helpersym {
/// `__sol.copy_string.<src>.storage`
///
/// Emitted when a string or bytes value is assigned into storage from
/// memory, calldata or storage. Takes the source reference and the slot.
std::string copyStringToStorage(mlir::sol::DataLocation src);

/// `__sol.copy_struct.<src>.storage.<src name or ty>.<dst name or ty>`
///
/// Emitted for every struct copy into storage. Always
/// outlined: an identified struct may be self-referential, and the helper
/// recurses at runtime through the members. Copies member by member into an
/// existing storage slot. Both struct types are in the key, as the body
/// reads the members by the source layout and writes them by the
/// destination layout.
std::string copyStructToStorage(mlir::sol::DataLocation src,
                                mlir::sol::StructType srcTy,
                                mlir::sol::StructType ty);

/// `__sol.clone_struct.<src>.memory.<name or ty>`
///
/// Emitted for every struct copy into memory. Always outlined, as above.
/// Allocates the memory struct, copies member by member and returns the
/// new pointer.
std::string cloneStructToMemory(mlir::sol::DataLocation src,
                                mlir::sol::StructType ty);

/// `__sol.clone_array.<src>.memory.<ty>`
///
/// Emitted for an allocating copy of an array into memory that needs a loop:
/// any storage source, or a calldata source whose elements are not plain
/// 32-byte words. Allocates the memory array, fills it element by element and
/// returns the new pointer.
std::string cloneArrayToMemory(mlir::sol::DataLocation src,
                               mlir::sol::ArrayType ty);

/// `__sol.copy_array.<src>.<dst>.<src ty>.<dst ty>`
///
/// Emitted for an array copy that cannot be one bulk copy: a storage
/// destination, a storage source, or element types that differ or
/// are not word-sized. Loops over the elements, updates the length and
/// clears the tail of a storage destination. Inner rows of a nested array
/// share their own row helper.
std::string copyArray(mlir::sol::DataLocation src, mlir::sol::DataLocation dst,
                      mlir::sol::ArrayType srcTy, mlir::sol::ArrayType dstTy);

/// `__sol.clear_storage_struct.<name or ty>`
///
/// Emitted for `delete` of a storage struct, directly or as a member or
/// element of a value being cleared.
std::string clearStorageStruct(mlir::sol::StructType ty);

/// `__sol.clear_storage_array.<ty>`
///
/// Emitted for `delete` of a storage array, directly or as a member or
/// element of a value being cleared. Scalars and strings are cleared inline.
/// Zeroes the array slot by slot or element by element.
std::string clearStorageArray(mlir::sol::ArrayType ty);

/// `__sol.clear_storage_string_tail`
///
/// Emitted for a storage string assignment that may shrink the string, and
/// for `delete` of a storage string. Zeroes the out-of-place data slots
/// between the new and the old length.
std::string clearStorageStringTail();

/// `__sol.copy_string_bytes.storage.memory`
///
/// Emitted whenever a storage string is read into memory.
/// Copies the raw bytes for both the inline and the out-of-place layout,
/// without writing the length word.
std::string copyStringBytesStorageToMemory();

/// `__sol.alloc_array.<zeroed|uninit>.memory.<ty>`
///
/// Emitted when allocating a memory array whose elements are reference
/// types (arrays, structs, strings) and no initial values are given: a
/// static array, or a dynamic array at the outermost dimension with a
/// runtime length. A constant length such as `new T[](3)` stays inline.
/// Allocates the array and one row per element and returns the pointer.
std::string allocMemoryArray(bool zeroInit, mlir::sol::ArrayType ty);

/// `__sol.abi_decode.<calldata|memory>.memory.<ty>`
///
/// Emitted for ABI decoding into memory of a type that needs a loop: an
/// array whose elements are not word-sized, or a struct containing such an
/// array. Used for nested values below the tuple level. Decodes the value at
/// the given address into fresh memory with bounds checks and returns the
/// pointer.
std::string abiDecodeToMemory(bool fromMem, mlir::Type ty);

/// `__sol.abi_decode_tuple.<calldata|memory>.<ty>...`
///
/// Emitted for every non-empty ABI tuple decoded from calldata or memory:
/// a selector's parameters, `abi.decode`, an external call's returns, the
/// constructor's arguments. Takes the tuple start and end, checks the size,
/// resolves each element's head slot and decodes it, and returns the decoded
/// values. Loop-carrying elements call their \ref abiDecodeToMemory helper.
std::string abiDecodeTuple(bool fromMem, mlir::TypeRange tys);

/// `__sol.abi_encode_array.memory.<padded|packed>.<tail|inplace>.<ty>`
///
/// Emitted for ABI encoding of a memory array whose elements cannot be bulk
/// copied. The two mode fields come from ABIEncodingOptions: standard
/// padding or packed, and head-plus-tail or in-place body. Writes the array
/// element by element and returns the address after the last byte written.
std::string abiEncodeMemoryArray(bool padded, bool dynamicInplace,
                                 mlir::sol::ArrayType ty);

/// `__sol.abi_encode_tuple.<padded|packed>.<tail|inplace>.<ty>...`
///
/// Emitted for every non-empty ABI tuple encoded into memory: a selector's
/// returns, `abi.encode` and `abi.encodePacked`, an external call's
/// arguments, event data, revert data. The two mode fields come from
/// ABIEncodingOptions. Takes the values and the head start and returns the
/// address after the last byte written. Loop-carrying elements call their
/// \ref abiEncodeMemoryArray helper.
std::string abiEncodeTuple(bool padded, bool dynamicInplace,
                           mlir::TypeRange tys);

/// `__sol.index_storage_array.<ty>[.nopanic]`
///
/// Emitted when indexing a storage array with a bounds check. Checks the
/// index against the length, hashes the slot of a dynamic array and returns
/// the element slot, plus the byte offset for packed elements.
std::string indexStorageArray(mlir::sol::ArrayType arrTy, bool noPanicBounds);

/// `__sol.push_storage_array.<ty>`
///
/// Emitted for every `push` on a storage array that is not a string or
/// bytes. Increments the length and returns the address of the new element,
/// for packed and slot-aligned layouts.
std::string pushStorageArray(mlir::sol::ArrayType ty);

/// `__sol.pop_storage_array.<ty>`
///
/// Emitted for every `pop` on a storage array that is not a string or bytes.
/// Loads the length, panics if empty, clears the removed element and stores
/// the new length.
std::string popStorageArray(mlir::sol::ArrayType ty);

/// `__sol.dispatch_internal_call.<runtime|creation>.<id>...`
///
/// Emitted for a call through an internal function pointer with a non-empty
/// candidate set. The first field says whether the caller is runtime or
/// creation code. An empty candidate set panics inline. Switches on the
/// function id and calls the matching candidate, or panics on an invalid id.
std::string dispatchInternalCall(bool runtime,
                                 llvm::ArrayRef<int64_t> candidateIds);
} // namespace helpersym

} // namespace evm
} // namespace mlir

#endif // MLIR_CONVERSION_SOLTOYUL_HELPERSYMBOLS_H
