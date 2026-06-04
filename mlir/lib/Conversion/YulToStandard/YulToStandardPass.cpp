//===- YulToStandardPass.cpp - Yul to Standard dialect lowering pass ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Lowers the yul dialect to the standard dialects (arith, cf, func, LLVM).
//
//===----------------------------------------------------------------------===//

#include "mlir/Conversion/YulToStandard/YulToStandard.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/ControlFlow/IR/ControlFlow.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/Yul/Yul.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Transforms/DialectConversion.h"

namespace mlir {
#define GEN_PASS_DEF_CONVERTYULTOSTANDARDPASS
#include "mlir/Conversion/Passes.h.inc"
} // namespace mlir

using namespace mlir;

namespace {

/// Pass for lowering the yul dialect to the standard dialects.
struct ConvertYulToStandardPass
    : public impl::ConvertYulToStandardPassBase<ConvertYulToStandardPass> {

  void runOnOperation() override {
    ModuleOp mod = getOperation();

    ConversionTarget convTgt(getContext());
    convTgt.addLegalOp<ModuleOp>();
    convTgt.addLegalDialect<func::FuncDialect, cf::ControlFlowDialect,
                            arith::ArithDialect, LLVM::LLVMDialect>();
    convTgt.addIllegalDialect<yul::YulDialect>();

    TypeConverter tyConv;
    tyConv.addConversion([](Type ty) { return ty; });
    tyConv.addConversion([](yul::PtrType ty) -> Type {
      return LLVM::LLVMPointerType::get(ty.getContext());
    });
    auto castMaterialization = [](OpBuilder &b, Type resTy, ValueRange ins,
                                  Location loc) -> Value {
      return b.create<UnrealizedConversionCastOp>(loc, resTy, ins).getResult(0);
    };
    tyConv.addSourceMaterialization(castMaterialization);
    tyConv.addTargetMaterialization(castMaterialization);

    RewritePatternSet pats(&getContext());
    evm::populateYulPats(pats, tyConv);

    if (failed(applyPartialConversion(mod, convTgt, std::move(pats)))) {
      signalPassFailure();
      return;
    }
  }
};

} // namespace
