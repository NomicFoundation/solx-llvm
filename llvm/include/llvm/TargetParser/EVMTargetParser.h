//===-- EVMTargetParser.h - EVM subtarget features --------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file exposes the subtarget features of EVM.td outside the backend.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TARGETPARSER_EVMTARGETPARSER_H
#define LLVM_TARGETPARSER_EVMTARGETPARSER_H

#include "llvm/ADT/StringRef.h"
#include "llvm/Support/Compiler.h"

namespace llvm {
namespace EVM {

/// `Feature` is one of the `EVM::Feature*` enumerators.
LLVM_ABI StringRef getFeatureName(unsigned Feature);

} // namespace EVM
} // namespace llvm

#define GET_SUBTARGETFEATURES_ENUM
#include "llvm/TargetParser/EVMGenTargetFeatures.inc"

#endif
