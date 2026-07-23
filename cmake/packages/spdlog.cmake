# spdlog — header-only 安装（与当前 AsApp 仅 include 用法对齐）

set(_SPDLOG_SRC "${ASAPP_DEP_SOURCE_ROOT}/spdlog/src")
set(_SPDLOG_INC "${_SPDLOG_SRC}/include")
if(NOT EXISTS "${_SPDLOG_INC}/spdlog/spdlog.h")
    # 兼容解压布局：sources/spdlog/src 即为上游根，或 sources/spdlog/include
    if(EXISTS "${ASAPP_DEP_SOURCE_ROOT}/spdlog/include/spdlog/spdlog.h")
        set(_SPDLOG_INC "${ASAPP_DEP_SOURCE_ROOT}/spdlog/include")
    elseif(EXISTS "${_SPDLOG_SRC}/spdlog/spdlog.h")
        set(_SPDLOG_INC "${_SPDLOG_SRC}")
    else()
        message(FATAL_ERROR "spdlog headers missing under ${_SPDLOG_SRC}")
    endif()
endif()

add_library(spdlog INTERFACE)
add_library(spdlog::spdlog ALIAS spdlog)
target_include_directories(spdlog INTERFACE
    "$<BUILD_INTERFACE:${_SPDLOG_INC}>"
    "$<INSTALL_INTERFACE:include>"
)
# 勿定义 SPDLOG_HEADER_ONLY：common.h 在未定义 SPDLOG_COMPILED_LIB 时会自行 #define；
# 命令行再传会导致 MSVC C4005，CEF /WX 下升为 C2220。

install(DIRECTORY "${_SPDLOG_INC}/spdlog" DESTINATION include)
install(TARGETS spdlog EXPORT spdlogTargets)
install(EXPORT spdlogTargets
    FILE spdlogTargets.cmake
    NAMESPACE spdlog::
    DESTINATION lib/cmake/spdlog
)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/spdlogConfig.cmake"
"include(\"\${CMAKE_CURRENT_LIST_DIR}/spdlogTargets.cmake\")\n")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/spdlogConfig.cmake"
    DESTINATION lib/cmake/spdlog
)

set(_META_DIR "${CMAKE_CURRENT_BINARY_DIR}/_meta/spdlog")
file(MAKE_DIRECTORY "${_META_DIR}")
file(WRITE "${_META_DIR}/PACKAGE_META.yaml" [[
name: spdlog
version: "1.14.1"
kind: header-only
license: MIT
windows_min_os: win7
toolchain:
  generator: ninja
  preferred: clang-ninja
]])
install(FILES "${_META_DIR}/PACKAGE_META.yaml" DESTINATION .)
