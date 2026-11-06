add_mlir_dialect_library(MLIRYulDialect
  MemorySlot.cpp
  YulBase.cpp
  YulOps.cpp

  ADDITIONAL_HEADER_DIRS
  ${MLIR_MAIN_INCLUDE_DIR}/mlir/Dialect/Yul

  DEPENDS
  MLIRYulOpsIncGen
  MLIRYulExtraIncGen
  MLIRYulInterfacesIncGen

  LINK_LIBS PUBLIC
  MLIRLLVMDialect
  MLIRMemorySlotInterfaces
  MLIRMemorySlotUtils
  )
