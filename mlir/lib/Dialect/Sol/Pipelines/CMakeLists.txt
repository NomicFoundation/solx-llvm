add_mlir_dialect_library(MLIRSolPipelines
  SolPipelines.cpp

  ADDITIONAL_HEADER_DIRS
  ${MLIR_MAIN_INCLUDE_DIR}/mlir/Dialect/Sol

  LINK_LIBS PUBLIC
  MLIRPass
  MLIRSolDialect
  MLIRSolToYul
  MLIRSolTransforms
  MLIRTransforms
  MLIRYulDialect
)
