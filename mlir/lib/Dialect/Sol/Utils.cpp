//===- Utils.cpp - Sol dialect IR-construction utilities ------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Sol/Utils.h"
#include "mlir/Dialect/Sol/Sol.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/raw_ostream.h"

using namespace mlir;
using namespace mlir::sol;

Value mlir::sol::genDefaultVal(OpBuilder &b, Type ty, Location loc) {
  MLIRContext *ctx = b.getContext();

  if (auto intTy = dyn_cast<IntegerType>(ty))
    return b.create<ConstantOp>(
        loc, b.getIntegerAttr(intTy, llvm::APInt(intTy.getWidth(), 0)));

  if (isa<FuncRefType>(ty))
    return b.create<DefaultFuncConstantOp>(loc);

  if (auto extFnTy = dyn_cast<ExtFuncRefType>(ty)) {
    auto addrTy = AddressType::get(ctx, /*payable=*/false);
    auto uint160Ty = b.getIntegerType(160, /*isSigned=*/false);
    auto zeroInt = b.create<ConstantOp>(
        loc, b.getIntegerAttr(uint160Ty, llvm::APInt(160, 0)));
    auto zeroAddr = b.create<AddressCastOp>(loc, addrTy, zeroInt);
    return b.create<ExtFuncConstantOp>(loc, extFnTy, zeroAddr,
                                       b.getI32IntegerAttr(0));
  }

  if (auto addrTy = dyn_cast<AddressType>(ty)) {
    auto uint160Ty = b.getIntegerType(160, /*isSigned=*/false);
    auto zero = b.create<ConstantOp>(
        loc, b.getIntegerAttr(uint160Ty, llvm::APInt(160, 0)));
    return b.create<AddressCastOp>(loc, addrTy, zero);
  }

  if (auto contractTy = dyn_cast<ContractType>(ty)) {
    auto uint160Ty = b.getIntegerType(160, /*isSigned=*/false);
    auto zero = b.create<ConstantOp>(
        loc, b.getIntegerAttr(uint160Ty, llvm::APInt(160, 0)));
    auto addrTy = AddressType::get(ctx, contractTy.getPayable());
    auto zeroAddr = b.create<AddressCastOp>(loc, addrTy, zero);
    return b.create<AddressCastOp>(loc, contractTy, zeroAddr);
  }

  if (auto bytesTy = dyn_cast<FixedBytesType>(ty)) {
    unsigned width = bytesTy.getSize() * 8;
    auto uintTy = b.getIntegerType(width, /*isSigned=*/false);
    auto zero = b.create<ConstantOp>(
        loc, b.getIntegerAttr(uintTy, llvm::APInt(width, 0)));
    return b.create<BytesCastOp>(loc, bytesTy, zero);
  }

  if (isa<ByteType>(ty)) {
    auto uintTy = b.getIntegerType(8, /*isSigned=*/false);
    auto zero =
        b.create<ConstantOp>(loc, b.getIntegerAttr(uintTy, llvm::APInt(8, 0)));
    return b.create<BytesCastOp>(loc, ty, zero);
  }

  if (auto enumTy = dyn_cast<EnumType>(ty)) {
    auto ui256Ty = b.getIntegerType(256, /*isSigned=*/false);
    auto zero = b.create<ConstantOp>(
        loc, b.getIntegerAttr(ui256Ty, llvm::APInt(256, 0)));
    return b.create<EnumCastOp>(loc, enumTy, zero);
  }

  if (isa<ArrayType, StructType, StringType>(ty)) {
    DataLocation dataLoc = getDataLocation(ty);
    if (dataLoc == DataLocation::CallData)
      return b.create<DefaultCallDataOp>(loc, ty);
    if (dataLoc == DataLocation::Storage || dataLoc == DataLocation::Transient)
      return b.create<DefaultStorageOp>(loc, ty);
    // TODO zero-init memory strings?
    bool zeroInit = !isa<StringType>(ty);
    return b.create<MallocOp>(loc, ty, zeroInit, /*size=*/Value{});
  }

  llvm::errs() << "sol::genDefaultVal: unsupported type: " << ty << "\n";
  llvm_unreachable("sol::genDefaultVal: unsupported type");
}
