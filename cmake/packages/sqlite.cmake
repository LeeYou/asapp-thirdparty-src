# sqlite — amalgamation 静态库（Win7 基线宏由 AsAppDepOptions 注入）

set(_SQLITE_SRC "${ASAPP_DEP_SOURCE_ROOT}/sqlite/src")
set(_SQLITE_C "${_SQLITE_SRC}/sqlite3.c")
set(_SQLITE_H "${_SQLITE_SRC}/sqlite3.h")
if(NOT EXISTS "${_SQLITE_C}" OR NOT EXISTS "${_SQLITE_H}")
    message(FATAL_ERROR "sqlite amalgamation missing under ${_SQLITE_SRC}")
endif()

if(ASAPP_DEP_LINKAGE STREQUAL "shared")
    add_library(asapp_sqlite3 SHARED "${_SQLITE_C}")
    # MSVC 默认不导出 C 符号；无此则 DLL 无导出表、导入库无 __imp_sqlite3_*
    if(WIN32)
        set_target_properties(asapp_sqlite3 PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
    endif()
else()
    add_library(asapp_sqlite3 STATIC "${_SQLITE_C}")
endif()

add_library(SQLite::SQLite3 ALIAS asapp_sqlite3)
set_target_properties(asapp_sqlite3 PROPERTIES
    OUTPUT_NAME asapp_sqlite3
    POSITION_INDEPENDENT_CODE ON
    LINKER_LANGUAGE C
)
target_include_directories(asapp_sqlite3 PUBLIC
    "$<BUILD_INTERFACE:${_SQLITE_SRC}>"
    "$<INSTALL_INTERFACE:include>"
)
target_compile_definitions(asapp_sqlite3 PUBLIC
    SQLITE_THREADSAFE=1
    SQLITE_DEFAULT_WAL_SYNCHRONOUS=1
    SQLITE_OMIT_LOAD_EXTENSION
    SQLITE_DQS=0
)
if(MSVC OR (WIN32 AND CMAKE_CXX_COMPILER_ID MATCHES "Clang"))
    target_compile_options(asapp_sqlite3 PRIVATE /W0)
else()
    target_compile_options(asapp_sqlite3 PRIVATE -w)
endif()
if(UNIX AND NOT APPLE)
    target_link_libraries(asapp_sqlite3 PUBLIC pthread dl)
elseif(UNIX)
    target_link_libraries(asapp_sqlite3 PUBLIC pthread)
endif()

install(FILES "${_SQLITE_H}" "${_SQLITE_SRC}/sqlite3ext.h" DESTINATION include)
install(TARGETS asapp_sqlite3 EXPORT sqlite3Targets
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)
install(EXPORT sqlite3Targets
    FILE SQLite3Targets.cmake
    NAMESPACE SQLite::
    DESTINATION lib/cmake/SQLite3
)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/SQLite3Config.cmake" [[
include("${CMAKE_CURRENT_LIST_DIR}/SQLite3Targets.cmake")
# 导出名为 SQLite::asapp_sqlite3；为业务仓提供稳定别名
if(TARGET SQLite::asapp_sqlite3)
    if(NOT TARGET SQLite::SQLite3)
        add_library(SQLite::SQLite3 INTERFACE IMPORTED)
        set_target_properties(SQLite::SQLite3 PROPERTIES
            INTERFACE_LINK_LIBRARIES SQLite::asapp_sqlite3)
    endif()
    if(NOT TARGET asapp_sqlite3)
        add_library(asapp_sqlite3 INTERFACE IMPORTED)
        set_target_properties(asapp_sqlite3 PROPERTIES
            INTERFACE_LINK_LIBRARIES SQLite::asapp_sqlite3)
    endif()
endif()
]])
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/SQLite3Config.cmake"
    DESTINATION lib/cmake/SQLite3
)

set(_META_DIR "${CMAKE_CURRENT_BINARY_DIR}/_meta/sqlite")
file(MAKE_DIRECTORY "${_META_DIR}")
file(WRITE "${_META_DIR}/PACKAGE_META.yaml" [[
name: sqlite
version: "3.53.3"
kind: compiled
license: Public Domain
windows_min_os: win7
toolchain:
  generator: ninja
  preferred: clang-ninja
  windows_driver: clang-cl
  abi: msvc
]])
install(FILES "${_META_DIR}/PACKAGE_META.yaml" DESTINATION .)
