//===- YulOps.cpp - MLIR operations for Yul implementation ----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the Yul operations.
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/LLVMIR/LLVMTypes.h"
#include "mlir/Dialect/Yul/Folders.h"
#include "mlir/Dialect/Yul/Yul.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/Matchers.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/IR/ValueRange.h"
#include "llvm/ADT/APInt.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallString.h"

using namespace mlir;
using namespace mlir::yul;

//===----------------------------------------------------------------------===//
// Folders
//===----------------------------------------------------------------------===//

namespace {

bool isAllOnes(Attribute attr) {
  APInt val;
  return matchPattern(attr, m_ConstantInt(&val)) && val.isAllOnes();
}

bool evalPredicate(CmpPredicate pred, const APInt &lhs, const APInt &rhs) {
  switch (pred) {
  case CmpPredicate::eq:
    return lhs == rhs;
  case CmpPredicate::ne:
    return lhs != rhs;
  case CmpPredicate::ult:
    return lhs.ult(rhs);
  case CmpPredicate::ule:
    return lhs.ule(rhs);
  case CmpPredicate::ugt:
    return lhs.ugt(rhs);
  case CmpPredicate::uge:
    return lhs.uge(rhs);
  case CmpPredicate::slt:
    return lhs.slt(rhs);
  case CmpPredicate::sle:
    return lhs.sle(rhs);
  case CmpPredicate::sgt:
    return lhs.sgt(rhs);
  case CmpPredicate::sge:
    return lhs.sge(rhs);
  }
  llvm_unreachable("unknown yul.cmp predicate");
}

CmpPredicate invertPredicate(CmpPredicate pred) {
  switch (pred) {
  case CmpPredicate::eq:
    return CmpPredicate::ne;
  case CmpPredicate::ne:
    return CmpPredicate::eq;
  case CmpPredicate::ult:
    return CmpPredicate::uge;
  case CmpPredicate::ule:
    return CmpPredicate::ugt;
  case CmpPredicate::ugt:
    return CmpPredicate::ule;
  case CmpPredicate::uge:
    return CmpPredicate::ult;
  case CmpPredicate::slt:
    return CmpPredicate::sge;
  case CmpPredicate::sle:
    return CmpPredicate::sgt;
  case CmpPredicate::sgt:
    return CmpPredicate::sle;
  case CmpPredicate::sge:
    return CmpPredicate::slt;
  }
  llvm_unreachable("unknown yul.cmp predicate");
}

/// The predicate that reads the same with the operands swapped.
CmpPredicate swapPredicate(CmpPredicate pred) {
  switch (pred) {
  case CmpPredicate::eq:
  case CmpPredicate::ne:
    return pred;
  case CmpPredicate::ult:
    return CmpPredicate::ugt;
  case CmpPredicate::ule:
    return CmpPredicate::uge;
  case CmpPredicate::ugt:
    return CmpPredicate::ult;
  case CmpPredicate::uge:
    return CmpPredicate::ule;
  case CmpPredicate::slt:
    return CmpPredicate::sgt;
  case CmpPredicate::sle:
    return CmpPredicate::sge;
  case CmpPredicate::sgt:
    return CmpPredicate::slt;
  case CmpPredicate::sge:
    return CmpPredicate::sle;
  }
  llvm_unreachable("unknown yul.cmp predicate");
}

} // namespace

OpFoldResult ConstantOp::fold(FoldAdaptor) { return getValueAttr(); }

OpFoldResult AddOp::fold(FoldAdaptor adaptor) {
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return getLhs();
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &a, const APInt &b) { return a + b; });
}

OpFoldResult SubOp::fold(FoldAdaptor adaptor) {
  if (getLhs() == getRhs())
    return IntegerAttr::get(getType(), 0);
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return getLhs();
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &a, const APInt &b) { return a - b; });
}

OpFoldResult MulOp::fold(FoldAdaptor adaptor) {
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return getRhs();
  if (matchPattern(adaptor.getRhs(), m_One()))
    return getLhs();
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &a, const APInt &b) { return a * b; });
}

OpFoldResult AndOp::fold(FoldAdaptor adaptor) {
  if (getLhs() == getRhs())
    return getLhs();
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return getRhs();
  if (isAllOnes(adaptor.getRhs()))
    return getLhs();
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &a, const APInt &b) { return a & b; });
}

