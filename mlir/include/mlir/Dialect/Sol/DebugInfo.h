//===- DebugInfo.h - Debug locations for Sol functions ----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The subprograms of the functions a Sol module defines, and the locations of
// the code the lowering generates itself: the dispatcher, the ABI helpers,
// `__entry` and the code modifier inlining generates.
//
// With debug info the module location carries a compile unit and every
// location is a FileLineColLoc. Without it every location is unknown, and
// sourceLoc, artificialLoc and fuseArtificialSubprogram return their input
// unchanged.
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_DIALECT_SOL_DEBUGINFO_H_
#define MLIR_DIALECT_SOL_DEBUGINFO_H_

#include "mlir/Dialect/LLVMIR/LLVMAttrs.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Location.h"
#include "llvm/ADT/StringRef.h"

namespace mlir {
namespace evm {

/// Returns the file location `loc` reports, without what is fused onto it, or
/// `loc` if it reports no file.
///
/// This is how to put an operation at a contract's or a function's position:
/// their locations carry a compile unit or a subprogram, which belongs on them
/// and nowhere else.
Location sourceLoc(Location loc);

/// Returns the file `loc` reports at line 0, or `loc` if it reports no file.
///
/// This is also how to take the position of a function for an operation: the
/// result is a plain file location, never a fused subprogram.
Location artificialLoc(Location loc);

/// Returns `declLoc`'s file location with a fresh DISubprogramAttr fused onto
/// it: named `name`, in `compileUnit` and the file `declLoc` reports, with
/// `flags`. The name is the linkage name too.
///
/// A function operation needs a subprogram on its own location for anything
/// inside it to get a `!dbg`. The id is distinct per call: two definitions
/// sharing one in a module is a verifier error.
///
/// Put the result on a function operation and nowhere else. An operation
/// created at it is attributed to this subprogram, which the verifier rejects
/// inside any other function.
Location fuseSubprogram(LLVM::DICompileUnitAttr compileUnit, StringRef name,
                        Location declLoc, LLVM::DIFlags flags);

/// Returns fuseSubprogram of an artificial subprogram in the compile unit
/// fused onto `mod`'s location, or `declLoc` if `mod` carries none.
Location fuseArtificialSubprogram(ModuleOp mod, StringRef name,
                                  Location declLoc);

/// Returns `loc` with the subprogram fused onto it under a fresh id, or `loc`
/// if it carries none.
///
/// A function operation cloned with its location shares the original's
/// subprogram, which the verifier rejects once both definitions are emitted.
Location freshSubprogram(Location loc);

} // namespace evm
} // namespace mlir

#endif // MLIR_DIALECT_SOL_DEBUGINFO_H_
