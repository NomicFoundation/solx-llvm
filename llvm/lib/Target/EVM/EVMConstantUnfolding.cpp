//===----- EVMConstantUnfolding.cpp - Constant unfolding -------*- C++ -*--===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implement large constants unfolding.
//
// Large constants are broken into sequences of operations
// to reduce bytecode size. For example,
//
//   PUSH32 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000
//   (33 bytes)
//
// can be replaced with
//
//   PUSH4  0xFFFFFFFF
//   PUSH1  0xE0
//   SHL
//   (8 bytes)
//
//===----------------------------------------------------------------------===//

#include "EVM.h"
#include "EVMCalculateModuleSize.h"
#include "EVMInstrInfo.h"
#include "EVMSubtarget.h"
#include "MCTargetDesc/EVMMCTargetDesc.h"
#include "TargetInfo/EVMTargetInfo.h"
#include "llvm/ADT/SCCIterator.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/CallGraph.h"
#include "llvm/CodeGen/MachineBlockFrequencyInfo.h"
#include "llvm/CodeGen/MachineBranchProbabilityInfo.h"
#include "llvm/CodeGen/MachineDominators.h"
#include "llvm/CodeGen/MachineLoopInfo.h"
#include "llvm/CodeGen/MachineModuleInfo.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/PassInstrumentation.h"
#include "llvm/InitializePasses.h"
#include "llvm/Support/Debug.h"
#include <functional>

using namespace llvm;

#define DEBUG_TYPE "evm-constant-unfolding"
#define PASS_NAME "EVM constant unfolding"

STATISTIC(StatNumOfUnfoldings, "Number of unfolded constants");
STATISTIC(StatCodeSizeReduction, "Total size reduction across all functions");

// The values of the following options were determined experimentally to allow
// constant unfolding in non-OptForSize mode without noticeably impacting
// performance. The size reduction threshold is flat between 1.05 and 1.4 over
// the OpenZeppelin, uniswap-v4-core, ENS, Aave v3 and Graph Horizon projects,
// the size falls monotonically as the threshold approaches 1 and the selection
// below already guarantees a ratio above it, so 1.05 keeps a small margin
// without giving up bytes.
static cl::opt<float>
    SizeReductionThreshold("evm-const-unfolding-size-reduction-threshold",
                           cl::Hidden, cl::init(1.05),
                           cl::desc("Minimum original-to-unfolded size ratio"
                                    "required for constant unfolding when"
                                    "optimizing for speed"));

static cl::opt<unsigned> InstrNumLimitUnfoldInto(
    "evm-const-unfolding-inst-num-limit", cl::Hidden, cl::init(4),
    cl::desc("Maximum number of instructions an original"
             "instruction can be unfolded into"));

// How heavily the gas of a recomputed constant counts against its bytes when
// optimizing for speed, and how fast that grows with loop nesting. A constant
// outside any loop runs about as often as its function, so its bytes dominate;
// one inside a loop pays its gas on every iteration. The weight at loop depth
// d is GasWeight * LoopGasFactor^d, so 0.19, 0.57 and 1.71 at depths 0, 1 and
// 2. The crossover is what these values are chosen around: an all-ones mask
// unfolds to PUSH0 NOT PUSHn SHR, 5 bytes and 11 gas against 9 bytes and 3
// gas, which wins only while the weight is below 0.5. Depth 0 is therefore
// unfolded and depth 1 and deeper are not.
constexpr float GasWeight = 0.19F;
constexpr float LoopGasFactor = 3.0F;

// A function that takes part in a call graph cycle runs its body once per
// level of recursion, which MachineLoopInfo cannot see: it reports only the
// natural loops inside one function, so every block of a recursive function
// reports depth 0. Count such a function as this many levels of nesting so
// that its constants are priced like a loop body.
constexpr unsigned RecursionDepthBonus = 2;

static cl::opt<unsigned>
    LoopDepthLimit("evm-const-loop-depth-limit", cl::Hidden, cl::init(2),
                   cl::desc("The maximum loop depth at which constant"
                            "unfolding is still considered beneficial"));