OpFoldResult OrOp::fold(FoldAdaptor adaptor) {
  if (getLhs() == getRhs())
    return getLhs();
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return getLhs();
  if (isAllOnes(adaptor.getRhs()))
    return getRhs();
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &a, const APInt &b) { return a | b; });
}

OpFoldResult XOrOp::fold(FoldAdaptor adaptor) {
  if (getLhs() == getRhs())
    return IntegerAttr::get(getType(), 0);
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return getLhs();
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &a, const APInt &b) { return a ^ b; });
}

OpFoldResult NotOp::fold(FoldAdaptor adaptor) {
  if (auto inner = getValue().getDefiningOp<NotOp>())
    return inner.getValue();
  return foldUnary(adaptor.getOperands(), [](const APInt &a) { return ~a; });
}

OpFoldResult CmpOp::fold(FoldAdaptor adaptor) {
  if (getLhs() == getRhs())
    return IntegerAttr::get(
        getType(), evalPredicate(getPredicate(), APInt(256, 0), APInt(256, 0)));

  // A comparison yields 0 or 1, so testing it against 0 reads it as a boolean.
  if (getPredicate() == CmpPredicate::ne &&
      matchPattern(adaptor.getRhs(), m_Zero()) &&
      getLhs().getDefiningOp<CmpOp>())
    return getLhs();

  // cmp eq (cmp p a b), 0 -> cmp !p a b. The shape comes from:
  // - assembly: Yul has no ge, le or ne, so iszero(lt(a, b)) spells a >= b.
  // - require and assert: the revert condition is the negated argument.
  // - bool cleanup: a bool operand is normalized with ne x, 0.
  if (getPredicate() == CmpPredicate::eq &&
      matchPattern(adaptor.getRhs(), m_Zero())) {
    if (auto inner = getLhs().getDefiningOp<CmpOp>()) {
      setPredicate(invertPredicate(inner.getPredicate()));
      getLhsMutable().assign(inner.getLhs());
      getRhsMutable().assign(inner.getRhs());
      return getResult();
    }
  }

  // Constant on the right, so the patterns match one shape.
  if (adaptor.getLhs() && !adaptor.getRhs()) {
    setPredicate(swapPredicate(getPredicate()));
    Value lhs = getLhs();
    getLhsMutable().assign(getRhs());
    getRhsMutable().assign(lhs);
    return getResult();
  }

  return foldBinary(adaptor.getOperands(), [&](const APInt &a, const APInt &b) {
    return APInt(256, evalPredicate(getPredicate(), a, b));
  });
}

OpFoldResult ArithShlOp::fold(FoldAdaptor adaptor) {
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return getLhs();
  bool bounded = false;
  Attribute result =
      foldBinary(adaptor.getOperands(), [&](const APInt &a, const APInt &b) {
        bounded = b.ult(256);
        return a.shl(b);
      });
  return bounded ? result : Attribute();
}

OpFoldResult ArithShrOp::fold(FoldAdaptor adaptor) {
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return getLhs();
  bool bounded = false;
  Attribute result =
      foldBinary(adaptor.getOperands(), [&](const APInt &a, const APInt &b) {
        bounded = b.ult(256);
        return a.lshr(b);
      });
  return bounded ? result : Attribute();
}

OpFoldResult ArithSarOp::fold(FoldAdaptor adaptor) {
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return getLhs();
  bool bounded = false;
  Attribute result =
      foldBinary(adaptor.getOperands(), [&](const APInt &a, const APInt &b) {
        bounded = b.ult(256);
        return a.ashr(b);
      });
  return bounded ? result : Attribute();
}

OpFoldResult ArithDivOp::fold(FoldAdaptor adaptor) {
  if (matchPattern(adaptor.getRhs(), m_One()))
    return getLhs();
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return {};
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &a, const APInt &b) { return a.udiv(b); });
}

OpFoldResult ArithSDivOp::fold(FoldAdaptor adaptor) {
  if (matchPattern(adaptor.getRhs(), m_One()))
    return getLhs();
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return {};
  bool overflow = false;
  Attribute result =
      foldBinary(adaptor.getOperands(), [&](const APInt &a, const APInt &b) {
        return a.sdiv_ov(b, overflow);
      });
  return overflow ? Attribute() : result;
}

