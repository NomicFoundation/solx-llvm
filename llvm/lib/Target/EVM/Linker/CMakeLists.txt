add_llvm_component_library(LLVMEVMLinker
  EVMLinker.cpp
  EVMLinkerQueries.cpp

  LINK_COMPONENTS
  EVMDesc
  MC
  Object
  Support

  ADD_TO_COMPONENT
  EVM
  )
