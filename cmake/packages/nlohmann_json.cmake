# nlohmann_json — header-only 安装到切片

set(_NLOHMANN_SRC "${ASAPP_DEP_SOURCE_ROOT}/nlohmann/src/single_include")
if(NOT EXISTS "${_NLOHMANN_SRC}/nlohmann/json.hpp")
    message(FATAL_ERROR "nlohmann_json source missing: ${_NLOHMANN_SRC}/nlohmann/json.hpp")
endif()

add_library(nlohmann_json INTERFACE)
add_library(nlohmann_json::nlohmann_json ALIAS nlohmann_json)
target_include_directories(nlohmann_json INTERFACE
    "$<BUILD_INTERFACE:${_NLOHMANN_SRC}>"
    "$<INSTALL_INTERFACE:include>"
)

install(DIRECTORY "${_NLOHMANN_SRC}/nlohmann"
    DESTINATION include
)
install(TARGETS nlohmann_json EXPORT nlohmann_jsonTargets)
install(EXPORT nlohmann_jsonTargets
    FILE nlohmann_jsonTargets.cmake
    NAMESPACE nlohmann_json::
    DESTINATION lib/cmake/nlohmann_json
)

include(CMakePackageConfigHelpers)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/nlohmann_jsonConfig.cmake"
"include(\"\${CMAKE_CURRENT_LIST_DIR}/nlohmann_jsonTargets.cmake\")\n")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/nlohmann_jsonConfig.cmake"
    DESTINATION lib/cmake/nlohmann_json
)

# 包元数据（安装到包根）
set(_META_DIR "${CMAKE_CURRENT_BINARY_DIR}/_meta/nlohmann_json")
file(MAKE_DIRECTORY "${_META_DIR}")
file(WRITE "${_META_DIR}/PACKAGE_META.yaml" [[
name: nlohmann_json
version: "3.11.3"
kind: header-only
license: MIT
windows_min_os: win7
toolchain:
  generator: ninja
  preferred: clang-ninja
]])
install(FILES "${_META_DIR}/PACKAGE_META.yaml" DESTINATION .)