OpFoldResult ArithModOp::fold(FoldAdaptor adaptor) {
  if (matchPattern(adaptor.getRhs(), m_One()))
    return IntegerAttr::get(getType(), 0);
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return {};
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &a, const APInt &b) { return a.urem(b); });
}

OpFoldResult ArithSModOp::fold(FoldAdaptor adaptor) {
  if (matchPattern(adaptor.getRhs(), m_One()))
    return IntegerAttr::get(getType(), 0);
  if (matchPattern(adaptor.getRhs(), m_Zero()))
    return {};
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &a, const APInt &b) { return a.srem(b); });
}

OpFoldResult ArithSelectOp::fold(FoldAdaptor adaptor) {
  if (getTrueValue() == getFalseValue())
    return getTrueValue();
  APInt cond;
  if (!matchPattern(adaptor.getCondition(), m_ConstantInt(&cond)))
    return {};
  return cond.isZero() ? getFalseValue() : getTrueValue();
}

OpFoldResult DivOp::fold(FoldAdaptor adaptor) {
  return foldBinary(adaptor.getOperands(), [](const APInt &a, const APInt &b) {
    return b.isZero() ? b : a.udiv(b);
  });
}

OpFoldResult SDivOp::fold(FoldAdaptor adaptor) {
  return foldBinary(adaptor.getOperands(), [](const APInt &a, const APInt &b) {
    return b.isZero() ? b : a.sdiv(b);
  });
}

OpFoldResult ModOp::fold(FoldAdaptor adaptor) {
  return foldBinary(adaptor.getOperands(), [](const APInt &a, const APInt &b) {
    return b.isZero() ? b : a.urem(b);
  });
}

OpFoldResult SModOp::fold(FoldAdaptor adaptor) {
  return foldBinary(adaptor.getOperands(), [](const APInt &a, const APInt &b) {
    return b.isZero() ? b : a.srem(b);
  });
}

OpFoldResult ShlOp::fold(FoldAdaptor adaptor) {
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &shift, const APInt &val) {
                      if (shift.uge(256))
                        return APInt(256, 0);
                      return val.shl(shift);
                    });
}

OpFoldResult ShrOp::fold(FoldAdaptor adaptor) {
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &shift, const APInt &val) {
                      if (shift.uge(256))
                        return APInt(256, 0);
                      return val.lshr(shift);
                    });
}

OpFoldResult SarOp::fold(FoldAdaptor adaptor) {
  return foldBinary(
      adaptor.getOperands(), [](const APInt &shift, const APInt &val) {
        if (shift.uge(256))
          return val.isNegative() ? APInt::getAllOnes(256) : APInt(256, 0);
        return val.ashr(shift);
      });
}

OpFoldResult ClzOp::fold(FoldAdaptor adaptor) {
  return foldUnary(adaptor.getOperands(), [](const APInt &a) {
    return APInt(256, a.countLeadingZeros());
  });
}

OpFoldResult ExpOp::fold(FoldAdaptor adaptor) {
  return foldBinary(
      adaptor.getOperands(), [](const APInt &base, const APInt &exp) {
        APInt result(256, 1);
        APInt square = base;
        for (unsigned i = 0, e = exp.getActiveBits(); i < e; ++i) {
          if (exp[i])
            result *= square;
          square *= square;
        }
        return result;
      });
}

OpFoldResult AddModOp::fold(FoldAdaptor adaptor) {
  return foldTernary(adaptor.getOperands(), [](const APInt &x, const APInt &y,
                                               const APInt &mod) {
    if (mod.isZero())
      return mod;
    return (x.zext(257) + y.zext(257)).urem(mod.zext(257)).trunc(256);
  });
}

OpFoldResult MulModOp::fold(FoldAdaptor adaptor) {
  return foldTernary(adaptor.getOperands(), [](const APInt &x, const APInt &y,
                                               const APInt &mod) {
    if (mod.isZero())
      return mod;
    return (x.zext(512) * y.zext(512)).urem(mod.zext(512)).trunc(256);
  });
}

OpFoldResult SignExtendOp::fold(FoldAdaptor adaptor) {
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &idx, const APInt &val) {
                      if (idx.uge(31))
                        return val;
                      unsigned bits = 8 * (idx.getZExtValue() + 1);
                      return val.trunc(bits).sext(256);
                    });
}

