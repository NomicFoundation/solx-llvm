//===- SolBase.td - Solidity dialect -----------------------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_DIALECT_SOL_SOLBASE_TD
#define MLIR_DIALECT_SOL_SOLBASE_TD

include "mlir/Interfaces/CastInterfaces.td"
include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/Interfaces/SideEffectInterfaces.td"
include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/EnumAttr.td"
include "mlir/IR/OpBase.td"

//===----------------------------------------------------------------------===//
// Dialect
//===----------------------------------------------------------------------===//

def Sol_Dialect : Dialect {
  let name = "sol";
  let cppNamespace = "::mlir::sol";
  let useDefaultAttributePrinterParser = 1;
  let useDefaultTypePrinterParser = 1;
  let hasConstantMaterializer = 1;
}

//===----------------------------------------------------------------------===//
// Types
//===----------------------------------------------------------------------===//

class Sol_Type<string name, string typeMnemonic, list<Trait> traits = []> :
    TypeDef<Sol_Dialect, name, traits> {
  let mnemonic = typeMnemonic;
}

def I256 : I<256>;
def UI256 : UI<256>;
def Sol_EnumType : Sol_Type<"Enum", "enum"> {
  // The max value is for the validation generation
  let parameters = (ins "uint32_t":$max);
  let assemblyFormat = [{ `<` $max `>` }];
}
def Sol_Int : AnyTypeOf<[Sol_EnumType, I1, AnySignedInteger,
                         AnyUnsignedInteger]>;

def Sol_PayableKeywordParameter : AttrOrTypeParameter<"bool", "address payability"> {
  let defaultValue = "false";
  let parser = [{ [&]() -> FailureOr<bool> {
    if ($_parser.parseKeyword("payable"))
      return failure();
    return true;
  }() }];
  let printer = [{ $_printer << "payable"; }];
}

def Sol_AddressType : Sol_Type<"Address", "address"> {
  let parameters = (ins Sol_PayableKeywordParameter:$payable);
  let assemblyFormat = [{ (`<` $payable^ `>`)? }];
}

def Sol_ContractType : Sol_Type<"Contract", "contract"> {
  let parameters = (ins StringRefParameter<"contract name">:$name,
                        Sol_PayableKeywordParameter:$payable);
  let assemblyFormat = [{ `<` $name (`,` $payable^)? `>` }];
}

def Sol_FixedBytesType : Sol_Type<"FixedBytes", "fixedbytes"> {
  let parameters = (ins "uint32_t":$size);
  let assemblyFormat = [{ `<` $size `>` }];
}

def Sol_ByteType : Sol_Type<"Byte", "byte">;

// Extends Sol_Int with Solidity's fixed-bytes types (bytes1 .. bytes32 and the
// legacy `byte` alias). Used as the operand/result type constraint for bitwise
// ops (and, or, xor, not, shl, shr) that must work on both integer and bytesN
// values without converting to an intermediate integer form.
def Sol_BitwiseTy : AnyTypeOf<[Sol_Int, Sol_FixedBytesType, Sol_ByteType]>;

def Sol_DataLocation : I32Enum<"DataLocation",
                               "Data-location in reference-types",
                               [I32EnumCase<"Storage", 0>,
                                I32EnumCase<"CallData", 1>,
                                I32EnumCase<"Memory", 2>,
                                I32EnumCase<"Stack", 3>,
                                I32EnumCase<"Immutable", 4>,
                                I32EnumCase<"Transient", 5>]> {
  let cppNamespace = "::mlir::sol";
}

def Sol_StringType : Sol_Type<"String", "string"> {
  let parameters = (ins Sol_DataLocation:$dataLocation);

  let hasCustomAssemblyFormat = 1;
}

def Sol_ArrayType : Sol_Type<"Array", "array"> {
  let parameters = (ins "int64_t":$size, "Type":$eltType,
                    Sol_DataLocation:$dataLocation);

  let extraClassDeclaration = [{
    /// Returns true if the size is dynamic.
    bool isDynSized() { return getSize() == -1; }
  }];

  let hasCustomAssemblyFormat = 1;
}

