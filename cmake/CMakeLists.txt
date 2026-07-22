# asapp-thirdparty-src root superbuild
# Usage:
#   cmake -G Ninja -S . -B build/<slice> \
#     --toolchain cmake/toolchains/<os>.cmake \
#     -DASAPP_DEP_OS=windows -DASAPP_DEP_ARCH=x64 \
#     -DASAPP_DEP_LINKAGE=static -DASAPP_DEP_CONFIG=release \
#     -DASAPP_DEP_PACKAGES=nlohmann_json;stb;sqlite \
#     -DCMAKE_INSTALL_PREFIX=<prebuilt-slice-root>
#   cmake --build build/<slice>
#   cmake --install build/<slice>

cmake_minimum_required(VERSION 3.24)
project(asapp_thirdparty_src LANGUAGES C CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(AsAppDepOptions)

message(STATUS "AsApp deps slice: ${ASAPP_DEP_OS}-${ASAPP_DEP_ARCH}-${ASAPP_DEP_LINKAGE}-${ASAPP_DEP_CONFIG}")
message(STATUS "AsApp deps packages: ${ASAPP_DEP_PACKAGES}")

foreach(_pkg IN LISTS ASAPP_DEP_PACKAGES)
    string(STRIP "${_pkg}" _pkg)
    if(_pkg STREQUAL "")
        continue()
    endif()
    set(_pkg_cmake "${CMAKE_CURRENT_SOURCE_DIR}/cmake/packages/${_pkg}.cmake")
    if(NOT EXISTS "${_pkg_cmake}")
        message(FATAL_ERROR "Unknown package '${_pkg}' (missing ${_pkg_cmake})")
    endif()
    include("${_pkg_cmake}")
endforeach()