static cl::opt<unsigned>
    CodeSizeLimit("evm-bytecode-sizelimit", cl::Hidden, cl::init(24576),
                  cl::desc("EVM contract bytecode size limit"));

static cl::opt<unsigned> MetadataSize("evm-metadata-size", cl::Hidden,
                                      cl::init(0),
                                      cl::desc("EVM metadata size"));

namespace {
using InstrsPerLoopDepthTy = SmallVector<SmallVector<MachineInstr *>>;

// Estimates the execution cost of EVM-style stack operations.
// Tracks instruction count, gas cost, and unfolded bytecode size.
// It abstracts gas accounting for pushes and simple arithmetic/logical
// operations.
class StackCostModel {
public:
  StackCostModel() = default;

  void accountInstr(unsigned Opc, const TargetInstrInfo *TII) {
    ++InstrCount;
    const MCInstrDesc &Desc = TII->get(Opc);
    ByteSize += Desc.getSize();
    Gas += EVMInstrInfo::getGasCost(Desc);
  }

  unsigned getInstrCount() const { return InstrCount; }
  unsigned getByteSize() const { return ByteSize; }
  unsigned getGas() const { return Gas; }

private:
  unsigned InstrCount{0};
  unsigned ByteSize{0};
  unsigned Gas{0};
};

// Builds and applies a sequence of machine instructions required to
// unfold a constant. Instruction generation is deferred using lambdas,
// allowing the TransformationCandidate object to be reused for repeated
// constants. As new instructions are added, the StackCostModel is used
// to track the accumulated cost.
class TransformationCandidate {
public:
  TransformationCandidate(LLVMContext &Context, const TargetInstrInfo *TII)
      : Context(Context), TII(TII) {}

  void addShl() {
    constexpr unsigned Opc = EVM::SHL_S;
    CostModel.accountInstr(Opc, TII);
    BuildItems.push_back([this](MachineInstr &MI) { insertInstr(MI, Opc); });
  }

  void addShr() {
    constexpr unsigned Opc = EVM::SHR_S;
    CostModel.accountInstr(Opc, TII);
    BuildItems.push_back([this](MachineInstr &MI) { insertInstr(MI, Opc); });
  }

  void addNot() {
    constexpr unsigned Opc = EVM::NOT_S;
    CostModel.accountInstr(Opc, TII);
    BuildItems.push_back([this](MachineInstr &MI) { insertInstr(MI, Opc); });
  }

  void addImm(const APInt &Val) {
    unsigned Opc = EVM::getStackOpcode(EVM::getPUSHOpcode(Val));
    CostModel.accountInstr(Opc, TII);
    BuildItems.push_back([this, Opc, Val = Val](MachineInstr &MI) {
      insertImmInstr(MI, Opc, Val);
    });
  }

  // Applies queued build instruction steps to replace a given instruction.
  void apply(MachineInstr &MI) const {
    for (const auto &func : BuildItems)
      func(MI);
  }

  const StackCostModel &getCost() const { return CostModel; }

private:
  using BuildFunction = std::function<void(MachineInstr &)>;

  LLVMContext &Context;
  const TargetInstrInfo *TII{};

  StackCostModel CostModel;
  SmallVector<BuildFunction, 16> BuildItems;

  void insertInstr(MachineInstr &MI, unsigned Opc) {
    BuildMI(*MI.getParent(), MI, MI.getDebugLoc(), TII->get(Opc));
  }

  void insertImmInstr(MachineInstr &MI, unsigned Opc, const APInt &Val) {
    auto NewMI = BuildMI(*MI.getParent(), MI, MI.getDebugLoc(), TII->get(Opc));
    if (Opc != EVM::PUSH0_S)
      NewMI.addCImm(ConstantInt::get(Context, Val));
  }
};

// Discovers, applies, and caches optimal constant unfolding
// transformations.
class ConstantUnfolder {
public:
  explicit ConstantUnfolder(LLVMContext *Context) : Context(Context) {}

