//===- EVMUtil.h - EVM specific MLIR utilities ------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares EVM-specific MLIR utilities.
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_CONVERSION_SOLTOYUL_EVMUTIL_H
#define MLIR_CONVERSION_SOLTOYUL_EVMUTIL_H

#include "mlir/Conversion/SolToYul/EVMConstants.h"
#include "mlir/Conversion/SolToYul/Util.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/IR/Builders.h"
#include <memory>
#include <optional>

namespace mlir {
class TypeConverter;

namespace evm {

class StringLiteralPool;

enum AddrSpace : unsigned {
  AddrSpace_Stack = 0,
  AddrSpace_Heap = 1,
  AddrSpace_CallData = 2,
  AddrSpace_ReturnData = 3,
  AddrSpace_Code = 4,
  AddrSpace_Storage = 5,
  AddrSpace_TransientStorage = 6,
};

enum ByteLen {
  ByteLen_Byte = 1,
  ByteLen_X32 = 4,
  ByteLen_X64 = 8,
  ByteLen_EthAddr = 20,
  ByteLen_Field = 32
};

using AllocSize = int64_t;

/// Returns the alignment of `addrSpace`
unsigned getAlignment(AddrSpace addrSpace);
/// Returns the alignment of the LLVMPointerType value `ptr`
unsigned getAlignment(Value ptr);

/// Returns true when \p v is a compile-time constant. The type converter may
/// leave a single materialization cast over the constant, which is looked
/// through.
bool isConstantValue(Value v);

// FIXME: Remove this! The lowering should not expand the ABI encoding/decoding
// code (where this is used) involved in sol.contract, sol.emit etc. lowering.
// Instead it should generate a high level sol op that can have a custom
// lowering for each target.
/// MLIR version of solidity ast's Type::calldataHeadSize.
unsigned getCallDataHeadSize(Type ty);

/// Returns the memory address the creation code keeps `immOp` at until it sets
/// the immutables: a word per immutable after the scratch space.
int64_t getImmutableAddr(sol::ImmutableOp immOp);

/// Per-element iteration step. Unit depends on data location: memory-word
/// bytes for Memory/CallData, storage slots for Storage. 256-bit because a
/// storage element can itself be a huge static array.
llvm::APInt getArrayEltStride(sol::ArrayType arrTy);

/// Returns the size (in bytes) of static type without recursively calculating
/// the element type size.
int64_t getMallocSize(Type ty);

/// The longest string literal, in bytes, written as immediate words. A longer
/// one is cheaper to copy from the code, in gas and in code size.
constexpr uint64_t maxImmediateStringLiteralSize = 64;

/// ABI encoding knobs. Trimmed subset of upstream solc's `EncodingOptions` in
/// libsolidity/codegen/ABIFunctions.h:129-146 - only the two fields any type
/// branch currently consults are kept. The two common shapes
/// (`{padded=true, dynamicInplace=false}` for standard, `{padded=false,
/// dynamicInplace=true}` for packed) have wrappers (`genABIEncoding` /
/// `genABIEncodingPacked`); only uncommon callers spell out the struct.
///
/// Naming convention used in the implementation comments:
///  - "standard mode" / "standard encoding" => `dynamicInplace=false`. What
///    `abi.encode` produces: head + tail with offsets, length prefixes on
///    dynamic types.
///  - "packed mode" / "packed encoding"     => `dynamicInplace=true`. What
///    `abi.encodePacked` produces: single contiguous cursor, no offsets, no
///    length prefixes. `padded` varies within packed mode - false at the top
///    level, true inside containers after the recursive call site resets it
///    (upstream parity, see note below).
///
/// Container-element / struct-member recursion always forces `padded=true`,
/// mirroring upstream solc's `subOptions` reset in
/// `abiEncodingFunctionSimpleArray`, `abiEncodingFunctionCompactStorageArray`,
/// and `abiEncodingFunctionStruct`. This is spelled out at each recursive
/// call site rather than wrapped in a helper, since some sites additionally
/// force `dynamicInplace=false` (head/tail element calls) while others
/// preserve `dynamicInplace=true` (packed struct/array recursion).
struct ABIEncodingOptions {
  /// Pad value types to 32B (no MSB shift); zero-pad `bytes`/`string` payload
  /// to a 32B multiple; advance head by padded `calldataEncodedSize`.
  bool padded = true;
  /// Drop length prefix for dynamic arrays/`bytes`/`string`; encode
  /// struct/array body contiguously (no head + tail with offset words).
  bool dynamicInplace = false;
};

/// IR Builder for EVM specific lowering.
class Builder {
  // It's possible to provide a mlirgen::BuilderHelper member with same default
  // location, but then it becomes tricky to keep the default location behaviour
  // consistent.

  ModuleOp mod;
  OpBuilder &b;
  Location defLoc;
  StringLiteralPool *literals = nullptr;

public:
  explicit Builder(ModuleOp mod, OpBuilder &b, Location loc)
      : mod(mod), b(b), defLoc(loc) {
    assert(mod && "expected attached module for EVM builder");
  }

