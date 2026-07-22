# stb — header-only 安装到切片（include/stb/*.h）

set(_STB_SRC "${ASAPP_DEP_SOURCE_ROOT}/stb/src")
if(NOT EXISTS "${_STB_SRC}/stb_image.h")
    message(FATAL_ERROR "stb source missing: ${_STB_SRC}/stb_image.h")
endif()

add_library(stb INTERFACE)
add_library(AsApp::stb ALIAS stb)
target_include_directories(stb INTERFACE
    "$<BUILD_INTERFACE:${_STB_SRC}>"
    "$<INSTALL_INTERFACE:include>"
)

install(FILES
    "${_STB_SRC}/stb_image.h"
    "${_STB_SRC}/stb_image_write.h"
    "${_STB_SRC}/stb_truetype.h"
    DESTINATION include/stb
)
install(TARGETS stb EXPORT stbTargets)
install(EXPORT stbTargets
    FILE stbTargets.cmake
    NAMESPACE AsApp::
    DESTINATION lib/cmake/stb
)

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/stbConfig.cmake"
"include(\"\${CMAKE_CURRENT_LIST_DIR}/stbTargets.cmake\")\n")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/stbConfig.cmake"
    DESTINATION lib/cmake/stb
)

set(_META_DIR "${CMAKE_CURRENT_BINARY_DIR}/_meta/stb")
file(MAKE_DIRECTORY "${_META_DIR}")
file(WRITE "${_META_DIR}/PACKAGE_META.yaml" [[
name: stb
version: "master-pinned"
kind: header-only
license: Public Domain / MIT-like
windows_min_os: win7
toolchain:
  generator: ninja
  preferred: clang-ninja
]])
install(FILES "${_META_DIR}/PACKAGE_META.yaml" DESTINATION .)