  unsigned getCodeSizeReduction() const { return OverallCodeReductionSize; }

  bool tryToUnfoldConstant(MachineInstr &MI, bool OptForSize,
                           unsigned QuantizedWeight,
                           const TargetInstrInfo *TII);

private:
  LLVMContext *Context{};

  // The 'second' field is -1 when optimizing for size, and otherwise the
  // quantized gas weight the constant is scored with.
  using TransformationKey = std::pair<APInt, int>;
  DenseMap<TransformationKey, std::unique_ptr<TransformationCandidate>>
      TransformationCache;

  unsigned OverallCodeReductionSize{0};

  const TransformationCandidate *
  findOptimalTransformation(const APInt &Imm, bool OptForSize,
                            unsigned QuantizedWeight,
                            const TargetInstrInfo *TII);

  void reduceCodeSizeOn(unsigned Size) {
    OverallCodeReductionSize += Size;
    ++StatNumOfUnfoldings;
  }
};

class EVMConstantUnfolding final : public ModulePass {
public:
  static char ID;

  EVMConstantUnfolding() : ModulePass(ID) {
    initializeEVMConstantUnfoldingPass(*PassRegistry::getPassRegistry());
  }

private:
  StringRef getPassName() const override { return PASS_NAME; }

  bool runOnModule(Module &M) override;

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<MachineModuleInfoWrapperPass>();
    AU.addPreserved<MachineModuleInfoWrapperPass>();
    AU.setPreservesAll();
    ModulePass::getAnalysisUsage(AU);
  }
};
} // end anonymous namespace

char EVMConstantUnfolding::ID = 0;

INITIALIZE_PASS_BEGIN(EVMConstantUnfolding, DEBUG_TYPE, PASS_NAME, false, false)
INITIALIZE_PASS_DEPENDENCY(MachineModuleInfoWrapperPass)
INITIALIZE_PASS_END(EVMConstantUnfolding, DEBUG_TYPE, PASS_NAME, false, false)

ModulePass *llvm::createEVMConstantUnfolding() {
  return new EVMConstantUnfolding();
}

// Returns how heavily gas counts against bytes at \p LoopDepth.
static float gasWeightAt(unsigned LoopDepth) {
  float Weight = GasWeight;
  for (unsigned I = 0; I < LoopDepth; ++I)
    Weight *= LoopGasFactor;

  return Weight;
}

// The gas weight is quantized to sixteenths so the transformation cache stays
// small; a weight of 1.0 is the key 16.
static constexpr unsigned WeightScale = 16;

static unsigned quantizeWeight(float Weight) {
  return static_cast<unsigned>(
      std::lround(std::min(Weight, 64.0f) * WeightScale));
}

static float weightOf(unsigned Quantized) {
  return static_cast<float>(Quantized) / WeightScale;
}

static bool isBetterCandidate(const TransformationCandidate &A,
                              const TransformationCandidate &B, bool OptForSize,
                              unsigned QuantizedWeight) {
  static constexpr unsigned SizeWeight = 2;
  const StackCostModel &CostA = A.getCost();
  const StackCostModel &CostB = B.getCost();
  float ScoreA = 0;
  float ScoreB = 0;

  if (OptForSize) {
    ScoreA = (CostA.getByteSize() * SizeWeight) + CostA.getGas();
    ScoreB = (CostB.getByteSize() * SizeWeight) + CostB.getGas();
  } else {
    const float Weight = weightOf(QuantizedWeight);
    ScoreA = CostA.getByteSize() + (Weight * CostA.getGas());
    ScoreB = CostB.getByteSize() + (Weight * CostB.getGas());
  }
  if (ScoreA != ScoreB)
    return ScoreA < ScoreB;

  return CostA.getByteSize() < CostB.getByteSize();
}