  /// For a lowering that writes the bytes of a literal from the source, whose
  /// globals come from \p literals.
  explicit Builder(ModuleOp mod, OpBuilder &b, Location loc,
                   StringLiteralPool &literals)
      : Builder(mod, b, loc) {
    this->literals = &literals;
  }

  /// Generates a pointer to the address in the heap.
  Value genHeapPtr(Value addr, std::optional<Location> locArg = std::nullopt);

  /// Generates a pointer to the address in the calldata.
  Value genCallDataPtr(Value addr,
                       std::optional<Location> locArg = std::nullopt);

  /// Generates a pointer to the address in the returndata.
  Value genReturnDataPtr(Value addr,
                         std::optional<Location> locArg = std::nullopt);

  /// Generates a pointer to the address in the storage.
  Value genStoragePtr(Value addr,
                      std::optional<Location> locArg = std::nullopt);

  /// Generates a pointer to the address in the transient storage.
  Value genTStoragePtr(Value addr,
                       std::optional<Location> locArg = std::nullopt);

  /// Generates a pointer to the address in the code.
  Value genCodePtr(Value addr, std::optional<Location> locArg = std::nullopt);

  //
  // The following APIs are used in the stage1 lowering.
  //
  // TODO? Some of these could be transformed to mlir ops instead. This would
  // allow targets to define custom lowering. For instance, some targets might
  // not need the `type(uint64).max` check in the memory allocation code
  // generated by the genMemAlloc APIs.
  //

  /// Generates the free pointer.
  ///
  /// NOTE! Watch out for free-ptr loads between this and the update!
  Value genFreePtr(std::optional<Location> locArg = std::nullopt);

  /// Generates the free pointer update code.
  void genFreePtrUpd(Value freePtr, Value size,
                     std::optional<Location> locArg = std::nullopt);

  /// Returns the address of \p size fresh bytes of memory. A constant size
  /// allocates inline, any other through `helpersym::alloc`.
  Value genMemAlloc(Value size, std::optional<Location> locArg = std::nullopt);
  Value genMemAlloc(AllocSize size,
                    std::optional<Location> locArg = std::nullopt);

  /// Generates the memory allocation code for dynamic array.
  Value genMemAllocForDynArray(Value sizeVar, Value sizeInBytes,
                               std::optional<Location> locArg = std::nullopt,
                               bool genLengthPanicGuard = false);

  /// Generates the memory allocation and initialization code for the
  /// memory-located aggregate type \p ty. Cleans the dirty high bits
  /// of \p sizeVar when its Solidity type \p sizeVarTy is provided.
  Value genMemAlloc(Type ty, bool zeroInit, ValueRange initVals, Value sizeVar,
                    Type sizeVarTy,
                    std::optional<Location> locArg = std::nullopt);

  /// Cleans up a promoted Solidity integer value according to width/sign.
  Value genIntCleanup(unsigned width, bool isSigned, Value val,
                      std::optional<Location> locArg = std::nullopt);

  /// Cleans up a Solidity scalar value. Scalar validation failures use
  /// ABI-style revert when \p shouldRevert is set; otherwise cleanup-time enum
  /// validation uses panic.
  Value genCleanup(Type ty, Value val,
                   std::optional<Location> locArg = std::nullopt,
                   bool shouldRevert = false);
  Value genCleanup(Type ty, Value val, std::optional<Location> locArg,
                   std::optional<sol::DataLocation> srcDataLoc);

private:
  /// Recursively generates the memory allocation and initialization code for
  /// the memory-located aggregate type \p ty (sol.array, sol.string or
  /// sol.struct) and returns the allocated address.
  ///
  /// \p sizeVar is the runtime element count (byte count for sol.string). It
  /// applies only to the outermost dimension: inner dynamically sized
  /// elements and members always start out empty, per Solidity's default
  /// value semantics.
  ///
  /// The data initialization is controlled by:
  /// - \p zeroInit: zero-fills value-type payloads and scalar struct members
  ///   (string/bytes members are pointed at the zero-pointer sentinel). When
  ///   unset, the caller must write every field before any read.
  /// - \p initVals: literal element values (from sol.array_lit lowering).
  ///   Value-type elements are cleaned up before the full-word stores, while
  ///   for arrays of aggregates the values are the addresses of inner
  ///   allocations made by other literal ops.
  ///
  /// \p recDepth tracks the recursion depth to identify the outermost
  /// dimension. It is pre-incremented on entry, so external callers pass -1
  /// (the public overload above does this).
  ///
  /// The allocation spans are word-rounded centrally in genFreePtrUpd.
  ///
  /// A static array with reference-typed elements (nested arrays, arrays of
  /// structs or strings) allocates its rows through genMemAllocArray. The
  /// public overload decides the same for the outermost dynamic array, whose
  /// length it has.
  Value genMemAlloc(Type ty, bool zeroInit, ValueRange initVals, Value sizeVar,
                    int64_t recDepth,
                    std::optional<Location> locArg = std::nullopt);

