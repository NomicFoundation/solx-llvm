//===- HelperSymbolsTest.cpp - Helper symbol uniqueness -------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Pushes every helper symbol generator through a universe of types, data
// locations and mode flags and checks that no two distinct inputs produce the
// same symbol.
//
//===----------------------------------------------------------------------===//

#include "mlir/Conversion/SolToYul/HelperSymbols.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/MLIRContext.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/Support/raw_ostream.h"
#include "gtest/gtest.h"

using namespace mlir;
using namespace mlir::evm;
using sol::DataLocation;

namespace {

/// Records every generated symbol with a description of its inputs and
/// collects the symbols that two different inputs share.
struct SymbolRegistry {
  llvm::StringMap<std::string> seen;
  std::vector<std::string> collisions;
  unsigned count = 0;

  void add(const std::string &sym, const std::string &desc) {
    ++count;
    auto [it, inserted] = seen.try_emplace(sym, desc);
    if (!inserted && it->second != desc)
      collisions.push_back(sym + "\n    " + it->second + "\n    " + desc);
  }
};

static std::string str(Type ty) {
  std::string s;
  llvm::raw_string_ostream os(s);
  os << ty;
  return s;
}

static std::string str(DataLocation loc) {
  return sol::stringifyDataLocation(loc).str();
}

static std::string str(TypeRange tys) {
  std::string s = "[";
  for (Type ty : tys)
    s += str(ty) + "; ";
  return s + "]";
}

const DataLocation kLocs[] = {DataLocation::Memory, DataLocation::Storage,
                              DataLocation::CallData, DataLocation::Transient};

/// The type universe: scalars, strings, arrays and structs in every data
/// location, with struct names chosen to probe the identifier escaping.
struct Universe {
  MLIRContext ctx;
  Builder b{&ctx};
  SmallVector<Type> all;
  SmallVector<sol::ArrayType> arrays;
  SmallVector<sol::StructType> structs;

