// RUN: mlir-opt %s --pass-pipeline='builtin.module(sol.contract(sol.func(mem2reg)))' | FileCheck %s

sol.contract @C {
  // Inline assembly writes one field of the slot through a view.
  // CHECK-LABEL: sol.func @fieldView(
  // CHECK-NEXT:    %[[SLOT:.*]] = sol.alloca : !sol.ptr<!sol.string<CallData>, Stack>
  // CHECK-NEXT:    sol.store %{{.*}}, %[[SLOT]]
  // CHECK-NEXT:    sol.inline_asm {
  // CHECK:           sol.yul_calldata_length %[[SLOT]]
  // CHECK:         %[[V:.*]] = sol.load %[[SLOT]]
  // CHECK-NEXT:    sol.return %[[V]]
  sol.func @fieldView(%s: !sol.string<CallData>) -> !sol.string<CallData> {
    %0 = sol.alloca : !sol.ptr<!sol.string<CallData>, Stack>
    sol.store %s, %0 : !sol.string<CallData>, !sol.ptr<!sol.string<CallData>, Stack>
    sol.inline_asm {
      %c1 = yul.constant 1
      %1 = sol.yul_calldata_length %0 : !sol.ptr<!sol.string<CallData>, Stack> -> !yul.ptr
      yul.store %c1, %1 : i256, !yul.ptr
    }
    %2 = sol.load %0 : !sol.ptr<!sol.string<CallData>, Stack>, !sol.string<CallData>
    sol.return %2 : !sol.string<CallData>
  }
} {kind = #sol<ContractKind Contract>, runtime}
