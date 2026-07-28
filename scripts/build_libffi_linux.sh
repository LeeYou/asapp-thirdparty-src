#!/usr/bin/env bash
# 构建 libffi 到 dist/<slice>/libffi（Linux x64，上游 autotools）
# 依赖：autotools 产物 configure、make、C 编译器
#
# 用法：
#   ./scripts/build_libffi_linux.sh --linkage static --config release --jobs 8
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="x64"
LINKAGE="static"
CONFIG="release"
SOURCE_ROOT=""
INSTALL_ROOT=""
BUILD_ROOT=""
JOBS="$(nproc 2>/dev/null || echo 4)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch) ARCH="$2"; shift 2 ;;
    --linkage) LINKAGE="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --source-root) SOURCE_ROOT="$2"; shift 2 ;;
    --install-root) INSTALL_ROOT="$2"; shift 2 ;;
    --build-root) BUILD_ROOT="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ "$ARCH" != "x64" && "$ARCH" != "arm64" ]]; then
  echo "ERROR: build_libffi_linux.sh supports --arch x64|arm64 (got $ARCH)" >&2
  exit 1
fi
if [[ "$LINKAGE" != "static" && "$LINKAGE" != "shared" ]]; then
  echo "ERROR: --linkage must be static|shared" >&2
  exit 1
fi
if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "ERROR: --config must be debug|release" >&2
  exit 1
fi

SLICE="linux-${ARCH}-${LINKAGE}-${CONFIG}"
SOURCE_ROOT="${SOURCE_ROOT:-$REPO_ROOT/sources/libffi/src}"
INSTALL_ROOT="${INSTALL_ROOT:-$REPO_ROOT/dist/$SLICE/libffi}"
BUILD_ROOT="${BUILD_ROOT:-$REPO_ROOT/build/$SLICE/libffi}"

if [[ ! -f "$SOURCE_ROOT/configure" ]]; then
  echo "ERROR: libffi configure not found under $SOURCE_ROOT" >&2
  exit 1
fi
if ! command -v make >/dev/null 2>&1; then
  echo "ERROR: make not found" >&2
  exit 1
fi