  /// The inline expansion behind genMemAlloc. Element allocations go back
  /// through genMemAlloc, so nested rows share their helper.
  Value genMemAllocInline(Type ty, bool zeroInit, ValueRange initVals,
                          Value sizeVar, int64_t recDepth, Location loc);

  /// The free pointer read and update behind genMemAlloc(Value).
  Value genAllocInline(Value size, Location loc);

  /// The row allocation of \p arrTy as `helpersym::allocMemoryArray`.
  /// \p sizeVar is the length of a dynamic array and null for a static one.
  Value genMemAllocArray(sol::ArrayType arrTy, bool zeroInit, Value sizeVar,
                         int64_t recDepth, Location loc);

  void genRevertInline(TypeRange tys, ValueRange vals, StringRef signature,
                       Location loc);

  /// The checks and loads behind `helpersym::abiDecodeCalldataSlice`: the
  /// data address and the length of the calldata slice whose length word is
  /// at \p addr, bounded by \p tupleEnd.
  Value genCalldataSliceDecodeInline(Value addr, Value tupleEnd, Location loc);

  /// Recursive primitive for `genABIEncoding` covering the full type taxonomy
  /// parameterised by `opts`. `dstAddrInTail`, `tupleStart`, `tailAddr` are
  /// meaningful only when `opts.dynamicInplace=false`.
  Value genABIEncodingImpl(Type ty, Value src, Value dstAddr,
                           ABIEncodingOptions opts, bool dstAddrInTail,
                           Value tupleStart, Value tailAddr, Location loc,
                           std::optional<sol::DataLocation> srcDataLoc);

  /// The inline expansion behind genABIEncodingImpl. A memory array that
  /// needs a loop is encoded by `helpersym::abiEncodeMemoryArray`. Elements
  /// recurse through genABIEncodingImpl so rows share their helper.
  /// \p arrayLength, when set, is the length of the dynamic array \p src and
  /// is used instead of loading it. The encode helper takes it as an
  /// argument so that a compile-time constant length still folds after the
  /// helper is inlined back.
  Value genABIEncodingImplInline(Type ty, Value src, Value dstAddr,
                                 ABIEncodingOptions opts, bool dstAddrInTail,
                                 Value tupleStart, Value tailAddr, Location loc,
                                 std::optional<sol::DataLocation> srcDataLoc,
                                 Value arrayLength = {});

  /// Zeroes storage slots in the out-of-place data area of a storage
  /// string/bytes at \p dstAddr that are no longer needed when the content
  /// changes from \p oldLength to \p newLength bytes.  Called only when
  /// \p oldLength > 31 (i.e. the old value used out-of-place storage).
  void genClearStringStorageTail(
      mlir::Value dstAddr, mlir::Value oldLength, mlir::Value newLength,
      std::optional<mlir::Location> locArg = std::nullopt);

  /// Inline expansion behind genClearStringStorageTail.
  void genClearStringStorageTailInline(mlir::Value dstAddr,
                                       mlir::Value oldLength,
                                       mlir::Value newLength,
                                       mlir::Location loc);

  /// Copies \p length bytes from \p srcAddr in \p srcDataLoc (memory or
  /// calldata) to \p dstAddr in memory with one mcopy or calldatacopy. With
  /// \p withCleanup, zeroes the word at dstAddr + length so the padding of a
  /// variable-length copy is canonical.
  void genBulkCopy(Value dstAddr, Value srcAddr, Value length,
                   sol::DataLocation srcDataLoc, Location loc,
                   bool withCleanup = false);

  /// Copies \p count 32-byte words from \p srcAddr in \p srcDataLoc
  /// (memory or calldata) to \p dstAddr in memory with one mcopy or
  /// calldatacopy.
  void genBulkWordCopy(Value dstAddr, Value srcAddr, Value count,
                       sol::DataLocation srcDataLoc, Location loc);

  void genCopyStringToStorageInline(mlir::Value src, mlir::Type ty,
                                    mlir::Value dstAddr, mlir::Location loc);

  void genCopyConstantStringToStorageInline(llvm::StringRef bytes,
                                            mlir::Value dstAddr,
                                            mlir::Location loc);

  /// Inline expansion behind genCopyStringDataFromStorageToMemory.
  void genCopyStringDataFromStorageToMemoryInline(mlir::Value src,
                                                  mlir::Value lengthSlot,
                                                  mlir::Value length,
                                                  mlir::Value dstDataAddr,
                                                  mlir::Location loc);

  /// Returns the number of storage slots occupied by \p len elements of type
  /// \p eltTy: ceil(len / elemsPerSlot) for packable types, len * slotsPerElt
  /// for non-packable types.
  mlir::Value
  genStorageArraySlotCount(mlir::Value len, mlir::Type eltTy,
                           std::optional<mlir::Location> locArg = std::nullopt);

