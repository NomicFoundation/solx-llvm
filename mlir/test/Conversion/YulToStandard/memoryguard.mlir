// RUN: mlir-opt --convert-yul-to-std %s | FileCheck --check-prefix=CONST %s
// RUN: mlir-opt --convert-yul-to-std=symbolic-memguard=true %s | FileCheck --check-prefix=SYMBOLIC %s

// The memoryguard is the free memory pointer's initial value. Lowering it to
// the intrinsic keeps it identifiable for the EVM backend, which folds it to
// `guard + spill region size`.

// CONST-LABEL:    func @free_ptr_init
// CONST:          %[[GUARD:.*]] = arith.constant 128 : i256
// CONST:          llvm.store %[[GUARD]], %{{.*}} : i256, !llvm.ptr<1>
// CONST-NOT:      evm.memoryguard

// SYMBOLIC-LABEL: func @free_ptr_init
// SYMBOLIC:       %[[GUARD:.*]] = arith.constant 128 : i256
// SYMBOLIC:       %[[MARK:.*]] = "llvm.intrcall"(%[[GUARD]]) <{id = {{[0-9]+}} : i32, name = "evm.memoryguard"}> : (i256) -> i256
// SYMBOLIC:       llvm.store %[[MARK]], %{{.*}} : i256, !llvm.ptr<1>
func.func @free_ptr_init() {
  %guard = yul.memoryguard 128
  %addr = arith.constant 64 : i256
  yul.mstore %addr, %guard
  return
}
