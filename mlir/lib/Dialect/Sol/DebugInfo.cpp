//===- DebugInfo.cpp - Debug locations for Sol functions ------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Sol/DebugInfo.h"
#include "mlir/IR/BuiltinAttributes.h"

using namespace mlir;

Location mlir::evm::sourceLoc(Location loc) {
  if (auto fileLoc = loc->findInstanceOf<FileLineColLoc>())
    return fileLoc;
  return loc;
}

Location mlir::evm::artificialLoc(Location loc) {
  auto fileLoc = loc->findInstanceOf<FileLineColLoc>();
  if (!fileLoc)
    return loc;
  return FileLineColLoc::get(fileLoc.getFilename(), /*line=*/0, /*column=*/0);
}

Location mlir::evm::fuseSubprogram(LLVM::DICompileUnitAttr compileUnit,
                                   StringRef name, Location declLoc,
                                   LLVM::DIFlags flags) {
  // A function operation's location holds its own subprogram and nothing
  // else, so the subprogram is fused onto the plain file location.
  auto fileLoc = declLoc->findInstanceOf<FileLineColLoc>();
  assert(fileLoc && "a module with a compile unit has file locations");

  MLIRContext *context = compileUnit.getContext();
  // The function's own source: one lowered from an imported file names that
  // file. The directory is the compile unit's.
  auto file = LLVM::DIFileAttr::get(context, fileLoc.getFilename(),
                                    compileUnit.getFile().getDirectory());
  StringAttr nameAttr = StringAttr::get(context, name);
  auto subprogram = LLVM::DISubprogramAttr::get(
      context, DistinctAttr::create(UnitAttr::get(context)), compileUnit, file,
      nameAttr, /*linkageName=*/nameAttr, file, fileLoc.getLine(),
      /*scopeLine=*/fileLoc.getLine(),
      LLVM::DISubprogramFlags::LocalToUnit |
          LLVM::DISubprogramFlags::Definition,
      LLVM::DISubroutineTypeAttr::get(context, /*types=*/{}),
      /*retainedNodes=*/{}, /*annotations=*/{}, flags);
  return FusedLoc::get(context, {fileLoc}, subprogram);
}

Location mlir::evm::fuseArtificialSubprogram(ModuleOp mod, StringRef name,
                                             Location declLoc) {
  auto fusedCompileUnit =
      mod->getLoc()->findInstanceOf<FusedLocWith<LLVM::DICompileUnitAttr>>();
  if (!fusedCompileUnit)
    return declLoc;
  return fuseSubprogram(fusedCompileUnit.getMetadata(), name, declLoc,
                        LLVM::DIFlags::Artificial);
}

Location mlir::evm::freshSubprogram(Location loc) {
  auto fused = dyn_cast<FusedLocWith<LLVM::DISubprogramAttr>>(loc);
  if (!fused)
    return loc;

  LLVM::DISubprogramAttr subprogram = fused.getMetadata();
  MLIRContext *context = loc.getContext();
  auto fresh = LLVM::DISubprogramAttr::get(
      context, DistinctAttr::create(UnitAttr::get(context)),
      subprogram.getCompileUnit(), subprogram.getScope(), subprogram.getName(),
      subprogram.getLinkageName(), subprogram.getFile(), subprogram.getLine(),
      subprogram.getScopeLine(), subprogram.getSubprogramFlags(),
      subprogram.getType(), subprogram.getRetainedNodes(),
      subprogram.getAnnotations(), subprogram.getFlags());
  return FusedLoc::get(context, fused.getLocations(), fresh);
}
