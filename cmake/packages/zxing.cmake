# zxing — zxing-cpp 2.3.0（C++17；读码 + OLD 写码，不依赖 zint 子模块）
# 源码期望：sources/zxing/src（上游解压/克隆根，含 CMakeLists.txt）
# 导出目标：ZXing::ZXing（find_package(ZXing CONFIG)）

set(_ZXING_SRC "${ASAPP_DEP_SOURCE_ROOT}/zxing/src")
if(NOT EXISTS "${_ZXING_SRC}/CMakeLists.txt")
    message(FATAL_ERROR "zxing source missing: ${_ZXING_SRC}/CMakeLists.txt")
endif()
if(NOT EXISTS "${_ZXING_SRC}/core/CMakeLists.txt")
    message(FATAL_ERROR "zxing core missing: ${_ZXING_SRC}/core/CMakeLists.txt")
endif()

# 制品布局对齐规格 03：强制 lib/bin/include（避免 GNUInstallDirs 的 lib64）
set(CMAKE_INSTALL_LIBDIR "lib" CACHE STRING "" FORCE)
set(CMAKE_INSTALL_BINDIR "bin" CACHE STRING "" FORCE)
set(CMAKE_INSTALL_INCLUDEDIR "include" CACHE STRING "" FORCE)

# AsApp 全仓 C++17 硬上限；zxing-cpp 2.3.x 声明 cxx_std_17，禁止抬到 20
set(CMAKE_CXX_STANDARD 17 CACHE STRING "" FORCE)
set(CMAKE_CXX_STANDARD_REQUIRED ON CACHE BOOL "" FORCE)
set(CMAKE_CXX_EXTENSIONS OFF CACHE BOOL "" FORCE)

# BUILD_SHARED_LIBS 已由 AsAppDepOptions 按 ASAPP_DEP_LINKAGE 注入
set(ZXING_READERS ON CACHE BOOL "" FORCE)
set(ZXING_WRITERS "OLD" CACHE STRING "" FORCE)
set(ZXING_C_API OFF CACHE BOOL "" FORCE)
set(ZXING_EXPERIMENTAL_API OFF CACHE BOOL "" FORCE)
set(ZXING_EXAMPLES OFF CACHE BOOL "" FORCE)
set(ZXING_BLACKBOX_TESTS OFF CACHE BOOL "" FORCE)
set(ZXING_UNIT_TESTS OFF CACHE BOOL "" FORCE)
set(ZXING_PYTHON_MODULE OFF CACHE BOOL "" FORCE)
set(ZXING_DEPENDENCIES "LOCAL" CACHE STRING "" FORCE)
set(ZXING_USE_BUNDLED_ZINT ON CACHE BOOL "" FORCE)
set(ZXING_LINK_CPP_STATICALLY OFF CACHE BOOL "" FORCE)

# 不可 EXCLUDE_FROM_ALL，否则默认 ninja 不编译目标
add_subdirectory("${_ZXING_SRC}" "${CMAKE_BINARY_DIR}/_deps/zxing")

if(NOT TARGET ZXing)
    message(FATAL_ERROR "zxing recipe: expected target ZXing after add_subdirectory")
endif()

# 补充 PACKAGE_META（上游自带 install + ZXingConfig.cmake）
set(_META_DIR "${CMAKE_CURRENT_BINARY_DIR}/_meta/zxing")
file(MAKE_DIRECTORY "${_META_DIR}")
file(WRITE "${_META_DIR}/PACKAGE_META.yaml" [[
name: zxing
version: "2.3.0"
kind: compiled
license: Apache-2.0
windows_min_os: win7
upstream: zxing-cpp/zxing-cpp
cxx_standard: "17"
features:
  readers: true
  writers: old
  c_api: false
toolchain:
  generator: ninja
  preferred: clang-ninja
  windows_driver: clang-cl
  abi: msvc
]])
install(FILES "${_META_DIR}/PACKAGE_META.yaml" DESTINATION .)
