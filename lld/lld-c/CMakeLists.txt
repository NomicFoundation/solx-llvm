add_lld_library(lldC
  EVMLinker.cpp
  LLDAsLibraryC.cpp

  ${LLD_INCLUDE_DIR}/lld/Common

  LINK_COMPONENTS
  Core
  EVMDesc
  Object
  Support

  DEPENDS
  intrinsics_gen
  )
