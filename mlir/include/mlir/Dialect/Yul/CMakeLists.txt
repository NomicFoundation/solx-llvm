# Create MLIRYulOpsIncGen.
add_mlir_dialect(YulOps yul)

# Generate sources from YulOps.td.
set(LLVM_TARGET_DEFINITIONS YulOps.td)
mlir_tablegen(YulOpsEnums.h.inc -gen-enum-decls)
mlir_tablegen(YulOpsEnums.cpp.inc -gen-enum-defs)
add_public_tablegen_target(MLIRYulExtraIncGen)

# Generate sources from YulInterfaces.td.
set(LLVM_TARGET_DEFINITIONS YulInterfaces.td)
mlir_tablegen(YulInterfaces.h.inc -gen-op-interface-decls)
mlir_tablegen(YulInterfaces.cpp.inc -gen-op-interface-defs)
add_public_tablegen_target(MLIRYulInterfacesIncGen)

# Generate documentation.
add_mlir_doc(YulDialect YulDialect Yul/ -gen-dialect-doc)
add_mlir_doc(YulOps YulOps Yul/ -gen-op-doc)