def Sol_StructType : Sol_Type<"Struct", "struct", [MutableType]> {
  let summary =
      "Solidity struct type (supports identified, self-referential structs)";
  let description = [{
    Like LLVM's struct type, a Sol struct is either *literal* (uniqued by its
    member types and data location, immutable) or *identified* (uniqued by a
    name and data location, with a mutable body). Identified structs can be
    created opaque (no body) and have their body set later, which is what makes
    recursive (self-referential) structs representable: the body may reference
    the identified struct itself, e.g. `struct S { S[] arr; }`.

    Storage member offsets / slot count are computed once the body is known
    (at construction for literal structs, at `setBody` for identified ones).
    This is well-founded for the legal recursive forms because the only
    cycle-breaking members (dynamic arrays, mappings) occupy a fixed one-slot
    footprint and never require the nested struct's layout.
  }];

  let parameters = (ins StringRefParameter<"struct name", [{""}]>:$name,
      Sol_DataLocation:$dataLocation,
      OptionalArrayRefParameter<"Type">:$memberTypes);

  let storageClass = "StructTypeStorage";
  let genStorageClass = 0;
  let skipDefaultBuilders = 1;
  let genAccessors = 0;

  let extraClassDeclaration = [{
    struct StorageMemberOffset {
      uint64_t slotOffset;
      uint64_t byteOffset;
    };

    /// Gets or creates a literal struct uniqued by its members + location.
    static StructType get(::mlir::MLIRContext *ctx,
                          ::llvm::ArrayRef<Type> memberTypes,
                          DataLocation dataLocation);

    /// Gets or creates an identified struct uniqued by (name, location). If it
    /// does not yet exist it is created opaque (no body). Use `setBody` to fill
    /// it in. Re-fetching the same (name, location) returns the same instance,
    /// which is what closes self-referential cycles.
    static StructType getIdentified(::mlir::MLIRContext *ctx,
                                    ::llvm::StringRef name,
                                    DataLocation dataLocation);

    /// Sets the body of an identified struct (computing storage offsets).
    /// Fails on a literal struct or on re-setting a different body.
    ::llvm::LogicalResult setBody(::llvm::ArrayRef<Type> memberTypes);

    /// Whether this is an identified (name-uniqued) struct, as opposed to a
    /// literal one. Being identified is also the "may be recursive" signal:
    /// a literal struct can never be self-referential (its body is a
    /// uniquing key, so it would have to contain itself), and frontends are
    /// expected to create identified structs only for Solidity structs whose
    /// type is recursive. Lowering therefore branches on this predicate
    /// wherever inline expansion of a struct's members could recurse without
    /// bound in the compiler (e.g. `delete` and deep copies), outlining the
    /// per-struct work into a helper function that recurses at runtime
    /// instead. A false positive is harmless: a non-recursive identified
    /// struct (e.g. one parsed from textual IR) only costs an out-of-line
    /// helper it did not need.
    bool isIdentified() const;
    /// An identified struct whose body has not been set yet. Literal structs
    /// are never opaque (their body is fixed at construction), and opaque is
    /// distinct from empty: `setBody({})` yields a non-opaque zero-member
    /// struct. While opaque, `getMemberTypes()` is empty and the
    /// storage-layout accessors assert. Opaqueness is normally a transient
    /// state between `getIdentified()` and `setBody()`, exactly the window
    /// in which a self-reference inside the body being built observes the
    /// type, though a body-less `!sol.struct<"name", loc>` parsed from
    /// textual IR remains opaque. An opaque struct may only be embedded in
    /// cycle-breaking positions (dynamic arrays, mappings) where its layout
    /// is never needed; the parser rejects other member positions, and the
    /// printer prints opaque structs name-only.
    bool isOpaque() const;

    ::llvm::StringRef getName() const;
    DataLocation getDataLocation() const;
    ::llvm::ArrayRef<Type> getMemberTypes() const;
    ::llvm::ArrayRef<uint64_t> getMemberSlotOffsets() const;
    ::llvm::ArrayRef<uint64_t> getMemberByteOffsets() const;
    uint64_t getStorageSlotCount() const;

    StorageMemberOffset getStorageMemberOffset(uint64_t memberIdx) const;
  }];

  let hasCustomAssemblyFormat = 1;
}

def Sol_MappingType : Sol_Type<"Mapping", "mapping"> {
  let parameters = (ins "Type":$keyType, "Type":$valType);

  let assemblyFormat = [{ `<` $keyType `,` $valType `>` }];
}

def Sol_PtrType : Sol_Type<"Pointer", "ptr"> {
  let parameters = (ins "Type":$pointeeType, Sol_DataLocation:$dataLocation);

  let hasCustomAssemblyFormat = 1;
}

