include_directories(
  ${LLVM_MAIN_SRC_DIR}/lib/Target/EVM
  ${LLVM_BINARY_DIR}/lib/Target/EVM
  )

set(LLVM_LINK_COMPONENTS
  EVM
  EVMDesc
  EVMInfo
  EVMLinker
  CodeGen
  Core
  IRReader
  MC
  MIRParser
  Object
  SelectionDAG
  Support
  Target
  TargetParser
)

# EVMLinkerTest locates its input files through
# llvm::unittest::getInputFileDirectory().
set(LLVM_UNITTEST_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
configure_file(
  ${LLVM_MAIN_SRC_DIR}/unittests/unittest.cfg.in
  ${CMAKE_CURRENT_BINARY_DIR}/llvm.srcdir.txt)

add_llvm_target_unittest(EVMTests
  BytecodeSize.cpp
  EmitToMemoryBufferWithDbg.cpp
  EVMLinkerTest.cpp
  SpillRegion.cpp
  StackShuffler.cpp
  StackModel.cpp
  )

target_link_libraries(EVMTests PRIVATE LLVMTestingSupport)

set_property(TARGET EVMTests PROPERTY FOLDER "Tests/UnitTests/TargetTests")
