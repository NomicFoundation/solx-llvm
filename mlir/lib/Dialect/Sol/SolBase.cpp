//===- SolDialect.cpp - MLIR Dialect for Solidity implementation ----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the Solidity dialect.
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/DialectImplementation.h"
#include "mlir/Support/LLVM.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/TypeSwitch.h"

#include "mlir/Dialect/Sol/SolInterfaces.cpp.inc"
#include "mlir/Dialect/Sol/SolOpsDialect.cpp.inc"
#include "mlir/Dialect/Sol/SolOpsEnums.cpp.inc"

using namespace mlir;
using namespace mlir::sol;

namespace {

struct SolOpAsmDialectInterface : public OpAsmDialectInterface {
  using OpAsmDialectInterface::OpAsmDialectInterface;

  AliasResult getAlias(Attribute attr, raw_ostream &os) const override {
    if (auto contrKindAttr = dyn_cast<ContractKindAttr>(attr)) {
      os << stringifyContractKind(contrKindAttr.getValue());
      return AliasResult::OverridableAlias;
    }
    if (auto stateMutAttr = dyn_cast<StateMutabilityAttr>(attr)) {
      os << stringifyStateMutability(stateMutAttr.getValue());
      return AliasResult::OverridableAlias;
    }
    if (auto fnKindAttr = dyn_cast<FunctionKindAttr>(attr)) {
      os << stringifyFunctionKind(fnKindAttr.getValue());
      return AliasResult::OverridableAlias;
    }
    if (auto evmVersionAttr = dyn_cast<EvmVersionAttr>(attr)) {
      os << stringifyEvmVersion(evmVersionAttr.getValue());
      return AliasResult::OverridableAlias;
    }
    if (auto revertStringsAttr = dyn_cast<RevertStringsAttr>(attr)) {
      os << stringifyRevertStrings(revertStringsAttr.getValue());
      return AliasResult::OverridableAlias;
    }
    return AliasResult::NoAlias;
  }
};

} // namespace

void SolDialect::initialize() {
  addTypes<
#define GET_TYPEDEF_LIST
#include "mlir/Dialect/Sol/SolOpsTypes.cpp.inc"
      >();

  addOperations<
#define GET_OP_LIST
#include "mlir/Dialect/Sol/SolOps.cpp.inc"
      >();

  addAttributes<
#define GET_ATTRDEF_LIST
#include "mlir/Dialect/Sol/SolOpsAttributes.cpp.inc"
      >();

  addInterfaces<SolOpAsmDialectInterface>();
}

Operation *SolDialect::materializeConstant(OpBuilder &builder, Attribute val,
                                           Type type, Location loc) {
  return builder.create<ConstantOp>(loc, type, cast<TypedAttr>(val));
}

static RevertStrings getRevertStrings(ModuleOp mod) {
  if (auto attr = mod->getAttrOfType<RevertStringsAttr>("sol.revert_strings"))
    return attr.getValue();
  return RevertStrings::Default;
}

bool mlir::sol::shouldEmitDebugRevertStrings(ModuleOp mod) {
  return getRevertStrings(mod) >= RevertStrings::Debug;
}

bool mlir::sol::shouldKeepUserRevertStrings(ModuleOp mod) {
  return getRevertStrings(mod) != RevertStrings::Strip;
}

bool mlir::sol::evmhasStaticCall(ModuleOp mod) {
  auto evmVersionAttr = cast<EvmVersionAttr>(mod->getAttr("sol.evm_version"));
  return evmVersionAttr.getValue() >= EvmVersion::Byzantium;
}

bool mlir::sol::evmSupportsReturnData(ModuleOp mod) {
  auto evmVersionAttr = cast<EvmVersionAttr>(mod->getAttr("sol.evm_version"));
  return evmVersionAttr.getValue() >= EvmVersion::Byzantium;
}

