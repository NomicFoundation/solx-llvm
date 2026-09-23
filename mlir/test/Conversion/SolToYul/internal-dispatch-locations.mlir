// RUN: mlir-opt %s --convert-sol-to-yul -mlir-print-debuginfo \
// RUN:   -mlir-print-local-scope | FileCheck %s

// The dispatch function of an internal function pointer call is shared by
// every call of the same candidates: its subprogram is artificial at the line
// of the module hosting it, and its body is at line 0. The call into it keeps
// the call's location.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

#file = #llvm.di_file<"C.sol" in "/src">
#cu = #llvm.di_compile_unit<id = distinct[0]<>, sourceLanguage = DW_LANG_C,
 file = #file, isOptimized = false, emissionKind = Full>

// CHECK-LABEL: yul.object @C_deployed {
// CHECK:         yul.func_call @[[DISPATCH:__sol\.dispatch_internal_call[^(]*]](%{{.*}}) : (i256) -> () loc("C.sol":5:5)
// CHECK:         yul.func @[[DISPATCH]] : (i256) -> () {
// CHECK-NEXT:    ^bb0(%arg0: i256 loc("C.sol":0:0)):
// CHECK-NEXT:      yul.switch %arg0 : i256
// CHECK:             yul.func_call @g() : () -> () loc("C.sol":0:0)
// CHECK:             yul.revert %{{.*}}, %{{.*}} loc("C.sol":0:0)
// CHECK:           yul.func_return loc("C.sol":0:0)
// CHECK-NEXT:    } loc(fused<#llvm.di_subprogram<{{.*}}name = "[[DISPATCH]]"{{.*}}line = 1, scopeLine = 1, {{.*}}flags = Artificial>>["C.sol":1:1])

module {
  sol.contract @C {
    sol.func @ctor() attributes {kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return loc(#loc_contract)
    } loc(#loc_contract)
    sol.func private @g() attributes {id = 7 : i64, state_mutability = #NonPayable} {
      sol.return loc(#loc_g)
    } loc(#loc_g)
    sol.func @f() attributes {orig_fn_type = () -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.func_constant @g : !sol.func_ref<() -> ()> loc(#loc_pointer)
      sol.icall %0() : !sol.func_ref<() -> ()>, () -> () loc(#loc_call)
      sol.return loc(#loc_f)
    } loc(#loc_f)
  } {kind = #Contract} loc(#loc_contract_cu)
} loc(#loc_contract_cu)

#loc_contract = loc("C.sol":1:1)
#loc_contract_cu = loc(fused<#cu>[#loc_contract])
#loc_g = loc("C.sol":2:3)
#loc_f = loc("C.sol":3:3)
#loc_pointer = loc("C.sol":4:5)
#loc_call = loc("C.sol":5:5)
