# Windows: clang-cl + MSVC ABI + Ninja
# cmake -G Ninja --toolchain cmake/toolchains/windows-clang-cl.cmake ...

set(CMAKE_SYSTEM_NAME Windows)

find_program(CMAKE_C_COMPILER NAMES clang-cl clang-cl.exe REQUIRED)
find_program(CMAKE_CXX_COMPILER NAMES clang-cl clang-cl.exe REQUIRED)

set(CMAKE_C_COMPILER "${CMAKE_C_COMPILER}" CACHE FILEPATH "" FORCE)
set(CMAKE_CXX_COMPILER "${CMAKE_CXX_COMPILER}" CACHE FILEPATH "" FORCE)

# MSVC 兼容前端
set(CMAKE_CXX_FLAGS_INIT "/EHsc")
set(CMAKE_C_FLAGS_INIT "")

# Win7 API 面
add_compile_definitions(_WIN32_WINNT=0x0601 WINVER=0x0601)