def Sol_AggType : AnyTypeOf<[Sol_StringType, Sol_ArrayType, Sol_StructType],
                             "Solidity aggregate types">;
def Sol_RefType : AnyTypeOf<[Sol_PtrType, Sol_AggType],
                             "Solidity aggregate types and pointers">;

def Sol_YulPtr : Type<CPred<"::mlir::isa<::mlir::yul::PtrType>($_self)">,
                      "!yul.ptr">;

def Sol_AnyStackPtr : Type<
  CPred<"::mlir::sol::isStackPtr($_self)">,
  "sol.ptr<*, Stack>">;

def Sol_StorageRefStackPtr : Type<
  CPred<"::mlir::sol::isStackPtrToStorageRef($_self)">,
  "sol.ptr to a Storage/Transient-located ref-type, on the Stack">;

def Sol_DynCallDataStackPtr : Type<
  CPred<"::mlir::sol::isStackPtrToDynCallData($_self)">,
  "sol.ptr to a dynamically-sized CallData ref-type, on the Stack">;

def Sol_ExtFuncRefStackPtr : Type<
  CPred<"::mlir::sol::isStackPtrToExtFuncRef($_self)">,
  "sol.ptr to a sol.ext_func_ref, on the Stack">;

// This represents a reference to a function in the context of indirect call.
def Sol_FuncRefType : Sol_Type<"FuncRef", "func_ref"> {
  let parameters = (ins "FunctionType":$funcTy);
  let assemblyFormat = [{ `<` $funcTy `>` }];
}

// This represents an external function reference (address + selector).
def Sol_ExtFuncRefType : Sol_Type<"ExtFuncRef", "ext_func_ref"> {
  let parameters = (ins "FunctionType":$funcTy);
  let assemblyFormat = [{ `<` $funcTy `>` }];
}

//===----------------------------------------------------------------------===//
// Attributes
//===----------------------------------------------------------------------===//

def I256Attr : SignlessIntegerAttrBase<I256,
                                       "256-bit signless integer attribute">;

def Sol_CmpPredicateAttr :
    I64EnumAttr<"CmpPredicate", "",
                [I64EnumAttrCase<"eq", 0>,
                 I64EnumAttrCase<"ne", 1>,
                 I64EnumAttrCase<"lt", 2>,
                 I64EnumAttrCase<"le", 3>,
                 I64EnumAttrCase<"gt", 4>,
                 I64EnumAttrCase<"ge", 5>]> {
  let cppNamespace = "::mlir::sol";
}

def Sol_StateMutability :
    I32EnumAttr<"StateMutability", "Represents the state mutability of functions",
                 [I32EnumAttrCase<"Pure", 0>,
                  I32EnumAttrCase<"View", 1>,
                  I32EnumAttrCase<"NonPayable", 2>,
                  I32EnumAttrCase<"Payable", 3>]> {
  let genSpecializedAttr = 0;
  let cppNamespace = "::mlir::sol";
}
def Sol_StateMutabilityAttr : EnumAttr<Sol_Dialect, Sol_StateMutability,
                                       "StateMutability">;

def Sol_FunctionKind :
    I32EnumAttr<"FunctionKind", "Represents the kind of functions",
                 [I32EnumAttrCase<"Constructor", 0>,
                  I32EnumAttrCase<"Fallback", 1>,
                  I32EnumAttrCase<"Receive", 2>]> {
  let genSpecializedAttr = 0;
  let cppNamespace = "::mlir::sol";
}
def Sol_FunctionKindAttr : EnumAttr<Sol_Dialect, Sol_FunctionKind,
                                    "FunctionKind">;

def Sol_ContractKind : I32EnumAttr<"ContractKind",
                                   "Represents the solidity contract kind",
                                   [I32EnumAttrCase<"Interface", 0>,
                                    I32EnumAttrCase<"Contract", 1>,
                                    I32EnumAttrCase<"Library", 2>]> {
  let genSpecializedAttr = 0;
  let cppNamespace = "::mlir::sol";
}
def Sol_ContractKindAttr : EnumAttr<Sol_Dialect, Sol_ContractKind,
                                    "ContractKind">;