bool mlir::sol::evmCanOverchargeGasForCall(ModuleOp mod) {
  auto evmVersionAttr = cast<EvmVersionAttr>(mod->getAttr("sol.evm_version"));
  return evmVersionAttr.getValue() >= EvmVersion::TangerineWhistle;
}

Type mlir::sol::getEltType(Type ty, Index structTyIdx) {
  if (auto ptrTy = dyn_cast<sol::PointerType>(ty)) {
    return ptrTy.getPointeeType();
  }
  if (auto arrTy = dyn_cast<sol::ArrayType>(ty)) {
    return arrTy.getEltType();
  }
  if (isa<sol::StringType>(ty)) {
    return sol::ByteType::get(ty.getContext());
  }
  if (auto structTy = dyn_cast<sol::StructType>(ty)) {
    return structTy.getMemberTypes()[structTyIdx];
  }
  llvm_unreachable("Invalid type");
}

DataLocation mlir::sol::getDataLocation(Type ty) {
  return TypeSwitch<Type, DataLocation>(ty)
      .Case<PointerType>(
          [](sol::PointerType ptrTy) { return ptrTy.getDataLocation(); })
      .Case<ArrayType>(
          [](sol::ArrayType arrTy) { return arrTy.getDataLocation(); })
      .Case<StringType>(
          [](sol::StringType strTy) { return strTy.getDataLocation(); })
      .Case<StructType>(
          [](sol::StructType structTy) { return structTy.getDataLocation(); })
      .Case<MappingType>(
          [](sol::MappingType) { return sol::DataLocation::Storage; })
      .Default([&](Type) { return DataLocation::Stack; });
}

mlir::SideEffects::Resource *mlir::sol::getResource(DataLocation dataLoc) {
  switch (dataLoc) {
  case DataLocation::Stack:
    return StackResource::get();
  case DataLocation::CallData:
    return CallDataResource::get();
  case DataLocation::Memory:
    return MemoryResource::get();
  case DataLocation::Storage:
    return StorageResource::get();
  case DataLocation::Transient:
    return TransientResource::get();
  case DataLocation::Immutable:
    return ImmutableResource::get();
  }
}

bool mlir::sol::isNonPtrRefType(Type ty) {
  return !isScalar(ty) && !isa<PointerType>(ty);
}

static Type getStackPointee(Type type) {
  auto ptr = dyn_cast<sol::PointerType>(type);
  if (!ptr || ptr.getDataLocation() != sol::DataLocation::Stack)
    return {};
  return ptr.getPointeeType();
}

bool mlir::sol::isStackPtr(Type type) { return !!getStackPointee(type); }

bool mlir::sol::isStackPtrToStorageRef(Type type) {
  Type pointee = getStackPointee(type);
  if (!pointee)
    return false;
  if (!isNonPtrRefType(pointee))
    return false;
  auto loc = getDataLocation(pointee);
  return loc == DataLocation::Storage || loc == DataLocation::Transient;
}

bool mlir::sol::isStackPtrToDynCallData(Type type) {
  Type pointee = getStackPointee(type);
  if (!pointee)
    return false;
  return getDataLocation(pointee) == DataLocation::CallData &&
         isDynamicallySized(pointee);
}

bool mlir::sol::isStackPtrToExtFuncRef(Type type) {
  return isa_and_nonnull<ExtFuncRefType>(getStackPointee(type));
}

bool mlir::sol::isLeftAligned(Type ty) {
  assert(isScalar(ty) && "Alignment only defined for scalar types");
  // FixedBytesN / `byte` and ExtFuncRef occupy the high bytes of the
  // cleaned word; everything else (int / enum / address / FuncRef) is
  // right-aligned (low bytes).
  return isBytesLikeType(ty) || isa<ExtFuncRefType>(ty);
}

bool mlir::sol::isDynamicallySized(Type ty) {
  if (isa<StringType>(ty))
    return true;

  if (auto arrTy = dyn_cast<ArrayType>(ty))
    return arrTy.isDynSized();

  return false;
}

