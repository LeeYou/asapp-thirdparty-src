# Windows: clang-cl + MSVC ABI + Ninja
# 通过环境变量 ASAPP_DEP_CLANG_TARGET / ASAPP_DEP_ARCH 选择 32/64 位。
# 推荐由 scripts/build.ps1 在 VsDevCmd -arch=x86|amd64 环境中调用。

set(CMAKE_SYSTEM_NAME Windows)

find_program(CMAKE_C_COMPILER NAMES clang-cl clang-cl.exe REQUIRED)
find_program(CMAKE_CXX_COMPILER NAMES clang-cl clang-cl.exe REQUIRED)

set(CMAKE_C_COMPILER "${CMAKE_C_COMPILER}" CACHE FILEPATH "" FORCE)
set(CMAKE_CXX_COMPILER "${CMAKE_CXX_COMPILER}" CACHE FILEPATH "" FORCE)

# 目标 triple：i686-pc-windows-msvc | x86_64-pc-windows-msvc
if(DEFINED ENV{ASAPP_DEP_CLANG_TARGET} AND NOT "$ENV{ASAPP_DEP_CLANG_TARGET}" STREQUAL "")
    set(_ASAPP_CLANG_TARGET "$ENV{ASAPP_DEP_CLANG_TARGET}")
elseif(DEFINED ENV{ASAPP_DEP_ARCH} AND "$ENV{ASAPP_DEP_ARCH}" STREQUAL "x86")
    set(_ASAPP_CLANG_TARGET "i686-pc-windows-msvc")
else()
    set(_ASAPP_CLANG_TARGET "x86_64-pc-windows-msvc")
endif()

set(CMAKE_C_COMPILER_TARGET "${_ASAPP_CLANG_TARGET}" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER_TARGET "${_ASAPP_CLANG_TARGET}" CACHE STRING "" FORCE)

# MSVC 兼容前端
set(CMAKE_CXX_FLAGS_INIT "/EHsc")
set(CMAKE_C_FLAGS_INIT "")

# Win7 API 面
add_compile_definitions(_WIN32_WINNT=0x0601 WINVER=0x0601)

message(STATUS "windows-clang-cl toolchain: target=${_ASAPP_CLANG_TARGET}")