  Universe() {
    ctx.loadDialect<sol::SolDialect>();
    MLIRContext *c = &ctx;
    auto i256 = b.getIntegerType(256);
    auto ui256 = b.getIntegerType(256, /*isSigned=*/false);
    SmallVector<Type> scalars = {
        b.getI1Type(),
        b.getIntegerType(8),
        i256,
        b.getIntegerType(8, false),
        ui256,
        b.getIntegerType(8, true),
        b.getIntegerType(256, true),
        sol::EnumType::get(c, 3),
        sol::EnumType::get(c, 4),
        sol::AddressType::get(c, false),
        sol::AddressType::get(c, true),
        sol::FixedBytesType::get(c, 1),
        sol::FixedBytesType::get(c, 32),
        sol::ByteType::get(c),
        sol::ContractType::get(c, "C", false),
        sol::ContractType::get(c, "C", true),
        sol::ContractType::get(c, "C_1", false),
    };
    SmallVector<FunctionType> fnTys = {
        FunctionType::get(c, {}, {}),
        FunctionType::get(c, {i256}, {i256}),
        FunctionType::get(c, {i256, i256}, {}),
        FunctionType::get(c, {}, {i256, i256}),
        FunctionType::get(c, {i256}, {i256, i256}),
        FunctionType::get(c, {i256, i256}, {i256}),
    };
    for (FunctionType fnTy : fnTys) {
      scalars.push_back(sol::FuncRefType::get(c, fnTy));
      scalars.push_back(sol::ExtFuncRefType::get(c, fnTy));
    }
    all = scalars;

    // Struct names that could, if the escaping were lossy, read as another
    // name or as a type spelling.
    const char *names[] = {"S",
                           "S_1",
                           "S_12",
                           "_S",
                           "$",
                           "$_",
                           "_$",
                           "$_$",
                           "$$$",
                           "S$_T",
                           "S_$_T",
                           "dyn",
                           "returns",
                           "nopanic",
                           "ui256",
                           "array",
                           "struct",
                           "memory",
                           "storage",
                           "x",
                           "2_ui256",
                           "$_ui256_$",
                           "struct$_$_ui256_$_$_Memory_$",
                           "A.S",
                           "AS",
                           "A_S"};

    for (DataLocation loc : kLocs) {
      auto string = sol::StringType::get(c, loc);
      auto dynWords = sol::ArrayType::get(c, std::nullopt, ui256, loc);
      auto twoWords = sol::ArrayType::get(c, APInt(256, 2), ui256, loc);
      auto twelveWords = sol::ArrayType::get(c, APInt(256, 12), ui256, loc);
      auto dynBytes =
          sol::ArrayType::get(c, std::nullopt, b.getIntegerType(8, false), loc);
      auto dynStrings = sol::ArrayType::get(c, std::nullopt, string, loc);
      auto twoDynWords = sol::ArrayType::get(c, APInt(256, 2), dynWords, loc);
      auto dynTwoWords = sol::ArrayType::get(c, std::nullopt, twoWords, loc);
      auto dynDynWords = sol::ArrayType::get(c, std::nullopt, dynWords, loc);
      auto literal = sol::StructType::get(c, {ui256, string}, loc);
      auto literal2 = sol::StructType::get(c, {ui256, ui256}, loc);
      auto literal3 = sol::StructType::get(c, {ui256}, loc);
      auto nested = sol::StructType::get(c, {literal3, ui256}, loc);
      SmallVector<Type> refs = {
          string,     dynWords,    twoWords,    twelveWords, dynBytes,
          dynStrings, twoDynWords, dynTwoWords, dynDynWords, literal,
          literal2,   literal3,    nested};
      // Recursive identified structs with a body, the other names opaque.
      auto rec = sol::StructType::getIdentified(c, "R_7", loc);
      auto recArr = sol::ArrayType::get(c, std::nullopt, rec, loc);
      if (failed(rec.setBody({ui256, recArr})))
        llvm::report_fatal_error("setBody failed");
      refs.push_back(rec);
      refs.push_back(recArr);
      for (const char *name : names)
        refs.push_back(sol::StructType::getIdentified(c, name, loc));
      for (Type ty : refs) {
        all.push_back(ty);
        if (auto arrTy = dyn_cast<sol::ArrayType>(ty))
          arrays.push_back(arrTy);
        if (auto structTy = dyn_cast<sol::StructType>(ty))
          structs.push_back(structTy);
      }
      // Arrays and strings wrapped in one more static dimension.
      for (Type ty : refs)
        if (isa<sol::ArrayType, sol::StringType>(ty)) {
          auto outer = sol::ArrayType::get(c, APInt(256, 3), ty, loc);
          all.push_back(outer);
          arrays.push_back(outer);
        }
    }
  }
};

TEST(HelperSymbols, Injective) {
  Universe u;
  SymbolRegistry reg;
  const bool flags[] = {false, true};

  reg.add(helpersym::clearStorageStringTail(), "clear_storage_string_tail");
  reg.add(helpersym::copyStringBytesStorageToMemory(), "copy_string_bytes");
  reg.add(helpersym::storageStringLength(), "storage_string_length");
  reg.add(helpersym::popStorageString(), "pop_storage_string");
  for (bool f : flags)
    reg.add(helpersym::pushStorageString(f),
            std::string("push_storage_string") + (f ? " zero" : ""));
  for (DataLocation src : kLocs)
    reg.add(helpersym::cloneStringToMemory(src), "clone_string " + str(src));
  for (DataLocation src : kLocs)
    reg.add(helpersym::copyStringToStorage(src), "copy_string " + str(src));

  // The struct generators key an identified struct by its name alone, and
  // the lowering always passes a struct type whose location is the one named
  // by the location fields. Keep the enumeration to such consistent calls.
  for (sol::StructType st : u.structs) {
    DataLocation src = st.getDataLocation();
    if (src == DataLocation::Storage)
      reg.add(helpersym::clearStorageStruct(st),
              "clear_storage_struct " + str(st));
    reg.add(helpersym::cloneStructToMemory(src, st),
            "clone_struct " + str(src) + " " + str(st));
    for (sol::StructType dst : u.structs)
      if (dst.getDataLocation() == DataLocation::Storage)
        reg.add(helpersym::copyStructToStorage(src, st, dst),
                "copy_struct " + str(src) + " " + str(st) + " -> " + str(dst));
  }

  // Every array copies to every third one.
  SmallVector<sol::ArrayType> someArrays;
  for (size_t i = 0; i < u.arrays.size(); i += 3)
    someArrays.push_back(u.arrays[i]);
  for (sol::ArrayType arr : u.arrays) {
    reg.add(helpersym::clearStorageArray(arr),
            "clear_storage_array " + str(arr));
    reg.add(helpersym::pushStorageArray(arr), "push_storage_array " + str(arr));
    reg.add(helpersym::popStorageArray(arr), "pop_storage_array " + str(arr));
    for (bool f : flags) {
      reg.add(helpersym::indexStorageArray(arr, f),
              "index_storage_array " + str(arr) + (f ? " nopanic" : ""));
      reg.add(helpersym::allocMemoryArray(f, arr),
              "alloc_array " + str(arr) + (f ? " zeroed" : " uninit"));
      for (bool g : flags)
        reg.add(helpersym::abiEncodeMemoryArray(f, g, arr),
                "abi_encode_array " + str(arr) + (f ? " padded" : " packed") +
                    (g ? " inplace" : " tail"));
    }
    for (DataLocation src : kLocs) {
      reg.add(helpersym::cloneArrayToMemory(src, arr),
              "clone_array " + str(src) + " " + str(arr));
      for (DataLocation dst : kLocs)
        for (sol::ArrayType dstArr : someArrays)
          reg.add(helpersym::copyArray(src, dst, arr, dstArr),
                  "copy_array " + str(src) + " " + str(dst) + " " + str(arr) +
                      " -> " + str(dstArr));
    }
  }

  for (Type ty : u.all)
    for (bool f : flags)
      reg.add(helpersym::abiDecodeToMemory(f, ty),
              "abi_decode " + str(ty) + (f ? " memory" : " calldata"));

  // Tuples of one and two elements, plus a few of three.
  SmallVector<SmallVector<Type>> tuples;
  // Pairs of every type with every fourth one and triples over the scalars.
  SmallVector<Type> some;
  for (size_t i = 0; i < u.all.size(); i += 4)
    some.push_back(u.all[i]);
  ArrayRef<Type> few = ArrayRef(u.all).take_front(8);
  for (Type a : u.all) {
    tuples.push_back({a});
    for (Type b : some)
      tuples.push_back({a, b});
    for (Type b : few)
      for (Type c : few)
        tuples.push_back({a, b, c});
  }
  for (const SmallVector<Type> &tys : tuples) {
    for (bool f : flags) {
      reg.add(helpersym::abiDecodeTuple(f, tys),
              "abi_decode_tuple " + str(TypeRange(tys)) +
                  (f ? " memory" : " calldata"));
      for (bool g : flags)
        reg.add(helpersym::abiEncodeTuple(f, g, tys),
                "abi_encode_tuple " + str(TypeRange(tys)) +
                    (f ? " padded" : " packed") + (g ? " inplace" : " tail"));
    }
  }

  const SmallVector<int64_t> idSets[] = {
      {1}, {2}, {12}, {1, 2}, {2, 1}, {1, 2, 3}, {12, 3}, {1, 23}, {0}, {0, 0}};
  for (bool runtime : flags)
    for (const SmallVector<int64_t> &ids : idSets) {
      std::string desc = runtime ? "dispatch runtime" : "dispatch creation";
      for (int64_t id : ids)
        desc += " " + std::to_string(id);
      reg.add(helpersym::dispatchInternalCall(runtime, ids), desc);
    }

  llvm::errs() << "helper symbols generated: " << reg.count
               << ", distinct: " << reg.seen.size() << "\n";
  llvm::errs() << "collisions: " << reg.collisions.size() << "\n";
  for (const std::string &c : ArrayRef(reg.collisions).take_front(40))
    llvm::errs() << "collision: " << c << "\n";
  EXPECT_TRUE(reg.collisions.empty());
  EXPECT_EQ(reg.count, reg.seen.size());
}

} // namespace