abs_path() {
  local p="$1"
  if [[ "$p" = /* ]]; then
    printf '%s\n' "$p"
  else
    printf '%s\n' "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
  fi
}

rm -rf "$BUILD_ROOT" "$INSTALL_ROOT"
mkdir -p "$BUILD_ROOT/work" "$INSTALL_ROOT" "$BUILD_ROOT/logs"

INSTALL_ROOT="$(abs_path "$INSTALL_ROOT")"
SOURCE_ROOT="$(abs_path "$SOURCE_ROOT")"
WORK="$(abs_path "$BUILD_ROOT/work")"

echo "libffi build"
echo "  Source : $SOURCE_ROOT"
echo "  Work   : $WORK"
echo "  Install: $INSTALL_ROOT"
echo "  Slice  : $SLICE"

CFG_ARGS=("--prefix=$INSTALL_ROOT" "--libdir=$INSTALL_ROOT/lib")
if [[ "$LINKAGE" == "static" ]]; then
  CFG_ARGS+=("--enable-static" "--disable-shared")
else
  CFG_ARGS+=("--enable-shared" "--disable-static")
fi

if [[ "$CONFIG" == "debug" ]]; then
  export CFLAGS="${CFLAGS:--g -O0}"
  export CXXFLAGS="${CXXFLAGS:--g -O0}"
else
  export CFLAGS="${CFLAGS:--O2}"
  export CXXFLAGS="${CXXFLAGS:--O2}"
fi

LOG_DIR="$BUILD_ROOT/logs"
(
  cd "$WORK"
  echo "Configure: $SOURCE_ROOT/configure ${CFG_ARGS[*]}"
  "$SOURCE_ROOT/configure" "${CFG_ARGS[@]}"
  make -j"$JOBS"
  make install
) >"$LOG_DIR/build.log" 2>"$LOG_DIR/build-stderr.log" || {
  echo "---- build.log (tail) ----" >&2
  tail -n 40 "$LOG_DIR/build.log" >&2 || true
  echo "---- build-stderr.log (tail) ----" >&2
  tail -n 40 "$LOG_DIR/build-stderr.log" >&2 || true
  echo "ERROR: libffi build failed" >&2
  exit 1
}

# 上游偶发把头文件装到 lib/libffi-*/include；归一到 include/
if [[ ! -f "$INSTALL_ROOT/include/ffi.h" ]]; then
  CAND="$(find "$INSTALL_ROOT" -type f -name ffi.h 2>/dev/null | head -n1 || true)"
  if [[ -n "$CAND" ]]; then
    mkdir -p "$INSTALL_ROOT/include"
    cp -a "$(dirname "$CAND")"/. "$INSTALL_ROOT/include/"
  fi
fi
[[ -f "$INSTALL_ROOT/include/ffi.h" ]] || {
  echo "ERROR: missing $INSTALL_ROOT/include/ffi.h" >&2
  exit 1
}

CMAKE_DIR="$INSTALL_ROOT/lib/cmake/libffi"
mkdir -p "$CMAKE_DIR"
if [[ "$LINKAGE" == "static" ]]; then
  LIB_FFI="$INSTALL_ROOT/lib/libffi.a"
  [[ -f "$LIB_FFI" ]] || { echo "ERROR: missing $LIB_FFI" >&2; exit 1; }
  cat >"$CMAKE_DIR/libffiConfig.cmake" <<'EOF'
if(TARGET AsApp::ffi)
  return()
endif()
get_filename_component(_FFI_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
add_library(AsApp::ffi STATIC IMPORTED)
set_target_properties(AsApp::ffi PROPERTIES
  IMPORTED_LOCATION "${_FFI_ROOT}/lib/libffi.a"
  INTERFACE_INCLUDE_DIRECTORIES "${_FFI_ROOT}/include")
if(NOT TARGET AsApp::libffi)
  add_library(AsApp::libffi INTERFACE IMPORTED)
  set_target_properties(AsApp::libffi PROPERTIES INTERFACE_LINK_LIBRARIES AsApp::ffi)
endif()
EOF
else
  LIB_FFI="$INSTALL_ROOT/lib/libffi.so"
  if [[ ! -e "$LIB_FFI" ]]; then
    LIB_FFI="$(ls -1 "$INSTALL_ROOT"/lib/libffi.so.* 2>/dev/null | head -n1 || true)"
  fi
  [[ -n "$LIB_FFI" && -e "$LIB_FFI" ]] || { echo "ERROR: missing libffi.so under $INSTALL_ROOT/lib" >&2; exit 1; }
  cat >"$CMAKE_DIR/libffiConfig.cmake" <<'EOF'
if(TARGET AsApp::ffi)
  return()
endif()
get_filename_component(_FFI_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(_FFI_LIB "${_FFI_ROOT}/lib/libffi.so")
if(NOT EXISTS "${_FFI_LIB}")
  file(GLOB _FFI_CAND "${_FFI_ROOT}/lib/libffi.so.*")
  list(GET _FFI_CAND 0 _FFI_LIB)
endif()
add_library(AsApp::ffi SHARED IMPORTED)
set_target_properties(AsApp::ffi PROPERTIES
  IMPORTED_LOCATION "${_FFI_LIB}"
  INTERFACE_INCLUDE_DIRECTORIES "${_FFI_ROOT}/include")
if(NOT TARGET AsApp::libffi)
  add_library(AsApp::libffi INTERFACE IMPORTED)
  set_target_properties(AsApp::libffi PROPERTIES INTERFACE_LINK_LIBRARIES AsApp::ffi)
endif()
EOF
fi

cat >"$INSTALL_ROOT/PACKAGE_META.yaml" <<EOF
name: libffi
version: "3.4.6"
kind: compiled
license: MIT
os: linux
arch: ${ARCH}
linkage: ${LINKAGE}
config: ${CONFIG}
toolchain:
  generator: autotools
  preferred: clang
  notes: "Upstream configure/make on POSIX (Windows uses cmake/packages/libffi.cmake)"
  abi: system
EOF

echo "libffi staged: $INSTALL_ROOT"
