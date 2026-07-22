# libffi — Windows x64 静态库（自维护最小 CMake；非上游官方 Windows 主路径）
# 源码期望：sources/libffi/src（上游解压根）

set(_FFI_ROOT "${ASAPP_DEP_SOURCE_ROOT}/libffi/src")
if(NOT EXISTS "${_FFI_ROOT}/src/prep_cif.c")
    message(FATAL_ERROR "libffi source missing under ${_FFI_ROOT}")
endif()

if(NOT WIN32)
    message(FATAL_ERROR "cmake/packages/libffi.cmake currently supports Windows only; use autotools on POSIX")
endif()
if(NOT ASAPP_DEP_ARCH STREQUAL "x64")
    message(FATAL_ERROR "libffi package recipe currently supports windows x64 only (arch=${ASAPP_DEP_ARCH})")
endif()

set(_FFI_GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/libffi_gen")
file(MAKE_DIRECTORY "${_FFI_GEN_DIR}")

# 最小 fficonfig.h（x64 Windows / MSVC ABI / clang-cl）
file(WRITE "${_FFI_GEN_DIR}/fficonfig.h" [[
#ifdef _MSC_VER
# define HAVE_ALLOCA 1
# define alloca _alloca
#endif
#define STDC_HEADERS 1
#define HAVE_MEMCPY 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_STDINT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_UINT8_T 1
#define HAVE_UINT16_T 1
#define HAVE_UINT32_T 1
#define HAVE_UINT64_T 1
#define HAVE_INT8_T 1
#define HAVE_INT16_T 1
#define HAVE_INT32_T 1
#define HAVE_INT64_T 1
#define HAVE_LONG_DOUBLE 0
#define SIZEOF_DOUBLE 8
#define SIZEOF_LONG_DOUBLE 8
#define SIZEOF_SIZE_T 8
#define FFI_MMAP_EXEC_WRIT 1
#ifdef LIBFFI_ASM
# define FFI_HIDDEN(name)
#else
# define FFI_HIDDEN
#endif
]])

set(_FFI_H_IN "${_FFI_ROOT}/include/ffi.h.in")
set(_FFI_H_OUT "${_FFI_GEN_DIR}/ffi.h")
if(EXISTS "${_FFI_ROOT}/include/ffi.h")
    configure_file("${_FFI_ROOT}/include/ffi.h" "${_FFI_H_OUT}" COPYONLY)
elseif(EXISTS "${_FFI_H_IN}")
    file(READ "${_FFI_H_IN}" _ffi_h_content)
    string(REPLACE "@VERSION@" "3.4.6" _ffi_h_content "${_ffi_h_content}")
    string(REPLACE "@TARGET@" "X86_WIN64" _ffi_h_content "${_ffi_h_content}")
    string(REPLACE "@HAVE_LONG_DOUBLE@" "0" _ffi_h_content "${_ffi_h_content}")
    string(REPLACE "@HAVE_LONG_DOUBLE_VARIANT@" "0" _ffi_h_content "${_ffi_h_content}")
    string(REPLACE "@FFI_EXEC_TRAMPOLINE_TABLE@" "0" _ffi_h_content "${_ffi_h_content}")
    file(WRITE "${_FFI_H_OUT}" "${_ffi_h_content}")
else()
    message(FATAL_ERROR "libffi: neither include/ffi.h nor ffi.h.in found")
endif()

configure_file("${_FFI_ROOT}/src/x86/ffitarget.h" "${_FFI_GEN_DIR}/ffitarget.h" COPYONLY)

set(_FFI_SOURCES
    "${_FFI_ROOT}/src/prep_cif.c"
    "${_FFI_ROOT}/src/types.c"
    "${_FFI_ROOT}/src/raw_api.c"
    "${_FFI_ROOT}/src/java_raw_api.c"
    "${_FFI_ROOT}/src/closures.c"
    "${_FFI_ROOT}/src/tramp.c"
    "${_FFI_ROOT}/src/x86/ffiw64.c"
)

# 汇编：clang 汇编 win64.S（gas）；避免 clang-cl 直接吃 .S
set(_FFI_ASM_OBJ "")
if(EXISTS "${_FFI_ROOT}/src/x86/win64.S")
    find_program(_CLANG_ASM NAMES clang.exe clang)
    if(_CLANG_ASM)
        set(_FFI_ASM_OBJ "${CMAKE_CURRENT_BINARY_DIR}/win64_asm.obj")
        add_custom_command(
            OUTPUT "${_FFI_ASM_OBJ}"
            COMMAND "${_CLANG_ASM}" -c -o "${_FFI_ASM_OBJ}"
                    "-I${_FFI_GEN_DIR}" "-I${_FFI_ROOT}/include" "-I${_FFI_ROOT}/src/x86"
                    -target x86_64-pc-windows-msvc -DFFI_BUILDING -DFFI_STATIC_BUILD -DX86_WIN64 -DLIBFFI_ASM
                    "${_FFI_ROOT}/src/x86/win64.S"
            DEPENDS "${_FFI_ROOT}/src/x86/win64.S" "${_FFI_H_OUT}" "${_FFI_GEN_DIR}/fficonfig.h"
            COMMENT "Assembling libffi win64.S with clang"
            VERBATIM
        )
        message(STATUS "libffi: using clang assembler for win64.S (${_CLANG_ASM})")
    else()
        message(WARNING "libffi: clang.exe not found; building without ASM (may be incomplete)")
    endif()
endif()

if(ASAPP_DEP_LINKAGE STREQUAL "shared")
    if(_FFI_ASM_OBJ)
        add_library(ffi SHARED ${_FFI_SOURCES} "${_FFI_ASM_OBJ}")
    else()
        add_library(ffi SHARED ${_FFI_SOURCES})
    endif()
else()
    if(_FFI_ASM_OBJ)
        add_library(ffi STATIC ${_FFI_SOURCES} "${_FFI_ASM_OBJ}")
    else()
        add_library(ffi STATIC ${_FFI_SOURCES})
    endif()
endif()

target_include_directories(ffi PUBLIC
    "$<BUILD_INTERFACE:${_FFI_GEN_DIR}>"
    "$<BUILD_INTERFACE:${_FFI_ROOT}/include>"
    "$<INSTALL_INTERFACE:include>"
)
target_compile_definitions(ffi PRIVATE FFI_BUILDING)
if(ASAPP_DEP_LINKAGE STREQUAL "static")
    target_compile_definitions(ffi PUBLIC FFI_STATIC_BUILD)
endif()
if(MSVC OR (WIN32 AND CMAKE_CXX_COMPILER_ID MATCHES "Clang"))
    target_compile_options(ffi PRIVATE /W0)
endif()
set_target_properties(ffi PROPERTIES OUTPUT_NAME ffi)

add_library(AsApp::libffi ALIAS ffi)

install(FILES "${_FFI_H_OUT}" "${_FFI_GEN_DIR}/ffitarget.h" DESTINATION include)
install(TARGETS ffi EXPORT libffiTargets
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)
install(EXPORT libffiTargets
    FILE libffiTargets.cmake
    NAMESPACE AsApp::
    DESTINATION lib/cmake/libffi
)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/libffiConfig.cmake" [[
include("${CMAKE_CURRENT_LIST_DIR}/libffiTargets.cmake")
if(TARGET AsApp::ffi AND NOT TARGET AsApp::libffi)
  add_library(AsApp::libffi INTERFACE IMPORTED)
  set_target_properties(AsApp::libffi PROPERTIES INTERFACE_LINK_LIBRARIES AsApp::ffi)
endif()
]])
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/libffiConfig.cmake" DESTINATION lib/cmake/libffi)

set(_META_DIR "${CMAKE_CURRENT_BINARY_DIR}/_meta/libffi")
file(MAKE_DIRECTORY "${_META_DIR}")
file(WRITE "${_META_DIR}/PACKAGE_META.yaml" [[
name: libffi
version: "3.4.6"
kind: compiled
license: MIT
windows_min_os: win7
toolchain:
  generator: ninja
  preferred: clang-ninja
  windows_driver: clang-cl
  abi: msvc
  notes: "Custom Windows x64 CMake recipe; not upstream autotools."
]])
install(FILES "${_META_DIR}/PACKAGE_META.yaml" DESTINATION .)
