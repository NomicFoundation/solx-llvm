//===- EVMAddrSpace.h - EVM address spaces ----------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The address spaces of the EVM target, which the Yul dialect's memory ops
// address.
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_DIALECT_YUL_EVMADDRSPACE_H
#define MLIR_DIALECT_YUL_EVMADDRSPACE_H

namespace mlir::evm {

enum AddrSpace : unsigned {
  AddrSpace_Stack = 0,
  AddrSpace_Heap = 1,
  AddrSpace_CallData = 2,
  AddrSpace_ReturnData = 3,
  AddrSpace_Code = 4,
  AddrSpace_Storage = 5,
  AddrSpace_TransientStorage = 6,
};

/// Returns the alignment of `addrSpace`.
inline unsigned getAlignment(AddrSpace addrSpace) {
  // Stack objects are compiler-generated i256 cells, 32-byte aligned per the
  // data layout (i256:256:256, S256). All other address spaces are byte
  // addressed with no alignment guarantees.
  return addrSpace == AddrSpace_Stack ? 32 : 1;
}

} // namespace mlir::evm

#endif // MLIR_DIALECT_YUL_EVMADDRSPACE_H