const TransformationCandidate *
ConstantUnfolder::findOptimalTransformation(const APInt &Imm, bool OptForSize,
                                            unsigned QuantizedWeight,
                                            const TargetInstrInfo *TII) {
  const int Key = OptForSize ? -1 : static_cast<int>(QuantizedWeight);
  if (auto It = TransformationCache.find({Imm, Key});
      It != TransformationCache.end()) {
    LLVM_DEBUG(
        { dbgs() << "      Retrieving transformation from the cache\n"; });

    return It->second.get();
  }

  // Decompose a given immediate operand of the form:
  //
  //   0x0000001...100000000
  //
  // into:
  //    - trailing and leading zero bits
  //    - 'Val' part, that starts and ends with '1'
  //    - abs('Val')
  //
  unsigned Ones = Imm.popcount();
  unsigned TrailZ = Imm.countTrailingZeros();
  unsigned LeadZ = Imm.countLeadingZeros();
  APInt Val = Imm.extractBits(Imm.getBitWidth() - TrailZ - LeadZ, TrailZ);
  unsigned ValLen = Val.getActiveBits();
  bool IsMask = ((Ones + LeadZ + TrailZ) == Imm.getBitWidth());
  assert(ValLen == (Imm.getBitWidth() - TrailZ - LeadZ));
  assert(Val.isNegative());

  SmallVector<std::unique_ptr<TransformationCandidate>, 8> Transformations;

  // 1. A transformation that represents an immediate value as:
  //
  //    (~(AbsVal - 1) << shift_l) >> shift_r
  //
  // For example,
  //
  //   0x00000000FFFFFFFFFFFFFF000000000000000000000000000000000000000000
  //
  // is represented as:
  //
  //   (~0 << 200) >> 32
  //
  // Cost:
  //   PUSH AbsVal     // 1 + AbsValLen
  //   NOT             // 1
  //   PUSH1 shiftl    // 2
  //   SHR             // 1
  //   -------------------- // Optional
  //   PUSH1 shiftr    // 2
  //   SHL             // 1
  //
  {
    auto Tr = std::make_unique<TransformationCandidate>(*Context, TII);
    assert(!Val.abs().isZero());
    Tr->addImm(Val.abs() - 1);
    Tr->addNot();
    Tr->addImm(APInt(256, 256 - ValLen));
    Tr->addShl();
    if (LeadZ) {
      Tr->addImm(APInt(256, LeadZ));
      Tr->addShr();
    }
    Transformations.emplace_back(std::move(Tr));
  }

  // 2. A transformation that represents an immediate value in the
  //    form of a right-shifted mask.
  //
  // For example,
  //
  //   0x0000000000000000000000000000000000000000000000000000FFFFFFFFFFFF
  //
  // is represented as:
  //
  //   (~0) >> 192
  //
  // Cost:
  //   PUSH0            // 1
  //   NOT              // 1
  //   PUSH1 shift      // 2
  //   SHR              // 1
  //
  if (IsMask && !TrailZ) {
    assert(ValLen != 256);
    auto Tr = std::make_unique<TransformationCandidate>(*Context, TII);
    Tr->addImm(APInt::getZero(256));
    Tr->addNot();
    Tr->addImm(APInt(256, 256 - ValLen));
    Tr->addShr();
    Transformations.emplace_back(std::move(Tr));
  }

  // 3. A transformation that expresses an immediate value as a smaller
  //    bit-width value shifted to the left
  //
  // For example,
  //
  //   0xFFFFFF0000000000000000000000000000000000000000000000000000000000
  //
  // is represented as:
  //
  //   0xFFFFFF << 192
  //
  // Cost:
  //   PUSH  Val        // 1 + ValLen
  //   PUSH1 shift      // 2
  //   SHL              // 1
  //
  if (TrailZ) {
    auto Tr = std::make_unique<TransformationCandidate>(*Context, TII);
    Tr->addImm(Val);
    Tr->addImm(APInt(256, TrailZ));
    Tr->addShl();
    Transformations.emplace_back(std::move(Tr));
  }

  if (!LeadZ) {
    // 4. A transformation that represents an immediate value in the
    //    form of bit-reversing.
    //
    // For example,
    //
    //   0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE
    //
    // is represented as:
    //
    //   ~0x01
    //
    // Cost:
    //   PUSH             // 1 InvImm
    //   NOT              // 1
    //
    {
      auto Tr = std::make_unique<TransformationCandidate>(*Context, TII);
      Tr->addImm(~Imm);
      Tr->addNot();
      Transformations.emplace_back(std::move(Tr));
    }

    // 5. A transformation that represents an immediate value by reversing its
    //    bits and representing the reversed portion using a left shift
    //    operation.
    //
    // For example,
    //
    //   0xFFFFFFFFFFFFFFFFFFFFFFFFF7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    //
    // is represented as:
    //
    //   ~(0x01 << 155)
    //
    // Cost:
    //   PUSH             // 1 InvImmVal
    //   PUSH1 shift      // 2
    //   SHL              // 1
    //   NOT              // 1
    //
    {
      auto Tr = std::make_unique<TransformationCandidate>(*Context, TII);
      APInt ImmNot = ~Imm;
      unsigned Tz = ImmNot.countTrailingZeros();
      unsigned Lz = ImmNot.countLeadingZeros();
      APInt ImmNotVal = ImmNot.extractBits(ImmNot.getBitWidth() - Tz - Lz, Tz);
      Tr->addImm(ImmNotVal);
      Tr->addImm(APInt(256, Tz));
      Tr->addShl();
      Tr->addNot();
      Transformations.emplace_back(std::move(Tr));
    }
  }

  // 6. No transformation, leave immediate as is.
  {
    auto Tr = std::make_unique<TransformationCandidate>(*Context, TII);
    Tr->addImm(Imm);
    Transformations.emplace_back(std::move(Tr));
  }

  // Find optimal transformation.
  auto *OptIt = std::min_element(
      Transformations.begin(), Transformations.end(),
      [OptForSize, QuantizedWeight](const auto &A, const auto &B) {
        return isBetterCandidate(*A, *B, OptForSize, QuantizedWeight);
      });

#ifndef NDEBUG
  LLVM_DEBUG({ dbgs() << "      Available transformations:\n"; });
  for (const auto &Tr : Transformations) {
    const StackCostModel &Cost = Tr->getCost();
    LLVM_DEBUG({
      dbgs() << "       [size: " << Cost.getByteSize()
             << ", instr count: " << Cost.getInstrCount()
             << ", gas: " << Cost.getGas() << "]\n";
    });
  }
#endif // NDEBUG

  const TransformationCandidate *Tr = OptIt->get();
  [[maybe_unused]] auto Res =
      TransformationCache.try_emplace({Imm, Key}, std::move(*OptIt));
  assert(Res.second);

  return Tr;
}

