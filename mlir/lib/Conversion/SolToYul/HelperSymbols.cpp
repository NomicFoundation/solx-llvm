//===- HelperSymbols.cpp - Symbols of out-of-line helpers -----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the generators of the `__sol.*` helper symbols and the
// type spelling they share.
//
//===----------------------------------------------------------------------===//

#include "mlir/Conversion/SolToYul/HelperSymbols.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/Support/raw_ostream.h"

using namespace mlir;

/// Builds "__sol.<spelling>.<field>..." (see the helpersym doc in
/// HelperSymbols.h for the uniqueness argument).
static std::string makeHelperSymbol(StringRef spelling,
                                    ArrayRef<StringRef> fields) {
  std::string sym;
  llvm::raw_string_ostream os(sym);
  os << "__sol." << spelling;
  for (StringRef field : fields) {
    assert(!field.contains('.') && "helper symbol field must not contain '.'");
    os << '.' << field;
  }
  return sym;
}

/// Returns \p in with solc's identifier escaping.
///
/// This is the scheme of solc `Type::escapeIdentifier`: the spelling is kept
/// letter for letter and only the punctuation that a Solidity identifier cannot
/// contain is re-spelled, with '$' and '_' sequences. The encoding is
/// reversible, so two different types never spell the same.
///
/// '$' is escaped first, and must be, because it is legal in a Solidity
/// identifier: a struct named `A$_B` would otherwise read back as `A(B`.
static std::string escaped(StringRef in) {
  std::string out;
  for (char c : in) {
    if (llvm::isAlnum(c) || c == '_') {
      out += c;
      continue;
    }
    switch (c) {
    case '$':
      out += "$$$";
      break;
    case ',':
      out += "_$_";
      break;
    // '<' joins '(' and '>' joins ')': the printer uses the angle brackets for
    // a type's own arguments and the parentheses for a member or parameter
    // list, and no two spellings differ in the bracket kind alone, so one pair
    // of escapes serves both.
    case '<':
    case '(':
      out += "$_";
      break;
    case '>':
    case ')':
      out += "_$";
      break;
    // A dynamic array length. solc spells it the same way.
    case '?':
      out += "dyn";
      break;
    // The dialect prefix's '!', the quotes around a name and the blanks carry
    // no information: a Solidity identifier contains none of them. A '.' is
    // not dropped, as a frontend may qualify a struct name with one, and it
    // falls through to the hex escape below.
    case '!':
    case ' ':
    case '"':
      break;
    default:
      out += '$';
      out += llvm::utohexstr(static_cast<unsigned char>(c));
      break;
    }
  }
  return out;
}

/// '.'-free spelling of a type as a helper symbol field. The printed type is
/// kept letter for letter, with the dialect prefix dropped and the punctuation
/// re-spelled by solc's '$' and '_' escapes, so two different types never
/// spell the same. `!sol.array<? x ui256, Storage>` spells
/// `array$_dyn_ui256_$_Storage_$`.
static std::string typeName(Type ty) {
  std::string printed;
  {
    llvm::raw_string_ostream os(printed);
    ty.print(os);
  }
  auto replaceAll = [](std::string &text, StringRef needle, StringRef with) {
    for (size_t pos = 0; (pos = text.find(needle.data(), pos, needle.size())) !=
                         std::string::npos;
         pos += with.size())
      text.replace(pos, needle.size(), with.data(), with.size());
  };
  replaceAll(printed, "!sol.", "");
  replaceAll(printed, "->", "returns");
  replaceAll(printed, " x ", "_");

  return escaped(printed);
}

/// A struct's key field: the escaped name of an identified struct, the type
/// spelling of a literal one.
static std::string structKey(sol::StructType ty) {
  return ty.isIdentified() ? escaped(ty.getName()) : typeName(ty);
}

static std::string locName(sol::DataLocation loc) {
  return sol::stringifyDataLocation(loc).lower();
}

std::string evm::helpersym::copyStringToStorage(sol::DataLocation src) {
  return makeHelperSymbol("copy_string", {locName(src), "storage"});
}

std::string evm::helpersym::copyStructToStorage(sol::DataLocation src,
                                                sol::StructType srcTy,
                                                sol::StructType dstTy) {
  return makeHelperSymbol("copy_struct", {locName(src), "storage",
                                          structKey(srcTy), structKey(dstTy)});
}