  /// Resizes a dynamic storage array: writes \p newLen to \p arraySlot,
  /// then zeroes any storage slots that fall outside the new range if the
  /// array shrank. Panics (ResourceError) if \p newLen exceeds
  /// type(uint64).max.
  void
  genResizeDynStorageArray(mlir::Value arraySlot, mlir::Value newLen,
                           mlir::Type eltTy,
                           std::optional<mlir::Location> locArg = std::nullopt);

  /// Inline expansion behind genClearStorageValue: zeroes the storage for \p ty
  /// at \p slot, recursing through genClearStorageValue for aggregate members
  /// so that nested identified structs are dispatched to their out-of-line
  /// helper.
  void genClearStorageValueInline(mlir::Type ty, mlir::Value slot,
                                  mlir::Location loc);

  /// Inline expansion behind genCopy for a struct destined to memory: copies
  /// each member from \p srcAddr (data location \p srcDataLoc) into the
  /// allocated member table at \p dstAddr, cloning aggregate members through
  /// genCloneToMemory.
  void genStructToMemoryCopyInline(mlir::sol::StructType structTy,
                                   mlir::Value srcAddr, mlir::Value dstAddr,
                                   mlir::sol::DataLocation srcDataLoc,
                                   mlir::Location loc);

  /// Inline expansion behind genCopy for a struct destined to storage: copies
  /// each member from \p srcAddr (data location \p srcDataLoc) to \p dstAddr in
  /// storage, recursing through genCopy for aggregate members so that nested
  /// identified structs are dispatched to their out-of-line helper.
  void genStructToStorageCopyInline(mlir::sol::StructType srcStructTy,
                                    mlir::sol::StructType dstStructTy,
                                    mlir::Value srcAddr, mlir::Value dstAddr,
                                    mlir::sol::DataLocation srcDataLoc,
                                    mlir::Location loc);

  /// Generates a revert with message.
  void genRevertWithMsg(std::string const &msg,
                        std::optional<Location> locArg = std::nullopt);
  void genRevertWithMsg(Value cond, std::string const &msg,
                        std::optional<Location> locArg = std::nullopt);

  /// Decodes the length of the inline and the out-of-place layout from the
  /// loaded \p lengthSlot and panics on an encoding that is neither.
  Value genStorageStringLengthInline(Value lengthSlot, Location loc);

  /// Returns the byte length of the string at \p src (any data location
  /// encoded in \p ty) and, for a storage source, the loaded length slot,
  /// which also holds the bytes of a short string. Null otherwise.
  std::pair<Value, Value> genStringLength(Value src, Type ty, Location loc);

  /// Copies the \p length bytes of the string at \p src (any data location
  /// encoded in \p ty, \p lengthSlot as returned by genStringLength) into the
  /// already-allocated memory area \p dstDataAddr (the address past the
  /// length word). Does not write the length word. When \p withCleanup is
  /// true, emits a trailing zero-word cleanup store at dstDataAddr + length.
  void genCopyStringBytesToMemory(Value src, Type ty, Value lengthSlot,
                                  Value length, Value dstDataAddr, Location loc,
                                  bool withCleanup = false);

  /// The inline expansion behind genCopy. Returns the destination. A null
  /// \p dstAddr with a memory destination is a clone: the object is
  /// allocated here, from the length read off the source, and returned.
  /// Reference elements and members of a memory destination are cloned in
  /// turn through genCloneToMemory.
  Value genCopyInline(mlir::Type srcTy, mlir::Type dstTy, mlir::Value srcAddr,
                      mlir::Value dstAddr, mlir::sol::DataLocation srcDataLoc,
                      mlir::sol::DataLocation dstDataLoc, mlir::Location loc);

  Value genABIEncodingInline(TypeRange tys, ValueRange vals, Value startAddr,
                             ABIEncodingOptions opts, Location loc);

  Value genABITupleDecodingInline(Type ty, Value addr, bool fromMem,
                                  Value tupleEnd, bool topLevel, Location loc);

  void genABITupleDecodingInline(TypeRange tys, Value tupleStart,
                                 Value tupleEnd, std::vector<Value> &results,
                                 bool fromMem, Location loc);

public:
  //
  // TODO? Should we work with the high level types + OpAdaptor for the APIs
  // that work with low level integral type pointers?
  //

  /// Generates a low level integral type pointer to the address holding the
  /// data of a dynamic allocation.
  Value genDataAddrPtr(Value addr, Type ty,
                       std::optional<Location> locArg = std::nullopt);
  Value genDataAddrPtr(Value addr, sol::DataLocation dataLoc,
                       std::optional<Location> locArg = std::nullopt);

  /// Extracts the leading fixed-bytes value from a dynamic bytes type.
  Value genDynBytesToFixedBytes(Value src, Type srcTy,
                                sol::FixedBytesType dstTy,
                                std::optional<Location> locArg = std::nullopt);

  /// Generates the address computation of the array or string at index.
  // TODO: Data-location should be fetched from the type! Implement APIs to
  // "clone" reference types with different data-locations.
  Value genAddrAtIdx(Value baseAddr, Value idx, Type ty,
                     sol::DataLocation dataLoc,
                     std::optional<Location> locArg = std::nullopt);

