//===- Yul.h - MLIR Yul dialect ---------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares the Yul dialect in MLIR.
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_DIALECT_YUL_YUL_H_
#define MLIR_DIALECT_YUL_YUL_H_

#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/IR/Types.h"
#include "mlir/Interfaces/CallInterfaces.h"
#include "mlir/Interfaces/CastInterfaces.h"
#include "mlir/Interfaces/ControlFlowInterfaces.h"
#include "mlir/Interfaces/FunctionInterfaces.h"
#include "mlir/Interfaces/InferTypeOpInterface.h"
#include "mlir/Interfaces/LoopLikeInterface.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"

namespace mlir::yul {
bool isI256OrI256LLVMStruct(Type type);

struct MemoryResource : public SideEffects::Resource::Base<MemoryResource> {
  StringRef getName() final { return "<Memory>"; }
};

/// State outside the EVM machine: the caller, the transaction log, the
/// deployed contracts.
// TODO: Can we replace ValidationResource with this?
struct ExternalResource : public SideEffects::Resource::Base<ExternalResource> {
  StringRef getName() final { return "<External>"; }
};
} // namespace mlir::yul

#include "mlir/Dialect/Yul/YulInterfaces.h.inc"
#include "mlir/Dialect/Yul/YulOpsDialect.h.inc"
#include "mlir/Dialect/Yul/YulOpsEnums.h.inc"

#define GET_TYPEDEF_CLASSES
#include "mlir/Dialect/Yul/YulOpsTypes.h.inc"

#define GET_OP_CLASSES
#include "mlir/Dialect/Yul/YulOps.h.inc"

#endif // MLIR_DIALECT_YUL_YUL_H_