static bool isProfitableToTranform(const APInt &Imm, const StackCostModel &Cost,
                                   bool OptForSize) {
  if (OptForSize)
    return true;

  unsigned OrigSize = (alignTo(Imm.getActiveBits(), 8) / 8) + 1;
  // When optimizing for speed, only unfold constants if it reduces the size
  // by a factor of at least the 'SizeReductionThreshold' and keeps the
  // instruction count to 'InstrNumLimitUnfoldInto' or fewer.
  if ((static_cast<float>(OrigSize) / static_cast<float>(Cost.getByteSize()) <
       SizeReductionThreshold) ||
      Cost.getInstrCount() > InstrNumLimitUnfoldInto)
    return false;

  return true;
}

bool ConstantUnfolder::tryToUnfoldConstant(MachineInstr &MI, bool OptForSize,
                                           unsigned QuantizedWeight,
                                           const TargetInstrInfo *TII) {
  const APInt Imm = MI.getOperand(0).getCImm()->getValue().zext(256);
  unsigned OrigSize = (alignTo(Imm.getActiveBits(), 8) / 8) + 1;
  assert(Imm.getActiveBits() > 4 * 8);

  // Check for the -1 value early
  if (Imm.isAllOnes()) {
    auto Tr = std::make_unique<TransformationCandidate>(*Context, TII);
    Tr->addImm(APInt::getZero(256));
    Tr->addNot();
    Tr->apply(MI);
    MI.eraseFromParent();
    assert(OrigSize > Tr->getCost().getByteSize());
    reduceCodeSizeOn(OrigSize - Tr->getCost().getByteSize());

    LLVM_DEBUG({ dbgs() << "      Transforming -1 to ~0\n"; });
    return true;
  }

  const TransformationCandidate *OptTransformation =
      findOptimalTransformation(Imm, OptForSize, QuantizedWeight, TII);

  const StackCostModel &OptCost = OptTransformation->getCost();
  LLVM_DEBUG({
    dbgs() << "      Optimal transformation:\n"
           << "       [size: " << OptCost.getByteSize()
           << ", instr count: " << OptCost.getInstrCount()
           << ", gas: " << OptCost.getGas() << "]\n";
  });

  if (OptCost.getInstrCount() == 1) {
    LLVM_DEBUG({ dbgs() << "      Skipping identity transformation\n"; });
    return false;
  }

  if (isProfitableToTranform(Imm, OptCost, OptForSize)) {
    OptTransformation->apply(MI);
    MI.eraseFromParent();
    assert(OrigSize > OptCost.getByteSize());
    reduceCodeSizeOn(OrigSize - OptCost.getByteSize());
    return true;
  }

  LLVM_DEBUG({
    dbgs() << "      Transformation is omitted as its effect does not meet the"
           << " required reduction threshold\n";
  });

  return false;
}

