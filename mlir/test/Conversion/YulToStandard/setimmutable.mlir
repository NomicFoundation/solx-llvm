// RUN: mlir-opt --convert-yul-to-std %s | FileCheck %s
// RUN: mlir-opt --convert-yul-to-std --convert-func-to-llvm %s \
// RUN:   | mlir-translate --mlir-to-llvmir | FileCheck --check-prefix=LLVM %s

// CHECK-LABEL: func @deploy
// CHECK-SAME:  (%[[ADDR:.*]]: i256, %[[VAL:.*]]: i256)
// CHECK:       "llvm.intrcall"(%[[ADDR]], %[[VAL]]) <{id = {{[0-9]+}} : i32, metadata = ["40"], name = "evm.setimmutable"}> : (i256, i256) -> ()
// LLVM-LABEL: define void @deploy
// LLVM:       call void @llvm.evm.setimmutable(i256 %{{.*}}, i256 %{{.*}}, metadata ![[ID:[0-9]+]])
// LLVM:       ![[ID]] = !{!"40"}
func.func @deploy(%addr: i256, %val: i256) {
  yul.setimmutable %addr, "40", %val
  return
}