def Sol_EvmVersion : I32EnumAttr<"EvmVersion",
                                 "Represents the evm version",
                                   [I32EnumAttrCase<"Homestead", 0>,
                                    I32EnumAttrCase<"TangerineWhistle", 1>,
                                    I32EnumAttrCase<"SpuriousDragon", 2>,
                                    I32EnumAttrCase<"Byzantium", 3>,
                                    I32EnumAttrCase<"Constantinople", 4>,
                                    I32EnumAttrCase<"Petersburg", 5>,
                                    I32EnumAttrCase<"Istanbul", 6>,
                                    I32EnumAttrCase<"Berlin", 7>,
                                    I32EnumAttrCase<"London", 8>,
                                    I32EnumAttrCase<"Paris", 9>,
                                    I32EnumAttrCase<"Shanghai", 10>,
                                    I32EnumAttrCase<"Cancun", 11>,
                                    I32EnumAttrCase<"Prague", 12>,
                                    I32EnumAttrCase<"Osaka", 13>]> {
  let genSpecializedAttr = 0;
  let cppNamespace = "::mlir::sol";
}
def Sol_EvmVersionAttr : EnumAttr<Sol_Dialect, Sol_EvmVersion,
                                    "EvmVersion">;

def Sol_RevertStrings :
    I32EnumAttr<"RevertStrings", "Represents the revert string policy",
                [I32EnumAttrCase<"Default", 0>,
                 I32EnumAttrCase<"Strip", 1>,
                 I32EnumAttrCase<"Debug", 2>,
                 I32EnumAttrCase<"VerboseDebug", 3>]> {
  let genSpecializedAttr = 0;
  let cppNamespace = "::mlir::sol";
}
def Sol_RevertStringsAttr : EnumAttr<Sol_Dialect, Sol_RevertStrings,
                                     "RevertStrings">;

//===----------------------------------------------------------------------===//
// Op classes
//===----------------------------------------------------------------------===//

class Sol_Op<string mnemonic, list<Trait> traits = []> : Op<Sol_Dialect,
                                                            mnemonic, traits>;

class Sol_IntArithOp<string mnemonic, list<Trait> traits = []> :
    Sol_Op<mnemonic, traits # [SameOperandsAndResultType]> {
  let arguments = (ins Sol_Int:$lhs, Sol_Int:$rhs);
  let results = (outs Sol_Int:$result);

  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}

class Sol_UncheckedIntArithOp<string mnemonic, list<Trait> traits = []> :
    Sol_IntArithOp<mnemonic, traits # [Pure]>;

// Base for bitwise binary ops (and, or, xor) that accept both integer and
// bytesN operands. All three types (lhs, rhs, result) must be the same.
class Sol_BitwiseBinOp<string mnemonic, list<Trait> traits = []> :
    Sol_Op<mnemonic, traits#[Pure, SameOperandsAndResultType]> {
  let arguments = (ins Sol_BitwiseTy:$lhs, Sol_BitwiseTy:$rhs);
  let results = (outs Sol_BitwiseTy:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}

// Base for shift ops (shl, shr) that accept bytesN as value (lhs) while the
// shift amount (rhs) remains an integer. lhs and result share the same type.
// Rhs is an independent integer type (typically the mobile type of the shift
// expression).
class Sol_BitwiseShiftOp<string mnemonic, list<Trait> traits = []> :
    Sol_Op<mnemonic, traits#[Pure, AllTypesMatch<["lhs", "result"]>]> {
  let arguments = (ins Sol_BitwiseTy:$lhs, Sol_Int:$rhs);
  let results = (outs Sol_BitwiseTy:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($lhs) `,` type($rhs)";
}

class Sol_IntExpOp<string mnemonic, list<Trait> traits = []> :
    Sol_Op<mnemonic, traits # [AllTypesMatch<["lhs", "result"]>]> {
  let arguments = (ins Sol_Int:$lhs, AnyUnsignedInteger:$rhs);
  let results = (outs Sol_Int:$result);

  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($lhs) `,` "
                       "type($rhs) `->` type($result)";
}

class Sol_ModOp<string mnemonic, list<Trait> traits = []>
    : Sol_Op<mnemonic, traits#[SameOperandsAndResultType]> {
  let arguments = (ins AnyUnsignedInteger:$x, AnyUnsignedInteger:$y,
      AnyUnsignedInteger:$mod);
  let results = (outs AnyUnsignedInteger:$result);
  let assemblyFormat = "$x `,` $y `,` $mod attr-dict `:` type($result)";
}

class Sol_HashPreCompileOp<string mnemonic> : Sol_Op<mnemonic> {
  let arguments = (ins Sol_StringType:$data);
  let results = (outs Sol_FixedBytesType:$result);
}

#endif // MLIR_DIALECT_SOL_SOLBASE_TD