bool mlir::sol::hasDynamicallySizedElt(Type ty) {
  if (isa<StringType>(ty))
    return true;

  if (auto arrTy = dyn_cast<ArrayType>(ty))
    return arrTy.isDynSized() || hasDynamicallySizedElt(arrTy.getEltType());

  if (auto structTy = dyn_cast<StructType>(ty))
    return llvm::any_of(structTy.getMemberTypes(),
                        [](Type ty) { return hasDynamicallySizedElt(ty); });

  return false;
}

bool mlir::sol::isAddressLikeType(Type ty) {
  return isa<AddressType, ContractType>(ty);
}

bool mlir::sol::isBytesLikeType(Type ty) {
  return isa<FixedBytesType, ByteType>(ty);
}

unsigned mlir::sol::getStorageSlotCount(Type ty) {
  if (isa<IntegerType>(ty) || isa<EnumType>(ty) || isa<FixedBytesType>(ty) ||
      isa<MappingType>(ty) || isa<FuncRefType>(ty) || isa<ExtFuncRefType>(ty) ||
      isa<StringType>(ty) || isAddressLikeType(ty))
    return 1;

  if (auto arrTy = dyn_cast<ArrayType>(ty)) {
    // Dynamic arrays store only the head slot in-place.
    if (arrTy.isDynSized())
      return 1;

    Type eltTy = arrTy.getEltType();
    unsigned size = arrTy.getSize();
    if (!canBePacked(eltTy))
      return size * getStorageSlotCount(eltTy);

    // Packed arrays of small elements can fit in fewer slots.
    return llvm::divideCeil(size, 32u / getNumBytes(eltTy));
  }

  if (auto structTy = dyn_cast<StructType>(ty)) {
    assert(structTy.getDataLocation() == DataLocation::Storage &&
           "Storage slot count is only defined for storage structs");
    return structTy.getStorageSlotCount();
  }

  llvm_unreachable("NYI: Other types");
}

bool mlir::sol::isScalar(Type ty) {
  return isa<IntegerType>(ty) || isa<EnumType>(ty) || isa<FuncRefType>(ty) ||
         isa<ExtFuncRefType>(ty) || isAddressLikeType(ty) ||
         isBytesLikeType(ty);
}

bool mlir::sol::canBePacked(Type ty) { return isScalar(ty); }

unsigned mlir::sol::getNumBytes(Type ty) {
  assert(canBePacked(ty) && "Only packable types have byte size");

  if (auto intTy = dyn_cast<IntegerType>(ty))
    // Bool occupies 1 byte in storage.
    return intTy.getWidth() == 1 ? 1 : intTy.getWidth() / 8;

  if (isa<ByteType>(ty))
    return 1;

  if (auto fixedBytesTy = dyn_cast<FixedBytesType>(ty))
    return fixedBytesTy.getSize();

  // Enums can have at most 256 members, so always 1 byte.
  if (isa<EnumType>(ty))
    return 1;

  // Address-like types are 20 bytes.
  if (isAddressLikeType(ty))
    return 20;

  // Internal function reference.
  if (isa<FuncRefType>(ty))
    return 8;

  // External function reference (address + selector).
  if (isa<ExtFuncRefType>(ty))
    return 20 + 4;

  llvm_unreachable("NYI");
}

static ParseResult parseDataLocation(AsmParser &parser,
                                     DataLocation &dataLocation) {
  StringRef dataLocationTok;
  SMLoc loc = parser.getCurrentLocation();
  if (parser.parseKeyword(&dataLocationTok))
    return failure();

  auto parsedDataLoc = symbolizeDataLocation(dataLocationTok);
  if (!parsedDataLoc) {
    parser.emitError(loc, "Invalid data-location");
    return failure();
  }

  dataLocation = *parsedDataLoc;
  return success();
}

//===----------------------------------------------------------------------===//
// ArrayType
//===----------------------------------------------------------------------===//

