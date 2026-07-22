# gtest — googletest 1.15.2 静态库（GTest::gtest / gmock）

set(_GTEST_SRC "${ASAPP_DEP_SOURCE_ROOT}/gtest/src")
if(NOT EXISTS "${_GTEST_SRC}/CMakeLists.txt")
    message(FATAL_ERROR "gtest source missing: ${_GTEST_SRC}/CMakeLists.txt")
endif()

set(BUILD_GMOCK ON CACHE BOOL "" FORCE)
set(INSTALL_GTEST ON CACHE BOOL "" FORCE)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
set(gtest_disable_pthreads OFF CACHE BOOL "" FORCE)
# clang-cl / MSVC ABI: 要求 C++17（googletest 1.15）
set(CMAKE_CXX_STANDARD 17 CACHE STRING "" FORCE)
set(CMAKE_CXX_STANDARD_REQUIRED ON CACHE BOOL "" FORCE)

# 不可 EXCLUDE_FROM_ALL，否则默认 ninja 不编译目标
add_subdirectory("${_GTEST_SRC}" "${CMAKE_BINARY_DIR}/_deps/googletest")

# googletest 自带 install；补充 PACKAGE_META
set(_META_DIR "${CMAKE_CURRENT_BINARY_DIR}/_meta/gtest")
file(MAKE_DIRECTORY "${_META_DIR}")
file(WRITE "${_META_DIR}/PACKAGE_META.yaml" [[
name: gtest
version: "1.15.2"
kind: compiled
license: BSD-3-Clause
windows_min_os: win7
toolchain:
  generator: ninja
  preferred: clang-ninja
  windows_driver: clang-cl
  abi: msvc
]])
install(FILES "${_META_DIR}/PACKAGE_META.yaml" DESTINATION .)