// RUN: mlir-opt %s --convert-sol-to-yul -mlir-print-debuginfo \
// RUN:   -mlir-print-local-scope | FileCheck %s

// An out-of-line helper is generated and shared by every caller, so its
// subprogram is artificial at the line of its host and its body and arguments
// are at line 0. The call into it keeps the caller's location. This holds for
// a helper hosted by the contract (the array copy below, called from a
// function) and for one hosted by the creation object (the decoder of the
// constructor's parameter tuple, requested from the object's entry block).

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#NonPayable = #sol<StateMutability NonPayable>

#file = #llvm.di_file<"C.sol" in "/src">
#cu = #llvm.di_compile_unit<id = distinct[0]<>, sourceLanguage = DW_LANG_C,
 file = #file, isOptimized = false, emissionKind = Full>
#sp_ctor = #llvm.di_subprogram<id = distinct[1]<>, compileUnit = #cu,
 scope = #file, name = "constructor", file = #file, line = 2, scopeLine = 2,
 subprogramFlags = Definition>
#sp_f = #llvm.di_subprogram<id = distinct[2]<>, compileUnit = #cu,
 scope = #file, name = "f", file = #file, line = 3, scopeLine = 3,
 subprogramFlags = Definition>

// CHECK-LABEL: yul.object @C {
// CHECK:         yul.func_call @[[DECODE:__sol\.abi_decode_tuple\.memory[^(]*]]({{.*}}) : (i256, i256) -> i256 loc("C.sol":2:3)
// CHECK:         yul.object @C_deployed {
// CHECK:           yul.func @[[COPY:__sol\.copy_array[^ ]*]] : (i256, i256) -> () {
// CHECK-NEXT:      ^bb0(%arg0: i256 loc("C.sol":0:0), %arg1: i256 loc("C.sol":0:0)):
// CHECK:             yul.sstore {{.*}} loc("C.sol":0:0)
// CHECK:             yul.func_return loc("C.sol":0:0)
// CHECK-NEXT:      } {{.*}} loc(fused<#llvm.di_subprogram<{{.*}}name = "[[COPY]]"{{.*}}line = 1, scopeLine = 1, {{.*}}flags = Artificial>>["C.sol":1:1])
// CHECK:           yul.func @f
// CHECK:             yul.func_call @[[COPY]]({{.*}}) : (i256, i256) -> () loc("C.sol":4:5)
// CHECK:         } loc(fused<#llvm.di_compile_unit<{{.*}}>>["C.sol":1:1])
// CHECK:         yul.func @[[DECODE]] : (i256, i256) -> i256 {
// CHECK-NEXT:    ^bb0(%arg0: i256 loc("C.sol":0:0), %arg1: i256 loc("C.sol":0:0)):
// CHECK:           yul.func_call @[[NESTED:__sol\.abi_decode\.[^(]*]]({{.*}}) : (i256, i256) -> i256 loc("C.sol":0:0)
// CHECK:           yul.func_return {{.*}} loc("C.sol":0:0)
// CHECK-NEXT:    } {{.*}} loc(fused<#llvm.di_subprogram<{{.*}}name = "[[DECODE]]"{{.*}}line = 1, scopeLine = 1, {{.*}}flags = Artificial>>["C.sol":1:1])
// CHECK:         yul.func @[[NESTED]] : (i256, i256) -> i256 {
// CHECK-NEXT:    ^bb0(%arg0: i256 loc("C.sol":0:0), %arg1: i256 loc("C.sol":0:0)):
// CHECK:           yul.mstore {{.*}} loc("C.sol":0:0)
// CHECK:           yul.func_return {{.*}} loc("C.sol":0:0)
// CHECK-NEXT:    } {{.*}} loc(fused<#llvm.di_subprogram<{{.*}}name = "[[NESTED]]"{{.*}}line = 1, scopeLine = 1, {{.*}}flags = Artificial>>["C.sol":1:1])
// CHECK:       } loc(fused<#llvm.di_compile_unit<{{.*}}>>["C.sol":1:1])

module {
  sol.contract @C {
    sol.state_var @s slot 0 offset 0 : !sol.array<? x ui256, Storage>
    sol.func @ctor(%arg0: !sol.array<? x ui8, Memory> loc(#loc_ctor)) attributes {kind = #Constructor, orig_fn_type = (!sol.array<? x ui8, Memory>) -> (), state_mutability = #NonPayable} {
      sol.return loc(#loc_ctor)
    } loc(#loc_ctor_sp)
    sol.func @f(%arg0: !sol.array<? x ui256, Memory> loc(#loc_f)) attributes {orig_fn_type = (!sol.array<? x ui256, Memory>) -> (), selector = 1 : i32, state_mutability = #NonPayable} {
      %0 = sol.addr_of @s : !sol.array<? x ui256, Storage> loc(#loc_copy)
      sol.copy %arg0, %0 : !sol.array<? x ui256, Memory>, !sol.array<? x ui256, Storage> loc(#loc_copy)
      sol.return loc(#loc_f)
    } loc(#loc_f_sp)
  } {kind = #Contract} loc(#loc_contract_cu)
} loc(#loc_contract_cu)

#loc_contract = loc("C.sol":1:1)
#loc_contract_cu = loc(fused<#cu>[#loc_contract])
#loc_ctor = loc("C.sol":2:3)
#loc_ctor_sp = loc(fused<#sp_ctor>[#loc_ctor])
#loc_f = loc("C.sol":3:3)
#loc_f_sp = loc(fused<#sp_f>[#loc_f])
#loc_copy = loc("C.sol":4:5)