/// Parses a sol.array type.
///
///   array-type ::= `<` size `x` elt-ty `,` data-location `>`
///   size ::= fixed-size | `?`
///
Type ArrayType::parse(AsmParser &parser) {
  if (parser.parseLess())
    return {};

  int64_t size = -1;
  if (parser.parseOptionalQuestion()) {
    if (parser.parseInteger(size))
      return {};
  }

  if (parser.parseKeyword("x"))
    return {};

  Type eleTy;
  if (parser.parseType(eleTy))
    return {};

  if (parser.parseComma())
    return {};

  DataLocation dataLocation = DataLocation::Memory;
  if (parseDataLocation(parser, dataLocation))
    return {};

  if (parser.parseGreater())
    return {};

  return get(parser.getContext(), size, eleTy, dataLocation);
}

/// Prints a sol.array type.
void ArrayType::print(AsmPrinter &printer) const {
  printer << "<";

  if (getSize() == -1)
    printer << "?";
  else
    printer << getSize();

  printer << " x " << getEltType() << ", "
          << stringifyDataLocation(getDataLocation()) << ">";
}

//===----------------------------------------------------------------------===//
// StringType
//===----------------------------------------------------------------------===//

/// Parses a sol.string type.
///
///   string-type ::= `<` data-location `>`
///
Type StringType::parse(AsmParser &parser) {
  if (parser.parseLess())
    return {};

  DataLocation dataLocation = DataLocation::Memory;
  if (parseDataLocation(parser, dataLocation))
    return {};

  if (parser.parseGreater())
    return {};

  return get(parser.getContext(), dataLocation);
}

/// Prints a sol.string type.
void StringType::print(AsmPrinter &printer) const {
  printer << "<" << stringifyDataLocation(this->getDataLocation()) << ">";
}

//===----------------------------------------------------------------------===//
// StructType
//===----------------------------------------------------------------------===//

static void computeStructStorageMemberOffsets(
    ArrayRef<Type> memberTypes, SmallVectorImpl<uint64_t> &slotOffsets,
    SmallVectorImpl<uint64_t> &byteOffsets, uint64_t &storageSlotCount) {
  uint64_t slotOffset = 0;
  uint64_t byteOffset = 0;

  slotOffsets.reserve(memberTypes.size());
  byteOffsets.reserve(memberTypes.size());

  for (Type memberTy : memberTypes) {
    if (canBePacked(memberTy)) {
      uint64_t memberByteSize = getNumBytes(memberTy);
      if (byteOffset + memberByteSize > 32) {
        ++slotOffset;
        byteOffset = 0;
      }

      slotOffsets.push_back(slotOffset);
      byteOffsets.push_back(byteOffset);
      byteOffset += memberByteSize;
      continue;
    }

    if (byteOffset != 0) {
      ++slotOffset;
      byteOffset = 0;
    }
    slotOffsets.push_back(slotOffset);
    byteOffsets.push_back(0);
    slotOffset += getStorageSlotCount(memberTy);
  }

  if (byteOffset > 0)
    ++slotOffset;

  storageSlotCount = slotOffset;
}

namespace mlir::sol::detail {
/// Storage for StructType. Supports both *literal* structs (uniqued by member
/// types + data location, immutable) and *identified* structs (uniqued by name
/// + data location, with a mutable body), the latter enabling self-referential
/// types. Storage member offsets are computed once the body is known.
struct StructTypeStorage : public ::mlir::TypeStorage {
  struct Key {
    StringRef name;
    DataLocation dataLocation;
    ArrayRef<Type> memberTypes;
    bool identified;

    Key(ArrayRef<Type> memberTypes, DataLocation dataLocation)
        : dataLocation(dataLocation), memberTypes(memberTypes),
          identified(false) {}
    Key(StringRef name, DataLocation dataLocation)
        : name(name), dataLocation(dataLocation), identified(true) {}