OpFoldResult ByteOp::fold(FoldAdaptor adaptor) {
  return foldBinary(adaptor.getOperands(),
                    [](const APInt &idx, const APInt &val) {
                      if (idx.uge(32))
                        return APInt(256, 0);
                      unsigned shift = 256 - 8 * (idx.getZExtValue() + 1);
                      return val.lshr(shift) & APInt(256, 0xff);
                    });
}

bool mlir::yul::isI256OrI256LLVMStruct(Type type) {
  if (type.isSignlessInteger(256))
    return true;

  auto structTy = dyn_cast<LLVM::LLVMStructType>(type);
  if (!structTy || structTy.isOpaque())
    return false;

  return llvm::all_of(structTy.getBody(), [](Type elementTy) {
    return elementTy.isSignlessInteger(256);
  });
}

void ConstantOp::getAsmResultNames(
    function_ref<void(Value, StringRef)> setNameFn) {
  SmallString<32> specialNameBuffer;
  llvm::raw_svector_ostream specialName(specialNameBuffer);
  specialName << 'c' << getValueAttr().getValue() << '_' << getType();
  setNameFn(getResult(), specialName.str());
}

LogicalResult FuncOp::verify() {
  auto fnTy = getFunctionType();

  for (Type inputTy : fnTy.getInputs())
    if (!isI256OrI256LLVMStruct(inputTy))
      return emitOpError(
          "expects all input types to be i256 or LLVM structs containing only "
          "i256 elements");
  for (Type resultTy : fnTy.getResults())
    if (!isI256OrI256LLVMStruct(resultTy))
      return emitOpError(
          "expects all result types to be i256 or LLVM structs containing only "
          "i256 elements");

  if (!getBody().empty()) {
    Block &entryBlock = getBody().front();
    if (entryBlock.getNumArguments() != fnTy.getNumInputs())
      return emitOpError("expects entry block argument count to match the "
                         "function type input count");

    for (BlockArgument arg : entryBlock.getArguments())
      if (!isI256OrI256LLVMStruct(arg.getType()))
        return emitOpError("expects all entry block argument types to be i256 "
                           "or LLVM structs containing only i256 elements");

    for (auto [arg, inputTy] :
         llvm::zip(entryBlock.getArguments(), fnTy.getInputs()))
      if (arg.getType() != inputTy)
        return emitOpError("expects entry block argument types to match the "
                           "function type inputs");

    for (Block &block : getBody())
      for (FuncReturnOp returnOp : block.getOps<FuncReturnOp>())
        if (returnOp->getNumOperands() != fnTy.getNumResults())
          return returnOp.emitOpError("expects operand count to match the "
                                      "parent yul.func result count");
  }

  return success();
}

void ScopeOp::getSuccessorRegions(RegionBranchPoint point,
                                  SmallVectorImpl<RegionSuccessor> &regions) {
  if (!point.isParent()) {
    regions.push_back(RegionSuccessor());
    return;
  }
  regions.push_back(RegionSuccessor(&getBodyRegion()));
}

void IfOp::getSuccessorRegions(RegionBranchPoint point,
                               SmallVectorImpl<RegionSuccessor> &regions) {
  if (!point.isParent()) {
    regions.push_back(RegionSuccessor(getResults()));
    return;
  }

  regions.push_back(RegionSuccessor(&getThenRegion()));
  if (!getElseRegion().empty())
    regions.push_back(RegionSuccessor(&getElseRegion()));
}

void SwitchOp::getSuccessorRegions(RegionBranchPoint point,
                                   SmallVectorImpl<RegionSuccessor> &regions) {
  if (!point.isParent()) {
    regions.push_back(RegionSuccessor(getResults()));
    return;
  }

  llvm::copy(getRegions(), std::back_inserter(regions));
}

void SwitchOp::getRegionInvocationBounds(
    ArrayRef<Attribute> operands, SmallVectorImpl<InvocationBounds> &bounds) {
  auto operandValue = dyn_cast_or_null<IntegerAttr>(operands.front());
  if (!operandValue) {
    bounds.append(getNumRegions(), InvocationBounds(/*lb=*/0, /*ub=*/1));
    return;
  }

  unsigned liveIndex = 0;
  const auto it = llvm::find(getCases(), operandValue.getValue());
  if (it != getCases().end())
    liveIndex = std::distance(getCases().begin(), it) + 1;
  for (unsigned i = 0, e = getNumRegions(); i < e; ++i)
    bounds.emplace_back(/*lb=*/0, /*ub=*/i == liveIndex);
}

