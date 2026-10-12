// RUN: mlir-opt --convert-sol-to-yul %s | FileCheck %s

// The creation code copies the constructor's arguments, the blob appended to
// the code, into memory only when the constructor takes parameters. A
// contract without a constructor, or with a parameterless one, emits neither
// the `codesize` arithmetic nor the allocation and copy, and the codecopy of
// the runtime object reads the free pointer as initialized.

#Constructor = #sol<FunctionKind Constructor>
#Contract = #sol<ContractKind Contract>
#Default = #sol<RevertStrings Default>
#NonPayable = #sol<StateMutability NonPayable>
#Osaka = #sol<EvmVersion Osaka>
module attributes {llvm.data_layout = "E-p:256:256-i256:256:256-S256-a:256:256", llvm.target_triple = "evm-unknown-unknown", sol.evm_version = #Osaka, sol.revert_strings = #Default} {
  sol.contract @NoCtor {
  } {kind = #Contract}
  sol.contract @EmptyCtor {
    sol.func @ctor() attributes {id = 1 : i64, kind = #Constructor, orig_fn_type = () -> (), state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract}
  sol.contract @ArgCtor {
    sol.func @ctor(%arg0: ui256) attributes {id = 1 : i64, kind = #Constructor, orig_fn_type = (ui256) -> (), state_mutability = #NonPayable} {
      sol.return
    }
  } {kind = #Contract}
}

// CHECK-LABEL: yul.object @NoCtor {
// CHECK:         yul.mstore %c64_i256, %{{.*}}
// CHECK-NOT:     yul.codesize
// CHECK-NOT:     yul.datasize {obj = @NoCtor}
// CHECK:         %[[FREE:.*]] = yul.mload %c64_i256
// CHECK-NEXT:    yul.dataoffset {obj = @NoCtor_deployed}
// CHECK-NEXT:    %[[SIZE:.*]] = yul.datasize {obj = @NoCtor_deployed}
// CHECK-NEXT:    yul.codecopy %[[FREE]], %{{.*}}, %[[SIZE]]
// CHECK-NEXT:    yul.return %[[FREE]], %[[SIZE]]

// CHECK-LABEL: yul.object @EmptyCtor {
// CHECK:         yul.mstore %c64_i256, %{{.*}}
// CHECK-NOT:     yul.codesize
// CHECK-NOT:     yul.datasize {obj = @EmptyCtor}
// CHECK-NOT:     yul.codecopy
// CHECK:         yul.func_call @ctor() : () -> ()
// CHECK:         %[[FREE:.*]] = yul.mload %c64_i256
// CHECK-NEXT:    yul.dataoffset {obj = @EmptyCtor_deployed}
// CHECK-NEXT:    %[[SIZE:.*]] = yul.datasize {obj = @EmptyCtor_deployed}
// CHECK-NEXT:    yul.codecopy %[[FREE]], %{{.*}}, %[[SIZE]]
// CHECK-NEXT:    yul.return %[[FREE]], %[[SIZE]]

// CHECK-LABEL: yul.object @ArgCtor {
// CHECK:         %[[PROG:.*]] = yul.datasize {obj = @ArgCtor}
// CHECK-NEXT:    %[[CODE:.*]] = yul.codesize
// CHECK-NEXT:    %[[ARGS:.*]] = yul.sub %[[CODE]], %[[PROG]]
// CHECK:         %[[START:.*]] = yul.mload %c64_i256
// CHECK:         yul.codecopy %[[START]], %[[PROG]], %[[ARGS]]
// CHECK:         yul.func_call @__sol.abi_decode_tuple.memory.ui256(%[[START]], %{{.*}})
// CHECK-NEXT:    yul.func_call @ctor(%{{.*}}) : (i256) -> ()