  /// Resolves a calldata relative-offset pointer (\p ptr) to the effective
  /// address of a dynamically-encoded ABI element, with bounds validation.
  /// \p baseAddr is the absolute start of the enclosing calldata head section.
  ///
  /// - Dynamic arrays / strings / bytes: returns {dataPtr, length} fat pointer.
  /// - Fixed-size arrays with dynamic children: returns the resolved absolute
  ///   address (baseAddr + relOffset).
  /// - Nested calldata structs: forwarded by their head address.
  ///
  /// When \p isNonABI is false (default, ABI-function context) the revert
  /// messages read "Invalid calldata access {offset,length,stride}".
  /// When \p isNonABI is true (non-ABI / internal calldata parameter) they
  /// read "Invalid calldata tail {offset,length}" and "Calldata tail too
  /// short".
  Value genCalldataAccessRef(mlir::Type ty, Value baseAddr, Value ptr,
                             bool isNonABI = false,
                             std::optional<Location> locArg = std::nullopt);

  /// Generates {slot, offset} for packed storage array indexing.
  Value genPackedStorageAddr(Value baseSlot, Value idx, Type eltTy,
                             bool isDataLeftAligned = false,
                             std::optional<Location> locArg = std::nullopt);

  /// The address of element \p idx of the storage array \p arrTy whose data
  /// starts at \p dataSlot: the {slot, byte offset} pair for a packable
  /// element type, else the strided slot from genAddrAtIdx.
  Value genStorageEltAddr(Value dataSlot, Value idx, sol::ArrayType arrTy,
                          Location loc);

  /// Returns {slot, byteOffset} for an element at \p idx in a packed storage
  /// array rooted at \p baseSlot, where elements are \p eltByteSize bytes each.
  std::pair<Value, Value>
  genPackedStorageAddrPair(Value baseSlot, Value idx, unsigned eltByteSize,
                           bool isDataLeftAligned = false,
                           std::optional<Location> locArg = std::nullopt);

  /// Loads slot and punches hole: and(sload/tload(slot), holeMask)
  /// where holeMask = not(ones(numBits) << shiftBits)
  Value genPunchHole(Value slot, Value shiftBits, unsigned numBits,
                     sol::DataLocation dataLoc = sol::DataLocation::Storage,
                     std::optional<Location> locArg = std::nullopt);

  /// Cleans up a packed storage value to match Solidity storage-load semantics
  /// for the given element type.
  Value
  genCleanupPackedStorageValue(Type eltTy, Value value,
                               std::optional<Location> locArg = std::nullopt);

  /// Ext-func-ref pack/unpack between the packed integer and {addr, selector}
  /// struct. The packing in storage/transient is LSB-aligned while everything
  /// else is MSB-aligned. The result is cleaned.
  Value genExtFuncPack(Value extFuncStruct, bool inStorage,
                       std::optional<Location> locArg = std::nullopt);
  Value genExtFuncUnpack(Value word, bool inStorage,
                         std::optional<Location> locArg = std::nullopt);

  /// Ext-func-ref conversion between data-location forms; calldata sources
  /// are validated and pair-form src is packed to dstDataLoc's form. The result
  /// is cleaned.
  Value genExtFuncConversion(Value src, sol::DataLocation srcDataLoc,
                             sol::DataLocation dstDataLoc,
                             std::optional<Location> locArg = std::nullopt);

  /// Reverts on dirty bits outside the MSB bytes24 lanes.
  void genExtFuncWordValidation(Value word,
                                std::optional<Location> locArg = std::nullopt);

  /// Inserts integer value (<=32 bytes) to the slot value:
  /// or(and(slot, holeMask), shiftedVal), where
  /// holeMask = not(ones(numBits) << offset * 8),
  /// shiftedVal = (intVal << offset * 8)
  Value genInsertIntToSlot(Value slot, Value offset, Value intVal,
                           unsigned numBits, std::optional<Location> locArg);

  /// Generates a load from the low level integral type address.
  Value genLoad(Value addr, sol::DataLocation dataLoc,
                std::optional<Location> locArg = std::nullopt);

  /// Generates a size load from addr of dynamic type.
  Value genDynSize(Value addr, Type ty,
                   std::optional<Location> locArg = std::nullopt);

  /// Generates a store to the low level integral type address.
  void genStore(Value val, Value addr, sol::DataLocation dataLoc,
                std::optional<Location> locArg = std::nullopt);

  /// Writes the bytes of a string literal at \p addr: up to
  /// `maxImmediateStringLiteralSize` bytes as immediate words, the last one
  /// with zeros past the bytes, and above that by a CODECOPY of the bytes from
  /// their global in the string literal pool. With \p withCleanup, a CODECOPY
  /// that ends inside a word is followed by clearing the word at addr + size,
  /// so the last word has zeros past the bytes as well.
  void genStringLiteralData(StringRef bytes, Value addr,
                            std::optional<Location> locArg = std::nullopt,
                            bool withCleanup = false);

