add_mlir_translation_library(MLIRYulToLLVMIRTranslation
  YulToLLVMIRTranslation.cpp

  LINK_COMPONENTS
  Core

  LINK_LIBS PUBLIC
  MLIRIR
  MLIRLLVMDialect
  MLIRSupport
  MLIRTargetLLVMIRExport
  MLIRYulDialect
  )