    llvm::hash_code hashValue() const {
      if (identified)
        return llvm::hash_combine(true, dataLocation, name);
      return llvm::hash_combine(
          false, dataLocation,
          llvm::hash_combine_range(memberTypes.begin(), memberTypes.end()));
    }
    bool operator==(const Key &o) const {
      if (identified != o.identified)
        return false;
      if (identified)
        return dataLocation == o.dataLocation && name == o.name;
      return dataLocation == o.dataLocation && memberTypes == o.memberTypes;
    }
  };
  using KeyTy = Key;

  StringRef name;
  DataLocation dataLocation;
  ArrayRef<Type> memberTypes;
  ArrayRef<uint64_t> memberSlotOffsets;
  ArrayRef<uint64_t> memberByteOffsets;
  uint64_t storageSlotCount = 0;
  bool identified;
  bool initialized = false;

  StructTypeStorage(StringRef name, DataLocation dataLocation, bool identified)
      : name(name), dataLocation(dataLocation), identified(identified) {}

  bool operator==(const KeyTy &k) const {
    if (identified != k.identified)
      return false;
    if (identified)
      return dataLocation == k.dataLocation && name == k.name;
    return dataLocation == k.dataLocation && memberTypes == k.memberTypes;
  }
  static llvm::hash_code hashKey(const KeyTy &k) { return k.hashValue(); }

  static StructTypeStorage *construct(::mlir::TypeStorageAllocator &allocator,
                                      const KeyTy &k) {
    auto *storage = new (allocator.allocate<StructTypeStorage>())
        StructTypeStorage(k.identified ? allocator.copyInto(k.name)
                                       : StringRef(),
                          k.dataLocation, k.identified);
    // Literal structs have their body (and offsets) fixed at construction.
    if (!k.identified)
      storage->setBodyImpl(allocator, k.memberTypes);
    return storage;
  }

  /// Mutation hook used by Type::mutate to fill an identified struct's body.
  ::llvm::LogicalResult mutate(::mlir::TypeStorageAllocator &allocator,
                               ArrayRef<Type> body) {
    if (!identified)
      return ::llvm::failure();
    // Allow setting the same body again (idempotent); reject a different one.
    if (initialized)
      return ::llvm::success(body == memberTypes);
    setBodyImpl(allocator, body);
    return ::llvm::success();
  }

  void setBodyImpl(::mlir::TypeStorageAllocator &allocator,
                   ArrayRef<Type> body) {
    memberTypes = allocator.copyInto(body);
    SmallVector<uint64_t, 8> slotOffs, byteOffs;
    uint64_t slotCount = 0;
    if (dataLocation == DataLocation::Storage)
      computeStructStorageMemberOffsets(memberTypes, slotOffs, byteOffs,
                                        slotCount);
    memberSlotOffsets = allocator.copyInto(ArrayRef<uint64_t>(slotOffs));
    memberByteOffsets = allocator.copyInto(ArrayRef<uint64_t>(byteOffs));
    storageSlotCount = slotCount;
    initialized = true;
  }
};
} // namespace mlir::sol::detail

StructType StructType::get(MLIRContext *ctx, ArrayRef<Type> memberTypes,
                           DataLocation dataLocation) {
  return Base::get(ctx,
                   detail::StructTypeStorage::Key(memberTypes, dataLocation));
}

StructType StructType::getIdentified(MLIRContext *ctx, StringRef name,
                                     DataLocation dataLocation) {
  return Base::get(ctx, detail::StructTypeStorage::Key(name, dataLocation));
}

LogicalResult StructType::setBody(ArrayRef<Type> memberTypes) {
  assert(isIdentified() && "cannot set the body of a literal struct");
  return Base::mutate(memberTypes);
}

bool StructType::isIdentified() const { return getImpl()->identified; }

bool StructType::isOpaque() const {
  return getImpl()->identified && !getImpl()->initialized;
}

StringRef StructType::getName() const { return getImpl()->name; }

DataLocation StructType::getDataLocation() const {
  return getImpl()->dataLocation;
}

ArrayRef<Type> StructType::getMemberTypes() const {
  return getImpl()->memberTypes;
}