  /// Returns the length of the storage string whose loaded length slot is
  /// \p lengthSlot, through `helpersym::storageStringLength`.
  mlir::Value
  genStorageStringLength(mlir::Value lengthSlot,
                         std::optional<mlir::Location> locArg = std::nullopt);

  /// Low-level helper: copies string data from storage into an
  /// already-allocated memory area \p dstDataAddr, which is the destination
  /// for the string's raw bytes. For length-prefixed encodings in memory,
  /// this is typically the address immediately past the length word. Uses the
  /// pre-decoded \p lengthSlot and \p length. Does not write the length word.
  void genCopyStringDataFromStorageToMemory(
      mlir::Value src, mlir::Value lengthSlot, mlir::Value length,
      mlir::Value dstDataAddr,
      std::optional<mlir::Location> locArg = std::nullopt);

  /// genStringLength followed by genCopyStringBytesToMemory. Returns the
  /// byte length.
  mlir::Value
  genCopyStringDataToMemory(mlir::Value src, mlir::Type ty,
                            mlir::Value dstDataAddr,
                            std::optional<mlir::Location> locArg = std::nullopt,
                            bool withCleanup = false);

  /// Zeroes storage elements [\p startIdx, \p endIdx) of the storage array
  /// \p arrTy at \p arraySlot.  For a dynamic array, \p arraySlot is the
  /// length slot and the data area is keccak256(\p arraySlot).  For a static
  /// array, \p arraySlot is also the base of the data area.
  ///
  /// All Solidity storage element types are handled recursively:
  ///  - Scalars and fixed-size arrays of scalars: all occupied slots zeroed
  ///    directly.
  ///  - Packed types (elemsPerSlot >= 2, e.g. bool, uint8): partial-slot
  ///    masking is applied at the low boundary when \p startIdx does not fall
  ///    on a slot boundary.
  ///  - Strings/bytes: out-of-place data area cleared, then the length slot
  ///    zeroed.
  ///  - Dynamic sub-arrays: length slot zeroed, data area cleared recursively.
  ///  - Fixed-size arrays with dynamically-sized element types: each element
  ///    cleared recursively.
  ///  - Structs: each member cleared recursively; packed members sharing a
  ///    storage slot are deduplicated.
  ///
  /// Set \p isDecrement when the caller is popping exactly one element, i.e.
  /// \p endIdx == \p startIdx + 1.  Two optimisations are applied:
  ///  1. The range-guard branch (\p startIdx < \p endIdx) is omitted.
  ///  2. For non-packed element types the loop is unrolled into
  ///     \c getStorageSlotCount(eltTy) direct stores (a compile-time constant).
  void
  genClearStorageArrayTail(mlir::Value arraySlot, mlir::sol::ArrayType arrTy,
                           mlir::Value startIdx, mlir::Value endIdx,
                           bool isDecrement = false,
                           std::optional<mlir::Location> locArg = std::nullopt);

  /// Zeros the storage occupied by a value of type \p ty at \p slot.
  ///
  /// Structs and arrays are cleared via an out-of-line helper function, one
  /// per type, that recurses at runtime (a self-referential struct such as
  /// `struct S { S[] arr; }` could not be expanded inline anyway). Scalars
  /// and strings are expanded inline.
  void genClearStorageValue(mlir::Type ty, mlir::Value slot,
                            mlir::Location loc);

  /// Copies a string from \p src (any data location encoded in \p ty) to the
  /// storage slot \p dstAddr, handling in-place / out-of-place encoding and
  /// zeroing storage slots no longer needed by the new value.
  void
  genCopyStringToStorage(mlir::Value src, mlir::Type ty, mlir::Value dstAddr,
                         std::optional<mlir::Location> locArg = std::nullopt);

  /// Writes the constant string \p bytes and its length to the storage slot
  /// \p dstAddr and its data slots, zeroing the data slots no longer needed,
  /// through a helper per literal that every assignment of it shares.
  void genCopyConstantStringToStorage(
      llvm::StringRef bytes, mlir::Value dstAddr,
      std::optional<mlir::Location> locArg = std::nullopt);

  /// Copies an object from (\p srcAddr, \p srcDataLoc) to
  /// (\p dstAddr, \p dstDataLoc).
  ///
  /// The caller must ensure that \p dstAddr points to already-allocated space
  /// large enough to hold the object.
  ///
  /// Supported: scalars (int, bytesN, addr, enum, FuncRef, ExtFuncRef),
  /// StringType (any->Stg), StructType (any->Stg), and arrays of any element
  /// type with any packing combination. Copies into memory are clones, made
  /// by genCloneToMemory.
  ///
  /// An array copy that is not one bulk copy is emitted as
  /// `helpersym::copyArray`. Nested rows recurse through genCopy and share
  /// their helper.
  void genCopy(mlir::Type srcTy, mlir::Type dstTy, mlir::Value srcAddr,
               mlir::Value dstAddr, mlir::sol::DataLocation srcDataLoc,
               mlir::sol::DataLocation dstDataLoc,
               std::optional<mlir::Location> locArg = std::nullopt);

