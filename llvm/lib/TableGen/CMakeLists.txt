add_llvm_component_library(LLVMTableGen
  DetailedRecordsBackend.cpp
  Error.cpp
  JSONBackend.cpp
  Main.cpp
  Parser.cpp
  Record.cpp
  SetTheory.cpp
  StringMatcher.cpp
  StringToOffsetTable.cpp
  TableGenBackend.cpp
  TableGenBackendSkeleton.cpp
  TGLexer.cpp
  TGParser.cpp
  TGTimer.cpp

  ADDITIONAL_HEADER_DIRS
  ${LLVM_MAIN_INCLUDE_DIR}/llvm/TableGen

  LINK_COMPONENTS
  Support
  )

# EVM local begin
# tblgen-rs (melior's TableGen binding) links the Record, RecordVal, and Init
# dump() methods, which NDEBUG compiles out; a no-assertions Release build
# then fails to link the melior_macro DLL on Windows, where PE linking
# resolves every symbol eagerly.
target_compile_definitions(LLVMTableGen PRIVATE LLVM_ENABLE_DUMP)
# EVM local end