static bool shouldSkip(const MachineInstr &MI) {
  if (!EVMInstrInfo::isPush(&MI))
    return true;

  // It’s not practical to check small constants, since the default
  // instructions are cheapest in those cases. The limit is based on the
  // fact that the most compact transformation for representing a
  // constant requires at least 5 bytes.
  switch (MI.getOpcode()) {
  case EVM::PUSH0_S:
  case EVM::PUSH1_S:
  case EVM::PUSH2_S:
  case EVM::PUSH3_S:
  case EVM::PUSH4_S: {
    return true;
  }
  default:
    return false;
  }
}

// This helper class organizes a MF’s instructions by their loop nesting depth,
// as reported by MachineLoopInfo. It builds a SmallVector of buckets, where
// each bucket contains the MIs for a specific loop depth (0 = out of loop,
// 1 - top level loop, etc.).
class LoopDepthInstrCache {
public:
  LoopDepthInstrCache(MachineFunction &MF, const MachineLoopInfo &MLI,
                      const MachineBlockFrequencyInfo &MBFI,
                      unsigned RecursionBonus) {
    unsigned MaxLoopDepth = 0;
    for (auto *ML : MLI.getLoopsInPreorder())
      MaxLoopDepth = std::max(MaxLoopDepth, ML->getLoopDepth());

    InstrsPerLoopDepth.resize(MaxLoopDepth + 1);
    for (MachineBasicBlock &MBB : MF) {
      for (MachineInstr &MI : MBB) {
        if (shouldSkip(MI))
          continue;

        unsigned Depth = MLI.getLoopDepth(&MBB);
        assert(Depth < InstrsPerLoopDepth.size());
        InstrsPerLoopDepth[Depth].push_back(&MI);
      }

      // Nesting sets the weight; a block reached less than once per call then
      // discounts it, which is what tells a revert block apart from ordinary
      // straight-line code at the same depth. The clamp keeps this a discount:
      // a hot block is priced by its nesting, never by its frequency.
      float Weight = gasWeightAt(MLI.getLoopDepth(&MBB) + RecursionBonus);
      if (MBFI.getEntryFreq() != BlockFrequency(0))
        Weight *= std::min(
            1.0F,
            static_cast<float>(MBFI.getBlockFreqRelativeToEntryBlock(&MBB)));
      QuantizedWeight[&MBB] = quantizeWeight(Weight);
    }

    LLVM_DEBUG({
      dbgs() << "Instructions in function: " << MF.getName() << '\n';
      for (unsigned Depth = 0; Depth < InstrsPerLoopDepth.size(); ++Depth) {
        dbgs() << "  loop depth: " << Depth << '\n';
        for (const MachineInstr *MI : InstrsPerLoopDepth[Depth])
          dbgs() << "    " << *MI << '\n';
      }
    });
  }

