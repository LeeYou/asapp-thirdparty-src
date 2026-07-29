# Linux: clang + Ninja
# Abseil/gRPC(C++17) 需要完整 <filesystem>。Ubuntu 18.04 默认 GCC 7 的 libstdc++ 没有该头文件；
# 若机器上装有 GCC ≥ 8，则让 Clang 挂到对应 libstdc++（可用 ASAPP_DEP_GCC_TOOLCHAIN 覆盖前缀）。

find_program(CMAKE_C_COMPILER NAMES clang REQUIRED)
find_program(CMAKE_CXX_COMPILER NAMES clang++ REQUIRED)
set(CMAKE_C_COMPILER "${CMAKE_C_COMPILER}" CACHE FILEPATH "" FORCE)
set(CMAKE_CXX_COMPILER "${CMAKE_CXX_COMPILER}" CACHE FILEPATH "" FORCE)

set(_asapp_gcc_toolchain_prefix "")
if(DEFINED ENV{ASAPP_DEP_GCC_TOOLCHAIN} AND NOT "$ENV{ASAPP_DEP_GCC_TOOLCHAIN}" STREQUAL "")
    set(_asapp_gcc_toolchain_prefix "$ENV{ASAPP_DEP_GCC_TOOLCHAIN}")
endif()

set(_asapp_gcc_ver "")
set(_asapp_gcc_triple "")
set(_asapp_gcc_candidates
    x86_64-linux-gnu
    aarch64-linux-gnu
    loongarch64-linux-gnu
)
foreach(_triple IN LISTS _asapp_gcc_candidates)
    foreach(_ver 13;12;11;10;9;8)
        set(_gcc_dir "/usr/lib/gcc/${_triple}/${_ver}")
        if(EXISTS "${_gcc_dir}")
            set(_asapp_gcc_ver "${_ver}")
            set(_asapp_gcc_triple "${_triple}")
            if(_asapp_gcc_toolchain_prefix STREQUAL "")
                set(_asapp_gcc_toolchain_prefix "/usr")
            endif()
            break()
        endif()
    endforeach()
    if(NOT _asapp_gcc_ver STREQUAL "")
        break()
    endif()
endforeach()

if(NOT _asapp_gcc_toolchain_prefix STREQUAL "")
    string(APPEND CMAKE_C_FLAGS_INIT " --gcc-toolchain=${_asapp_gcc_toolchain_prefix}")
    string(APPEND CMAKE_CXX_FLAGS_INIT " --gcc-toolchain=${_asapp_gcc_toolchain_prefix}")
    if(NOT _asapp_gcc_ver STREQUAL "" AND NOT _asapp_gcc_triple STREQUAL "")
        # 在同前缀下存在多个 GCC 时，强制选中 ≥8 的那套 libstdc++
        string(APPEND CMAKE_C_FLAGS_INIT " -B/usr/lib/gcc/${_asapp_gcc_triple}/${_asapp_gcc_ver}")
        string(APPEND CMAKE_CXX_FLAGS_INIT " -B/usr/lib/gcc/${_asapp_gcc_triple}/${_asapp_gcc_ver}")
        message(STATUS
            "linux-clang: libstdc++ from GCC ${_asapp_gcc_ver} (${_asapp_gcc_triple})")
        # GCC 8 的 filesystem 仍在 libstdc++fs；9+ 已并入 libstdc++
        if(_asapp_gcc_ver STREQUAL "8")
            # STANDARD_LIBRARIES 挂在链接行末尾，避免 -l 在 .o 之前导致 undefined reference
            string(APPEND CMAKE_CXX_STANDARD_LIBRARIES " -lstdc++fs")
            string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT " -lstdc++fs")
            string(APPEND CMAKE_SHARED_LINKER_FLAGS_INIT " -lstdc++fs")
            string(APPEND CMAKE_MODULE_LINKER_FLAGS_INIT " -lstdc++fs")
        endif()
    else()
        message(STATUS "linux-clang: --gcc-toolchain=${_asapp_gcc_toolchain_prefix}")
    endif()
else()
    message(WARNING
        "linux-clang: no GCC >= 8 found under /usr/lib/gcc/*/8..13. "
        "On Ubuntu 18.04 install g++-8 (or newer) before building gRPC/Abseil, "
        "or set ASAPP_DEP_GCC_TOOLCHAIN to a sysroot that provides <filesystem>.")
endif()
