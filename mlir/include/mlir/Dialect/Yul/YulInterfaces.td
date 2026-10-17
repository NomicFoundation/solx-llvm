//===- YulInterfaces.td - Yul dialect interfaces ----------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_DIALECT_YUL_YULINTERFACES_TD
#define MLIR_DIALECT_YUL_YULINTERFACES_TD

include "mlir/IR/OpBase.td"
include "mlir/Interfaces/ControlFlowInterfaces.td"
include "mlir/Interfaces/LoopLikeInterface.td"

// (Copied and modified from clangir).
//
// Loops in Yul are C-style loops.
def Yul_LoopOpInterface : OpInterface<"LoopOpInterface", [
  DeclareOpInterfaceMethods<RegionBranchOpInterface,
                            ["getEntrySuccessorOperands"]>,
  DeclareOpInterfaceMethods<LoopLikeOpInterface,
                            ["getInitsMutable", "getRegionIterArgs",
                             "getYieldedValuesMutable", "getLoopResults"]>
]> {
  let cppNamespace = "::mlir::yul";

  // Do we need the getRegionsInExecutionOrder interface function from the
  // clangir version?
  let methods = [
    InterfaceMethod<[{
        Returns the loop's conditional region.
      }],
      /*retTy=*/"mlir::Region &",
      /*methodName=*/"getCond"
    >,
    InterfaceMethod<[{
        Returns the loop's body region.
      }],
      /*retTy=*/"mlir::Region &",
      /*methodName=*/"getBody"
    >,
    InterfaceMethod<[{
        Returns a pointer to the loop's step region or nullptr.
      }],
      /*retTy=*/"mlir::Region *",
      /*methodName=*/"maybeGetStep",
      /*args=*/(ins),
      /*methodBody=*/"",
      /*defaultImplementation=*/"return nullptr;"
    >,
    InterfaceMethod<[{
        Returns the first region to be executed in the loop.
      }],
      /*retTy=*/"mlir::Region &",
      /*methodName=*/"getEntry",
      /*args=*/(ins),
      /*methodBody=*/"",
      /*defaultImplementation=*/"return $_op.getCond();"
    >
  ];

  let extraClassDeclaration = [{
    /// Generic method to retrieve the successors of a LoopOpInterface operation.
    static void getLoopOpSuccessorRegions(
        yul::LoopOpInterface op, RegionBranchPoint point,
        SmallVectorImpl<RegionSuccessor> &regions);
  }];
}

#endif // MLIR_DIALECT_YUL_YULINTERFACES_TD