  LoopDepthInstrCache(const LoopDepthInstrCache &) = delete;
  LoopDepthInstrCache &operator=(const LoopDepthInstrCache &) = delete;
  LoopDepthInstrCache(LoopDepthInstrCache &&) noexcept = default;
  LoopDepthInstrCache &operator=(LoopDepthInstrCache &&) noexcept = default;
  ~LoopDepthInstrCache() = default;

  const InstrsPerLoopDepthTy &getInstructionsPerLoopDepth() const {
    return InstrsPerLoopDepth;
  }

  SmallVector<MachineInstr *> getAllInstructions() const {
    SmallVector<MachineInstr *> Instrs;
    for (const SmallVector<MachineInstr *> &Bucket : InstrsPerLoopDepth)
      Instrs.append(Bucket.begin(), Bucket.end());

    return Instrs;
  }

  DenseSet<const MachineInstr *> &getVisited() { return Visited; }

  unsigned getQuantizedWeight(const MachineInstr &MI) const {
    auto It = QuantizedWeight.find(MI.getParent());
    return It == QuantizedWeight.end() ? quantizeWeight(GasWeight) : It->second;
  }

private:
  InstrsPerLoopDepthTy InstrsPerLoopDepth;
  DenseMap<const MachineBasicBlock *, unsigned> QuantizedWeight;
  DenseSet<const MachineInstr *> Visited;
};

static bool processInstructions(ConstantUnfolder &Unfolder,
                                const SmallVector<MachineInstr *> &Instrs,
                                LoopDepthInstrCache &Cache, bool OptForSize,
                                const TargetInstrInfo *TII) {
  DenseSet<const MachineInstr *> &Visited = Cache.getVisited();
  bool Changed = false;
  for (MachineInstr *MI : Instrs) {
    if (Visited.count(MI))
      continue;

    LLVM_DEBUG({ dbgs() << "     Checking " << *MI; });

    if (Unfolder.tryToUnfoldConstant(*MI, OptForSize,
                                     Cache.getQuantizedWeight(*MI), TII)) {
      Visited.insert(MI);
      Changed = true;
    }
  }

  return Changed;
}

/// Returns the functions that take part in a call graph cycle, directly or
/// through other functions. Mirrors how the inlining policy finds them.
static DenseSet<const Function *> collectRecursiveFunctions(Module &M) {
  DenseSet<const Function *> Recursive;
  CallGraph CG(M);
  for (auto SCCI = scc_begin(&CG); !SCCI.isAtEnd(); ++SCCI) {
    const std::vector<CallGraphNode *> &SCC = *SCCI;
    if (SCC.size() == 1 && !SCCI.hasCycle())
      continue;
    for (const CallGraphNode *Node : SCC)
      if (const Function *F = Node->getFunction(); F && !F->isDeclaration())
        Recursive.insert(F);
  }

  return Recursive;
}