ArrayRef<uint64_t> StructType::getMemberSlotOffsets() const {
  return getImpl()->memberSlotOffsets;
}

ArrayRef<uint64_t> StructType::getMemberByteOffsets() const {
  return getImpl()->memberByteOffsets;
}

uint64_t StructType::getStorageSlotCount() const {
  assert(!isOpaque() && "Storage layout queried before the body is set");
  return getImpl()->storageSlotCount;
}

StructType::StorageMemberOffset
StructType::getStorageMemberOffset(uint64_t memberIdx) const {
  assert(getDataLocation() == DataLocation::Storage &&
         "Storage offsets are only defined for storage structs");
  assert(!isOpaque() && "Storage layout queried before the body is set");
  assert(memberIdx < getMemberTypes().size() && "Member index out of bounds");

  return {/*slotOffset=*/getMemberSlotOffsets()[memberIdx],
          /*byteOffset=*/getMemberByteOffsets()[memberIdx]};
}

/// Returns the first opaque identified struct that \p ty embeds outside of a
/// cycle-breaking position, or a null type if there is none. Layout and value
/// size computation must recurse into direct struct members, fixed-size array
/// elements, and literal-struct members, so an opaque struct (one whose body
/// is not yet set, e.g. the enclosing struct while its own body is being
/// parsed) in those positions cannot be laid out. Dynamic arrays and mappings
/// occupy a fixed one-slot footprint independent of their element/value type,
/// which is what makes recursive structs representable.
static StructType findIllFoundedOpaqueRef(Type ty) {
  if (auto structTy = dyn_cast<StructType>(ty)) {
    if (structTy.isOpaque())
      return structTy;
    // A bodied identified struct was validated when its body was set; only
    // literal struct members need to be inspected here.
    if (!structTy.isIdentified())
      for (Type memTy : structTy.getMemberTypes())
        if (StructType found = findIllFoundedOpaqueRef(memTy))
          return found;
    return {};
  }
  if (auto arrTy = dyn_cast<ArrayType>(ty)) {
    if (arrTy.isDynSized())
      return {};
    return findIllFoundedOpaqueRef(arrTy.getEltType());
  }
  // Mappings, strings, pointers and scalars never require the layout of a
  // nested struct.
  return {};
}