LogicalResult SwitchOp::verify() {
  auto caseElementTy = getCases().getType().getElementType();
  if (caseElementTy != getArg().getType())
    return emitOpError("expects case value type to match switch argument type");
  if (!caseElementTy.isInteger(256))
    return emitOpError("expects case value type to be i256");

  if (getCases().getNumElements() !=
      static_cast<int64_t>(getCaseRegions().size()))
    return emitOpError("expects case value count to match case region count");

  return success();
}

void LoopOpInterface::getLoopOpSuccessorRegions(
    LoopOpInterface op, RegionBranchPoint point,
    SmallVectorImpl<RegionSuccessor> &regions) {
  assert(point.isParent() || point.getRegionOrNull());

  // Branching to first region: go to condition.
  if (point.isParent()) {
    regions.emplace_back(&op.getEntry(), op.getEntry().getArguments());
  }
  // Branching from condition: go to body or exit.
  else if (&op.getCond() == point.getRegionOrNull()) {
    regions.emplace_back(RegionSuccessor(op->getResults()));
    regions.emplace_back(&op.getBody(), op.getBody().getArguments());
  }
  // Branching from body: go to step or condition.
  else if (&op.getBody() == point.getRegionOrNull()) {
    auto *afterBody = (op.maybeGetStep() ? op.maybeGetStep() : &op.getCond());
    regions.emplace_back(afterBody, afterBody->getArguments());
  }
  // Branching from step: go to condition.
  else if (op.maybeGetStep() == point.getRegionOrNull()) {
    regions.emplace_back(&op.getCond(), op.getCond().getArguments());
  } else {
    llvm_unreachable("unexpected branch origin");
  }
}

void ForOp::getSuccessorRegions(RegionBranchPoint point,
                                SmallVectorImpl<RegionSuccessor> &regions) {
  LoopOpInterface::getLoopOpSuccessorRegions(*this, point, regions);
}

SmallVector<Region *> ForOp::getLoopRegions() { return {&getBody()}; }

OperandRange ForOp::getEntrySuccessorOperands(RegionBranchPoint point) {
  assert(point == getCond() &&
         "yul.for entry successor is expected to be the condition region");
  return getInitArgs();
}

MutableArrayRef<OpOperand> ForOp::getInitsMutable() {
  return (*this)->getOpOperands();
}

Block::BlockArgListType ForOp::getRegionIterArgs() {
  return getCond().front().getArguments();
}

std::optional<MutableArrayRef<OpOperand>> ForOp::getYieldedValuesMutable() {
  auto yieldOp = dyn_cast<YieldOp>(getStep().front().getTerminator());
  if (!yieldOp)
    return std::nullopt;
  return yieldOp.getOperandsMutable();
}

std::optional<ResultRange> ForOp::getLoopResults() { return getResults(); }

void WhileOp::getSuccessorRegions(RegionBranchPoint point,
                                  SmallVectorImpl<RegionSuccessor> &regions) {
  LoopOpInterface::getLoopOpSuccessorRegions(*this, point, regions);
}

SmallVector<Region *> WhileOp::getLoopRegions() { return {&getBody()}; }

OperandRange WhileOp::getEntrySuccessorOperands(RegionBranchPoint point) {
  assert(point == getCond() &&
         "yul.while entry successor is expected to be the condition region");
  return getInitArgs();
}

MutableArrayRef<OpOperand> WhileOp::getInitsMutable() {
  return (*this)->getOpOperands();
}

Block::BlockArgListType WhileOp::getRegionIterArgs() {
  return getCond().front().getArguments();
}

std::optional<MutableArrayRef<OpOperand>> WhileOp::getYieldedValuesMutable() {
  auto yieldOp = dyn_cast<YieldOp>(getBody().front().getTerminator());
  if (!yieldOp)
    return std::nullopt;
  return yieldOp.getOperandsMutable();
}

std::optional<ResultRange> WhileOp::getLoopResults() { return getResults(); }

void DoWhileOp::getSuccessorRegions(RegionBranchPoint point,
                                    SmallVectorImpl<RegionSuccessor> &regions) {
  LoopOpInterface::getLoopOpSuccessorRegions(*this, point, regions);
}

SmallVector<Region *> DoWhileOp::getLoopRegions() { return {&getBody()}; }