  /// Returns a fresh memory copy of the value of type \p ty at \p src in
  /// \p srcDataLoc (storage or calldata). An array clone that needs a loop,
  /// every struct clone and a storage string clone are emitted once per type
  /// as the `clone_array`, `clone_struct` and `clone_string` helpers. The
  /// copy itself is genCopyInline with a null destination.
  Value genCloneToMemory(Type ty, Value src, sol::DataLocation srcDataLoc,
                         std::optional<Location> locArg = std::nullopt);

  /// Calls the helper named \p symbol with \p args, creating it on first
  /// request with the types of \p args as its argument types and no
  /// results. \p genBody emits the body from the
  /// entry-block arguments and the body location. The terminating
  /// `sol.return` is emitted here.
  void genHelperCall(
      llvm::StringRef symbol, mlir::ValueRange args,
      llvm::function_ref<void(mlir::ValueRange, mlir::Location)> genBody,
      std::optional<mlir::Location> locArg = std::nullopt);
  /// Same for a helper with the single result type \p resTy. \p genBody
  /// returns the value the helper returns, and the call's result is returned.
  mlir::Value genHelperCall(
      llvm::StringRef symbol, mlir::ValueRange args, mlir::Type resTy,
      llvm::function_ref<mlir::Value(mlir::ValueRange, mlir::Location)> genBody,
      std::optional<mlir::Location> locArg = std::nullopt);
  /// Same for a helper with the result types \p resTys. \p genBody returns
  /// the values the helper returns, and the call's results are returned.
  SmallVector<Value> genHelperCall(
      llvm::StringRef symbol, mlir::ValueRange args, mlir::TypeRange resTys,
      llvm::function_ref<SmallVector<Value>(mlir::ValueRange, mlir::Location)>
          genBody,
      std::optional<mlir::Location> locArg = std::nullopt);

  /// Generates the 'push' of a value to string.
  void genPushToString(mlir::Value srcAddr, mlir::Value value,
                       std::optional<mlir::Location> locArg = std::nullopt);

  /// Generates the 'push' of a default value to string and
  /// returns a fat pointer to the newly added element.
  Value
  genPushVoidToString(Value srcAddr,
                      std::optional<mlir::Location> locArg = std::nullopt);

  /// Generates the 'pop' for string.
  void genPopString(mlir::Value srcAddr, mlir::Value oldData,
                    mlir::Value length,
                    std::optional<mlir::Location> locArg = std::nullopt);

  /// Generates {slot, offset} for string storage indexing.
  Value genStringItemAddress(mlir::Value srcAddr, mlir::Value idx,
                             std::optional<Location> locArg = std::nullopt);

  /// Generates an assertion that the tuple size should be less than `size`.
  void genABITupleSizeAssert(TypeRange tys, Value size,
                             std::optional<Location> locArg = std::nullopt);

  /// Encodes `vals` of `tys` into memory at `startAddr`. Returns the address
  /// just past the last written byte. Singleton ranges are valid (e.g.
  /// indexed-event keccak input).
  ///
  /// A non-empty tuple is encoded by `helpersym::abiEncodeTuple`, which
  /// never reads the free pointer: the caller takes the head start from it
  /// before the call and advances it from the returned end after.
  Value genABIEncoding(TypeRange tys, ValueRange vals, Value startAddr,
                       ABIEncodingOptions opts,
                       std::optional<Location> locArg = std::nullopt);
  /// Standard ABI encoding (`abi.encode` shape).
  Value genABIEncoding(TypeRange tys, ValueRange vals, Value startAddr,
                       std::optional<Location> locArg = std::nullopt);

  /// Packed ABI encoding (`abi.encodePacked` / indexed-event keccak input).
  Value genABIEncodingPacked(TypeRange tys, ValueRange vals, Value startAddr,
                             std::optional<Location> locArg = std::nullopt);

  Value genABITupleEncoding(std::string const &str, Value headStart,
                            std::optional<Location> locArg = std::nullopt);

  /// Decodes one ABI value of type \p ty at \p addr, bounded by
  /// \p tupleEnd. An identified struct or a value needing a loop is decoded by
  /// `helpersym::abiDecodeToMemory`.
  Value genABITupleDecoding(Type ty, Value addr, bool fromMem, Value tupleEnd,
                            bool topLevel,
                            std::optional<Location> locArg = std::nullopt);
  /// Generates the tuple decoder code as per the ABI and populates the results.
  /// A non-empty tuple is decoded by `helpersym::abiDecodeTuple`, whose
  /// results are the types \p tyConv gives \p tys.
  void genABITupleDecoding(TypeRange tys, Value tupleStart, Value tupleEnd,
                           std::vector<Value> &results, bool fromMem,
                           const TypeConverter &tyConv,
                           std::optional<Location> locArg = std::nullopt);
  /// Generates a panic with \p code through `helpersym::panic`.
  void genPanic(PanicCode code, std::optional<Location> locArg = std::nullopt);
  void genPanic(PanicCode code, Value cond,
                std::optional<Location> locArg = std::nullopt);
  /// The panic itself: the selector and \p code stored at address 0 and the
  /// revert.
  void genPanicInline(Value code, Location loc);

