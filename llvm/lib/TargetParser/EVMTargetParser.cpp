//===-- EVMTargetParser.cpp - EVM subtarget features ----------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/TargetParser/EVMTargetParser.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/TargetParser/TargetParser.h"

#define GET_SUBTARGETFEATURES_KV
#include "llvm/TargetParser/EVMGenTargetFeatures.inc"

using namespace llvm;

StringRef EVM::getFeatureName(unsigned Feature) {
  for (const BasicSubtargetFeatureKV &KV : BasicEVMFeatureKV)
    if (KV.Value == Feature)
      return KV.Key;
  llvm_unreachable("Unknown EVM subtarget feature");
}