OperandRange DoWhileOp::getEntrySuccessorOperands(RegionBranchPoint point) {
  assert(point == getBody() &&
         "yul.do entry successor is expected to be the body region");
  auto operandEnd = (*this)->operand_end();
  return OperandRange(operandEnd, operandEnd);
}

MutableArrayRef<OpOperand> DoWhileOp::getInitsMutable() { return {}; }

Block::BlockArgListType DoWhileOp::getRegionIterArgs() {
  return Block::BlockArgListType();
}

std::optional<MutableArrayRef<OpOperand>> DoWhileOp::getYieldedValuesMutable() {
  auto yieldOp = dyn_cast<YieldOp>(getBody().front().getTerminator());
  if (!yieldOp)
    return std::nullopt;
  return yieldOp.getOperandsMutable();
}

std::optional<ResultRange> DoWhileOp::getLoopResults() {
  return (*this)->getResults();
}

void SwitchOp::print(OpAsmPrinter &p) {
  p << ' ' << getArg() << " : " << getArg().getType();
  if (!getResultTypes().empty())
    p << " -> " << getResultTypes();
  p.printOptionalAttrDict((*this)->getAttrs(),
                          /*elidedAttrs=*/getCasesAttrName().getValue());

  for (auto [val, region] : llvm::zip(getCases(), getCaseRegions())) {
    p.printNewline();
    p << "case ";
    // Yul integers are unsigned words.
    val.print(p.getStream(), /*isSigned=*/false);
    p << ' ';
    p.printRegion(region, /*printEntryBlockArgs=*/false);
  }

  p.printNewline();
  p << "default ";
  p.printRegion(getDefaultRegion(), /*printEntryBlockArgs=*/false);
}

ParseResult SwitchOp::parse(OpAsmParser &p, OperationState &result) {
  OpAsmParser::UnresolvedOperand arg;
  IntegerType argTy;
  if (p.parseOperand(arg) || p.parseColon() || p.parseType(argTy) ||
      p.resolveOperand(arg, argTy, result.operands) ||
      p.parseOptionalArrowTypeList(result.types) ||
      p.parseOptionalAttrDict(result.attributes))
    return failure();

  Region *defRegion = result.addRegion();
  SmallVector<APInt> caseVals;
  while (succeeded(p.parseOptionalKeyword("case"))) {
    llvm::SMLoc caseLoc = p.getCurrentLocation();
    // Yul integers are unsigned words with no negative literals, so reject a
    // minus outright (like the Yul parser does) instead of granting it a
    // two's-complement reading. Reject the sign itself: parseInteger would
    // consume it, and "-0" would then come back as a non-negative zero.
    if (succeeded(p.parseOptionalMinus()))
      return p.emitError(caseLoc, "negative case values are not allowed");
    APInt value(argTy.getWidth(), 0);
    Region *region = result.addRegion();
    if (p.parseInteger(value) || p.parseRegion(*region))
      return failure();
    if (value.getActiveBits() > argTy.getWidth())
      return p.emitError(caseLoc,
                         "case value does not fit the switch argument type");
    caseVals.push_back(value.zextOrTrunc(argTy.getWidth()));
  }
  auto caseValsAttr = DenseIntElementsAttr::get(
      RankedTensorType::get({static_cast<int64_t>(caseVals.size())}, argTy),
      caseVals);
  result.addAttribute(getCasesAttrName(result.name), caseValsAttr);

  if (p.parseKeyword("default") || p.parseRegion(*defRegion))
    return failure();

  return success();
}

LogicalResult ObjectOp::verify() {
  // A module lowers to a single object, whose entry function becomes the
  // module's.
  for (Operation &sibling : *getOperation()->getBlock())
    if (&sibling != getOperation() && isa<ObjectOp>(sibling))
      return emitOpError("expects no other yul.object in its module, found '")
             << cast<ObjectOp>(sibling).getSymName() << "'";

  for (Operation &op : *getBody())
    if (!isa<FunctionOpInterface, LLVM::GlobalOp>(op))
      return emitOpError("expects only functions and globals, found '")
             << op.getName() << "'";
  if (!getEntryFn())
    return emitOpError("expects a function named '")
           << FuncOp::entryName << "'";
  return success();
}

#define GET_OP_CLASSES
#include "mlir/Dialect/Yul/YulOps.cpp.inc"