  /// Generates a revert with message if compiler-generated debug revert strings
  /// should be emitted, otherwise generates a revert without message.
  void genDebugRevertWithMsg(Value cond, std::string const &msg,
                             std::optional<Location> locArg = std::nullopt);
  void genDebugRevertWithMsg(std::string const &msg,
                             std::optional<Location> locArg = std::nullopt);

  /// Generates a revert with message if user-supplied revert strings should be
  /// preserved, otherwise generates a revert without message.
  void genUserRevertWithMsg(std::string const &msg,
                            std::optional<Location> locArg = std::nullopt);
  void genUserRevertWithMsg(Value cond, std::string const &msg,
                            std::optional<Location> locArg = std::nullopt);

  /// Generates a forwarding revert.
  void genForwardingRevert(std::optional<Location> locArg = std::nullopt);
  void genForwardingRevert(Value cond,
                           std::optional<Location> locArg = std::nullopt);

  /// Generates a revert(0, 0) unconditionally.
  void genRevert(std::optional<Location> locArg = std::nullopt);

  /// Generates a revert without message.
  void genRevert(Value cond, std::optional<Location> locArg = std::nullopt);

  /// Generates a revert with the custom error \p signature and its encoded
  /// \p vals of \p tys, through `helpersym::revertError`.
  void genRevert(Value cond, TypeRange tys, ValueRange vals,
                 StringRef signature,
                 std::optional<Location> locArg = std::nullopt);
  void genRevert(TypeRange tys, ValueRange vals, StringRef signature,
                 std::optional<Location> locArg = std::nullopt);

  /// Generates a revert with values. (Useful for debugging)
  void genDbgRevert(ValueRange vals,
                    std::optional<Location> locArg = std::nullopt);

  /// Conditionally generates a revert with values. (Useful for debugging)
  void genCondDbgRevert(Value cond, ValueRange vals,
                        std::optional<Location> locArg = std::nullopt);

  /// Creates a StructEncodeMemberReader for \p structTy at \p src, dispatching
  /// on the struct's embedded data location.
  std::unique_ptr<struct StructEncodeMemberReader>
  makeStructMemberReader(sol::StructType structTy, OpBuilder &b, Location loc,
                         Value src);
  /// Creates a StructMemberWriter for \p structTy at \p dst, dispatching
  /// on the struct's embedded data location.
  std::unique_ptr<struct StructMemberWriter>
  makeStructMemberWriter(sol::StructType structTy, OpBuilder &b, Location loc,
                         Value dst);
};

/// Base class for reading struct members from a concrete source location
/// (calldata, memory, or storage), used for ABI encoding and genCopy().
struct StructEncodeMemberReader {
  sol::StructType structTy;
  evm::Builder &evmB;
  OpBuilder &b;
  Location loc;
  mlir::solgen::BuilderExt bExt;

  StructEncodeMemberReader(sol::StructType structTy, evm::Builder &evmB,
                           OpBuilder &b, Location loc)
      : structTy(structTy), evmB(evmB), b(b), loc(loc), bExt(b, loc) {}

  virtual ~StructEncodeMemberReader() = default;

  Type getMemberType(uint64_t memberIdx) const {
    return structTy.getMemberTypes()[memberIdx];
  }

  // Returns the source value for the struct member at memberIdx.
  // If skipCleanup is true, storage readers return the raw right-shifted field
  // bits without calling genCleanupPackedStorageValue, other readers ignore it.
  virtual Value read(uint64_t memberIdx, bool skipCleanup = false) = 0;

  // Emits instruction to advance source position for the next member,
  // if needed.
  virtual void advance(uint64_t memberIdx) = 0;
};

/// Base class for writing struct members to a concrete destination
/// location (memory or storage).
struct StructMemberWriter {
  sol::StructType structTy;
  evm::Builder &evmB;
  OpBuilder &b;
  Location loc;
  mlir::solgen::BuilderExt bExt;

  StructMemberWriter(sol::StructType structTy, evm::Builder &evmB, OpBuilder &b,
                     Location loc)
      : structTy(structTy), evmB(evmB), b(b), loc(loc), bExt(b, loc) {}

  virtual ~StructMemberWriter() = default;

  Type getMemberType(uint64_t memberIdx) const {
    return structTy.getMemberTypes()[memberIdx];
  }

  // Writes the source value to the struct member at memberIdx.
  // srcMemberTy is the source type of the member (carries the correct
  // DataLocation for aggregate types).
  virtual void write(uint64_t memberIdx, Value srcVal, Type srcMemberTy) = 0;

  // Emits instruction to advance destination position for the next member,
  // if needed.
  virtual void advance(uint64_t memberIdx) = 0;
};

} // namespace evm
} // namespace mlir

#endif // MLIR_CONVERSION_SOLTOYUL_EVMUTIL_H