std::string evm::helpersym::cloneStructToMemory(sol::DataLocation src,
                                                sol::StructType ty) {
  return makeHelperSymbol("clone_struct",
                          {locName(src), "memory", structKey(ty)});
}

std::string evm::helpersym::cloneArrayToMemory(sol::DataLocation src,
                                               sol::ArrayType ty) {
  return makeHelperSymbol("clone_array",
                          {locName(src), "memory", typeName(ty)});
}

std::string evm::helpersym::copyArray(sol::DataLocation src,
                                      sol::DataLocation dst,
                                      sol::ArrayType srcTy,
                                      sol::ArrayType dstTy) {
  return makeHelperSymbol("copy_array", {locName(src), locName(dst),
                                         typeName(srcTy), typeName(dstTy)});
}

std::string evm::helpersym::clearStorageStruct(sol::StructType ty) {
  return makeHelperSymbol("clear_storage_struct", {structKey(ty)});
}

std::string evm::helpersym::clearStorageArray(sol::ArrayType ty) {
  return makeHelperSymbol("clear_storage_array", {typeName(ty)});
}

std::string evm::helpersym::clearStorageStringTail() {
  return makeHelperSymbol("clear_storage_string_tail", {});
}

std::string evm::helpersym::copyStringBytesStorageToMemory() {
  return makeHelperSymbol("copy_string_bytes", {"storage", "memory"});
}

std::string evm::helpersym::allocMemoryArray(bool zeroInit, sol::ArrayType ty) {
  return makeHelperSymbol(
      "alloc_array", {zeroInit ? "zeroed" : "uninit", "memory", typeName(ty)});
}

std::string evm::helpersym::abiDecodeToMemory(bool fromMem, Type ty) {
  return makeHelperSymbol(
      "abi_decode", {fromMem ? "memory" : "calldata", "memory", typeName(ty)});
}

/// Builds "__sol.<spelling>.<field>....<item>..." with the fixed \p fields
/// followed by one field per \p item.
static std::string makeListSymbol(StringRef spelling,
                                  ArrayRef<StringRef> fields,
                                  ArrayRef<std::string> items) {
  SmallVector<StringRef> all(fields);
  llvm::append_range(all, items);
  return makeHelperSymbol(spelling, all);
}

/// The spellings of \p tys.
static SmallVector<std::string> typeNames(TypeRange tys) {
  return llvm::to_vector(llvm::map_range(tys, typeName));
}

std::string evm::helpersym::abiDecodeTuple(bool fromMem, TypeRange tys) {
  return makeListSymbol("abi_decode_tuple", {fromMem ? "memory" : "calldata"},
                        typeNames(tys));
}

std::string evm::helpersym::abiEncodeTuple(bool padded, bool dynamicInplace,
                                           TypeRange tys) {
  return makeListSymbol(
      "abi_encode_tuple",
      {padded ? "padded" : "packed", dynamicInplace ? "inplace" : "tail"},
      typeNames(tys));
}

std::string evm::helpersym::abiEncodeMemoryArray(bool padded,
                                                 bool dynamicInplace,
                                                 sol::ArrayType ty) {
  return makeHelperSymbol("abi_encode_array",
                          {"memory", padded ? "padded" : "packed",
                           dynamicInplace ? "inplace" : "tail", typeName(ty)});
}

std::string evm::helpersym::indexStorageArray(sol::ArrayType arrTy,
                                              bool noPanicBounds) {
  SmallVector<StringRef> fields;
  std::string name = typeName(arrTy);
  fields.push_back(name);
  if (noPanicBounds)
    fields.push_back("nopanic");
  return makeHelperSymbol("index_storage_array", fields);
}

std::string evm::helpersym::pushStorageArray(sol::ArrayType ty) {
  return makeHelperSymbol("push_storage_array", {typeName(ty)});
}

std::string evm::helpersym::popStorageArray(sol::ArrayType ty) {
  return makeHelperSymbol("pop_storage_array", {typeName(ty)});
}

std::string
evm::helpersym::dispatchInternalCall(bool runtime,
                                     ArrayRef<int64_t> candidateIds) {
  SmallVector<std::string> ids;
  for (int64_t id : candidateIds)
    ids.push_back(std::to_string(id));
  return makeListSymbol("dispatch_internal_call",
                        {runtime ? "runtime" : "creation"}, ids);
}