static bool runImpl(Module &M, MachineModuleInfo &MMI) {
  bool Changed = false;
  ConstantUnfolder Unfolder(&M.getContext());
  const DenseSet<const Function *> Recursive = collectRecursiveFunctions(M);

  // Metadata size is included into the bytecode size.
  const unsigned ModuleCodeSize =
      EVM::calculateModuleCodeSize(M, MMI) + MetadataSize;

  // Collect PUSH instructions to process.
  SmallVector<
      std::pair<MachineFunction *, std::unique_ptr<LoopDepthInstrCache>>, 16>
      InstrCacheMap;

  for (Function &F : M) {
    MachineFunction *MF = MMI.getMachineFunction(F);
    if (!MF)
      continue;

    // Compute MachineLoopInfo on the fly, as it's not available on the
    // Module pass level.
    auto OwnedMDT = std::make_unique<MachineDominatorTree>();
    OwnedMDT->recalculate(*MF);
    MachineDominatorTree *MDT = OwnedMDT.get();

    auto OwnedMLI = std::make_unique<MachineLoopInfo>();
    OwnedMLI->analyze(*MDT);
    const MachineLoopInfo *MLI = OwnedMLI.get();

    MachineBranchProbabilityInfo MBPI;
    MachineBlockFrequencyInfo MBFI;
    MBFI.calculate(*MF, MBPI, *MLI);

    // A recursive function has no MachineLoop, so charge its body the
    // recursion bonus on top of whatever nesting it does have.
    const unsigned Bonus = Recursive.contains(&F) ? RecursionDepthBonus : 0;

    InstrCacheMap.emplace_back(
        MF, std::make_unique<LoopDepthInstrCache>(*MF, *MLI, MBFI, Bonus));
  }

  LLVM_DEBUG({
    dbgs() << "*** Running constant unfolding in the default mode ***\n";
    dbgs() << "*** Initial module size: " << ModuleCodeSize << " ***\n";
  });

  // First, process all PUSH instructions in the default mode, selecting
  // unfolding heuristics based on whether the OptSize flag is set for
  // the MachineFunction.
  for (auto &[MF, Cache] : InstrCacheMap) {
    LLVM_DEBUG({ dbgs() << "  Checking function: " << MF->getName() << '\n'; });

    bool OptForSize = MF->getFunction().hasOptSize();
    const EVMInstrInfo *TII = MF->getSubtarget<EVMSubtarget>().getInstrInfo();
    Changed |= processInstructions(Unfolder, Cache->getAllInstructions(),
                                   *Cache, OptForSize, TII);
  }

  unsigned CodeSizeReduction = Unfolder.getCodeSizeReduction();
  if (ModuleCodeSize < CodeSizeLimit + CodeSizeReduction) {
    StatCodeSizeReduction = CodeSizeReduction;
    return Changed;
  }

  LLVM_DEBUG({
    dbgs() << "*** Current module size is "
           << ModuleCodeSize - CodeSizeReduction
           << ", which still exceeds the limit, falling back to "
              "size-minimization mode ***\n";
  });

  // First, process all PUSH instructions in the default mode, selecting
  // unfolding heuristics based on whether the OptSize flag is set for
  // the MachineFunction.
  for (unsigned LoopDepth = 0; LoopDepth <= LoopDepthLimit; ++LoopDepth) {
    LLVM_DEBUG({
      dbgs() << "*** Running constant unfolding in "
                "size-minimization mode at loop depth "
             << LoopDepth << " ***\n";
    });

    for (auto &[MF, Cache] : InstrCacheMap) {
      LLVM_DEBUG(
          { dbgs() << "  Checking function: " << MF->getName() << '\n'; });

      const InstrsPerLoopDepthTy &InstrsPerLoopDepth =
          Cache->getInstructionsPerLoopDepth();
      if (LoopDepth >= InstrsPerLoopDepth.size())
        continue;

      const EVMInstrInfo *TII = MF->getSubtarget<EVMSubtarget>().getInstrInfo();
      Changed |=
          processInstructions(Unfolder, InstrsPerLoopDepth[LoopDepth], *Cache,
                              /*OptForSize=*/true, TII);

      CodeSizeReduction = Unfolder.getCodeSizeReduction();
      if (ModuleCodeSize < CodeSizeLimit + CodeSizeReduction) {
        StatCodeSizeReduction = CodeSizeReduction;
        return Changed;
      }
    }

    LLVM_DEBUG({
      dbgs() << "*** Current module size is "
             << ModuleCodeSize - CodeSizeReduction << " ***\n";
    });
  }

  return Changed;
}

bool EVMConstantUnfolding::runOnModule(Module &M) {
  LLVM_DEBUG({ dbgs() << "********** " << PASS_NAME << " **********\n"; });

  return runImpl(M, getAnalysis<MachineModuleInfoWrapperPass>().getMMI());
}