/// Parses a sol.struct type.
///
///   struct-type ::= `<` `(` member-types `)` `,` data-location `>` (literal)
///                 | `<` name `,` data-location (`,` `(` member-types `)`)? `>`
///                 (identified)
///
Type StructType::parse(AsmParser &parser) {
  MLIRContext *ctx = parser.getContext();
  if (parser.parseLess())
    return {};

  // Identified form: starts with a string-literal name.
  std::string name;
  if (succeeded(parser.parseOptionalString(&name))) {
    if (parser.parseComma())
      return {};
    DataLocation dataLocation = DataLocation::Memory;
    if (parseDataLocation(parser, dataLocation))
      return {};

    // Create (or look up) the identified struct first, so that member types
    // parsed below can refer back to it.
    StructType structTy = StructType::getIdentified(ctx, name, dataLocation);

    if (succeeded(parser.parseOptionalComma())) {
      // Guard against a body nested inside this struct's own body: the
      // printer only ever emits name-only back-references there.
      FailureOr<AsmParser::CyclicParseReset> cyclicParse =
          parser.tryStartCyclicParse(structTy);
      if (failed(cyclicParse)) {
        parser.emitError(parser.getNameLoc(),
                         "identifier '" + name +
                             "' already used for an enclosing struct");
        return {};
      }
      if (parser.parseLParen())
        return {};
      SmallVector<Type, 4> memTys;
      do {
        Type memTy;
        if (parser.parseType(memTy))
          return {};
        memTys.push_back(memTy);
      } while (succeeded(parser.parseOptionalComma()));
      if (parser.parseRParen())
        return {};
      // Reject ill-founded recursion before the layout computation in
      // setBody would query the still-opaque struct.
      for (Type memTy : memTys) {
        if (StructType opaque = findIllFoundedOpaqueRef(memTy)) {
          parser.emitError(parser.getNameLoc())
              << "member of identified struct '" << name
              << "' directly embeds opaque struct '" << opaque.getName()
              << "' (a recursive reference must go through a cycle-breaking "
                 "member such as a dynamic array or mapping)";
          return {};
        }
      }
      if (failed(structTy.setBody(memTys))) {
        parser.emitError(parser.getNameLoc(),
                         "conflicting body for identified struct '" + name +
                             "'");
        return {};
      }
    }

    if (parser.parseGreater())
      return {};
    return structTy;
  }

  // Literal form.
  if (parser.parseLParen())
    return {};
  SmallVector<Type, 4> memTys;
  do {
    Type memTy;
    if (parser.parseType(memTy))
      return {};
    memTys.push_back(memTy);
  } while (succeeded(parser.parseOptionalComma()));
  if (parser.parseRParen())
    return {};
  if (parser.parseComma())
    return {};
  DataLocation dataLocation = DataLocation::Memory;
  if (parseDataLocation(parser, dataLocation))
    return {};
  if (parser.parseGreater())
    return {};
  // Reject ill-founded recursion before the layout computation at
  // construction would query the still-opaque struct.
  for (Type memTy : memTys) {
    if (StructType opaque = findIllFoundedOpaqueRef(memTy)) {
      parser.emitError(parser.getNameLoc())
          << "literal struct member directly embeds opaque struct '"
          << opaque.getName()
          << "' (a recursive reference must go through a cycle-breaking "
             "member such as a dynamic array or mapping)";
      return {};
    }
  }
  return get(ctx, memTys, dataLocation);
}

/// Prints a sol.struct type.
void StructType::print(AsmPrinter &printer) const {
  if (isIdentified()) {
    printer << "<";
    printer.printString(getName());
    printer << ", " << stringifyDataLocation(getDataLocation());
    // Opaque, or a back-reference to a struct already being printed: name
    // only. The RAII reset re-enables printing the body once this print (and
    // anything nested in it) is done.
    FailureOr<AsmPrinter::CyclicPrintReset> cyclicPrint =
        printer.tryStartCyclicPrint(*this);
    if (isOpaque() || failed(cyclicPrint)) {
      printer << ">";
      return;
    }
    printer << ", (";
    llvm::interleaveComma(getMemberTypes(), printer.getStream(),
                          [&](Type memTy) { printer << memTy; });
    printer << ")>";
    return;
  }

  printer << "<(";
  llvm::interleaveComma(getMemberTypes(), printer.getStream(),
                        [&](Type memTy) { printer << memTy; });
  printer << "), " << stringifyDataLocation(getDataLocation()) << ">";
}

//===----------------------------------------------------------------------===//
// PointerType
//===----------------------------------------------------------------------===//

/// Parses a sol.ptr type.
///
///   ptr-type ::= `<` pointee-ty, data-location `>`
///
Type PointerType::parse(AsmParser &parser) {
  if (parser.parseLess())
    return {};

  Type pointeeTy;
  if (parser.parseType(pointeeTy))
    return {};

  if (parser.parseComma())
    return {};

  DataLocation dataLocation = DataLocation::Memory;
  if (parseDataLocation(parser, dataLocation))
    return {};

  if (parser.parseGreater())
    return {};

  return get(parser.getContext(), pointeeTy, dataLocation);
}

/// Prints a sol.ptr type.
void PointerType::print(AsmPrinter &printer) const {
  printer << "<" << getPointeeType() << ", "
          << stringifyDataLocation(getDataLocation()) << ">";
}

#define GET_ATTRDEF_CLASSES
#include "mlir/Dialect/Sol/SolOpsAttributes.cpp.inc"

#define GET_TYPEDEF_CLASSES
#include "mlir/Dialect/Sol/SolOpsTypes.cpp.inc"
