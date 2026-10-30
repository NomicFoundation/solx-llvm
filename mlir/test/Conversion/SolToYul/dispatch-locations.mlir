// RUN: mlir-opt %s --split-input-file --convert-sol-to-yul \
// RUN:   -mlir-print-debuginfo -mlir-print-local-scope | FileCheck %s

// The code the contract lowering generates is at the contract's location,
// including the call value test hoisted above the switch when no route is
// payable. A dispatch case runs its interface function, and the creation
// code's argument decoding and call run the constructor, so they are at that
// function's location. The subprograms stay on the functions.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

#file = #llvm.di_file<"C.sol" in "/src">
#cu = #llvm.di_compile_unit<id = distinct[0]<>, sourceLanguage = DW_LANG_C,
 file = #file, isOptimized = false, emissionKind = Full>
#sp_ctor = #llvm.di_subprogram<id = distinct[1]<>, compileUnit = #cu,
 scope = #file, name = "constructor", file = #file, line = 2, scopeLine = 2,
 subprogramFlags = Definition>

// CHECK-LABEL: yul.object @C {
// CHECK:         yul.func @ctor
// CHECK:         } {{.*}} loc(fused<#llvm.di_subprogram<{{.*}}name = "constructor"{{.*}}>>["C.sol":2:3])
// CHECK:         yul.mstore {{.*}} loc("C.sol":1:1)
// CHECK:         yul.callvalue loc("C.sol":2:3)
// CHECK:         yul.datasize {obj = @C} loc("C.sol":2:3)
// CHECK:         yul.codecopy {{.*}} loc("C.sol":2:3)
// CHECK:         yul.func_call @ctor({{.*}}) : (i256) -> () loc("C.sol":2:3)
// CHECK:         yul.dataoffset {obj = @C_deployed} loc("C.sol":1:1)
// CHECK:         yul.datasize {obj = @C_deployed} loc("C.sol":1:1)
// CHECK:         yul.codecopy {{.*}} loc("C.sol":1:1)
// CHECK:         yul.return {{.*}} loc("C.sol":1:1)
// CHECK:       } loc("C.sol":1:1)

module {
  sol.contract @C {
    sol.func @ctor(%arg0: ui256 loc(#loc_ctor)) attributes {kind = #Constructor, orig_fn_type = (ui256) -> (), state_mutability = #NonPayable} {
      sol.return loc(#loc_ctor)
    } loc(#loc_ctor_sp)
  } {kind = #Contract} loc(#loc_contract)
}

#loc_contract = loc("C.sol":1:1)
#loc_ctor = loc("C.sol":2:3)
#loc_ctor_sp = loc(fused<#sp_ctor>[#loc_ctor])

// -----

#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

#file = #llvm.di_file<"C.sol" in "/src">
#cu = #llvm.di_compile_unit<id = distinct[0]<>, sourceLanguage = DW_LANG_C,
 file = #file, isOptimized = false, emissionKind = Full>
#sp_f = #llvm.di_subprogram<id = distinct[1]<>, compileUnit = #cu,
 scope = #file, name = "f", file = #file, line = 3, scopeLine = 3,
 subprogramFlags = Definition>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         yul.func @f
// CHECK:         } {{.*}} loc(fused<#llvm.di_subprogram<{{.*}}name = "f"{{.*}}>>["C.sol":3:3])
// CHECK:         yul.calldatasize loc("C.sol":1:1)
// CHECK:         yul.callvalue loc("C.sol":1:1)
// CHECK:         yul.arith_shr {{.*}} loc("C.sol":1:1)
// CHECK:         case 1 {
// CHECK-NOT:       yul.callvalue
// CHECK:           yul.func_call @f({{.*}}) : (i256) -> i256 loc("C.sol":3:3)
// CHECK:           yul.return {{.*}} loc("C.sol":3:3)
// CHECK:         yul.revert {{.*}} loc("C.sol":1:1)
// CHECK:       } loc("C.sol":1:1)

module {
  sol.contract @C {
    sol.func @f(%arg0: ui256 loc(#loc_f)) -> ui256 attributes {orig_fn_type = (ui256) -> ui256, selector = 1 : i32, state_mutability = #NonPayable} {
      sol.return %arg0 : ui256 loc(#loc_f)
    } loc(#loc_f_sp)
  } {kind = #Contract, runtime} loc(#loc_contract)
}

#loc_contract = loc("C.sol":1:1)
#loc_f = loc("C.sol":3:3)
#loc_f_sp = loc(fused<#sp_f>[#loc_f])
