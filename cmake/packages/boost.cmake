# boost — header-only 安装到切片（Asio/Beast 消费；整棵 boost/ 头树）
#
# 源码布局：sources/boost/src/boost/...（上游 strip 后的头目录）
# 制品布局：<slice>/boost/include/boost/...

set(_BOOST_SRC_ROOT "${ASAPP_DEP_SOURCE_ROOT}/boost/src")
set(_BOOST_HEADERS "${_BOOST_SRC_ROOT}/boost")
if(NOT EXISTS "${_BOOST_HEADERS}/asio.hpp")
    message(FATAL_ERROR
        "boost headers missing: ${_BOOST_HEADERS}/asio.hpp\n"
        "  Place Boost 1.90.0 tree under sources/boost/src (see sources/boost/README.md).")
endif()
if(NOT EXISTS "${_BOOST_HEADERS}/beast/core.hpp")
    message(FATAL_ERROR "boost.beast headers missing: ${_BOOST_HEADERS}/beast/core.hpp")
endif()

add_library(boost_headers INTERFACE)
add_library(Boost::headers ALIAS boost_headers)
add_library(AsApp::boost ALIAS boost_headers)
target_include_directories(boost_headers INTERFACE
    "$<BUILD_INTERFACE:${_BOOST_SRC_ROOT}>"
    "$<INSTALL_INTERFACE:include>"
)

install(DIRECTORY "${_BOOST_HEADERS}"
    DESTINATION include
)
install(TARGETS boost_headers EXPORT boostTargets)
install(EXPORT boostTargets
    FILE boostTargets.cmake
    NAMESPACE Boost::
    DESTINATION lib/cmake/boost
)

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/boostConfig.cmake" [[
if(TARGET Boost::headers)
  return()
endif()
include("${CMAKE_CURRENT_LIST_DIR}/boostTargets.cmake")
if(TARGET Boost::boost_headers AND NOT TARGET Boost::headers)
  add_library(Boost::headers ALIAS Boost::boost_headers)
endif()
if(NOT TARGET AsApp::boost)
  add_library(AsApp::boost INTERFACE IMPORTED)
  set_target_properties(AsApp::boost PROPERTIES INTERFACE_LINK_LIBRARIES Boost::headers)
endif()
]])
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/boostConfig.cmake"
    DESTINATION lib/cmake/boost
)

set(_META_DIR "${CMAKE_CURRENT_BINARY_DIR}/_meta/boost")
file(MAKE_DIRECTORY "${_META_DIR}")
file(WRITE "${_META_DIR}/PACKAGE_META.yaml" [[
name: boost
version: "1.90.0"
kind: header-only
license: BSL-1.0
windows_min_os: win7
notes: "Full boost/ header tree for Asio + Beast (no b2 libs)"
toolchain:
  generator: ninja
  preferred: clang-ninja
]])
install(FILES "${_META_DIR}/PACKAGE_META.yaml" DESTINATION .)
