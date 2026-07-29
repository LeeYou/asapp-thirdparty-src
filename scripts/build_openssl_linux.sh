#!/usr/bin/env bash
# 构建 OpenSSL 到 dist/<slice>/openssl（Linux x64）
# 依赖：perl、make、C/C++ 编译器（推荐 clang 或 gcc）
#
# 用法：
#   ./scripts/build_openssl_linux.sh --linkage static --config release --jobs 16
#   ./scripts/build_openssl_linux.sh --linkage shared --config debug \
#     --install-root /path/to/dist/linux-x64-shared-debug/openssl
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="x64"
LINKAGE="static"
CONFIG="release"
SOURCE_ROOT=""
INSTALL_ROOT=""
BUILD_ROOT=""
JOBS="$(nproc 2>/dev/null || echo 4)"

CLEAN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch) ARCH="$2"; shift 2 ;;
    --linkage) LINKAGE="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --source-root) SOURCE_ROOT="$2"; shift 2 ;;
    --install-root) INSTALL_ROOT="$2"; shift 2 ;;
    --build-root) BUILD_ROOT="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --clean) CLEAN=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done
[[ "$CLEAN" -eq 1 ]] && export ASAPP_DEP_CLEAN=1
# shellcheck source=AsAppDepIncremental.sh
source "$REPO_ROOT/scripts/AsAppDepIncremental.sh"

if [[ "$ARCH" != "x64" && "$ARCH" != "arm64" ]]; then
  echo "ERROR: build_openssl_linux.sh supports --arch x64|arm64 (got $ARCH)" >&2
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
SOURCE_ROOT="${SOURCE_ROOT:-$REPO_ROOT/sources/openssl/src}"
INSTALL_ROOT="${INSTALL_ROOT:-$REPO_ROOT/dist/$SLICE/openssl}"
BUILD_ROOT="${BUILD_ROOT:-$REPO_ROOT/build/$SLICE/openssl}"

if asapp_dep_skip_if_ready "openssl" "$INSTALL_ROOT/PACKAGE_META.yaml"; then
  exit 0
fi

if [[ ! -f "$SOURCE_ROOT/Configure" ]]; then
  echo "ERROR: OpenSSL Configure not found under $SOURCE_ROOT" >&2
  exit 1
fi
if ! command -v perl >/dev/null 2>&1; then
  echo "ERROR: perl not found" >&2
  exit 1
fi
if ! command -v make >/dev/null 2>&1; then
  echo "ERROR: make not found" >&2
  exit 1
fi

# Configure 要求绝对 prefix
abs_path() {
  local p="$1"
  if [[ "$p" = /* ]]; then
    printf '%s\n' "$p"
  else
    printf '%s\n' "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
  fi
}

mkdir -p "$(dirname "$INSTALL_ROOT")" "$(dirname "$BUILD_ROOT")"
rm -rf "$BUILD_ROOT" "$INSTALL_ROOT"
mkdir -p "$BUILD_ROOT/src" "$INSTALL_ROOT" "$BUILD_ROOT/logs"

echo "OpenSSL build"
echo "  Source : $SOURCE_ROOT"
echo "  Work   : $BUILD_ROOT/src"
echo "  Install: $INSTALL_ROOT"
echo "  Slice  : $SLICE"

# 工作树拷贝，避免污染 sources/
echo "Copying OpenSSL sources to work tree..."
cp -a "$SOURCE_ROOT"/. "$BUILD_ROOT/src/"
# 去掉可能残留的构建产物
find "$BUILD_ROOT/src" -type f \( -name '*.o' -o -name '*.a' -o -name '*.so' -o -name '*.so.*' \) -delete 2>/dev/null || true

INSTALL_ROOT="$(abs_path "$INSTALL_ROOT")"
WORK_SRC="$(abs_path "$BUILD_ROOT/src")"

# OpenSSL Configure 目标名随宿主机/容器架构变化（x64 vs arm64）
case "$(uname -m)" in
  x86_64)
    OPENSSL_TARGET="linux-x86_64"
    ;;
  aarch64|arm64)
    OPENSSL_TARGET="linux-aarch64"
    ;;
  *)
    echo "ERROR: unsupported uname -m=$(uname -m) for OpenSSL Configure" >&2
    exit 1
    ;;
esac

CFG_OPTS=("${OPENSSL_TARGET}" "no-tests" "no-docs" "--prefix=$INSTALL_ROOT" "--openssldir=$INSTALL_ROOT/ssl" "--libdir=lib")
[[ "$LINKAGE" == "static" ]] && CFG_OPTS+=("no-shared")
[[ "$CONFIG" == "debug" ]] && CFG_OPTS+=("--debug")

LOG_DIR="$BUILD_ROOT/logs"
(
  cd "$WORK_SRC"
  echo "Configure: perl Configure ${CFG_OPTS[*]}"
  perl Configure "${CFG_OPTS[@]}"
  echo "make -j${JOBS}"
  make -j"$JOBS"
  make install_sw
) >"$LOG_DIR/build.log" 2>"$LOG_DIR/build-stderr.log" || {
  echo "---- build.log (tail) ----" >&2
  tail -n 40 "$LOG_DIR/build.log" >&2 || true
  echo "---- build-stderr.log (tail) ----" >&2
  tail -n 40 "$LOG_DIR/build-stderr.log" >&2 || true
  echo "ERROR: OpenSSL build failed" >&2
  exit 1
}

SSL_H="$INSTALL_ROOT/include/openssl/ssl.h"
if [[ ! -f "$SSL_H" ]]; then
  echo "ERROR: missing $SSL_H" >&2
  exit 1
fi

CMAKE_DIR="$INSTALL_ROOT/lib/cmake/OpenSSL"
mkdir -p "$CMAKE_DIR"

if [[ "$LINKAGE" == "static" ]]; then
  LIB_SSL="$INSTALL_ROOT/lib/libssl.a"
  LIB_CRYPTO="$INSTALL_ROOT/lib/libcrypto.a"
  [[ -f "$LIB_SSL" ]] || { echo "ERROR: missing $LIB_SSL" >&2; exit 1; }
  [[ -f "$LIB_CRYPTO" ]] || { echo "ERROR: missing $LIB_CRYPTO" >&2; exit 1; }
  cat >"$CMAKE_DIR/OpenSSLConfig.cmake" <<'EOF'
if(TARGET OpenSSL::SSL)
  return()
endif()
get_filename_component(_OPENSSL_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
add_library(OpenSSL::Crypto STATIC IMPORTED)
set_target_properties(OpenSSL::Crypto PROPERTIES
  IMPORTED_LOCATION "${_OPENSSL_ROOT}/lib/libcrypto.a"
  INTERFACE_INCLUDE_DIRECTORIES "${_OPENSSL_ROOT}/include"
  INTERFACE_LINK_LIBRARIES "pthread;dl")
add_library(OpenSSL::SSL STATIC IMPORTED)
set_target_properties(OpenSSL::SSL PROPERTIES
  IMPORTED_LOCATION "${_OPENSSL_ROOT}/lib/libssl.a"
  INTERFACE_INCLUDE_DIRECTORIES "${_OPENSSL_ROOT}/include"
  INTERFACE_LINK_LIBRARIES "OpenSSL::Crypto")
set(OPENSSL_FOUND TRUE)
set(OPENSSL_INCLUDE_DIR "${_OPENSSL_ROOT}/include")
set(OPENSSL_CRYPTO_LIBRARY "${_OPENSSL_ROOT}/lib/libcrypto.a")
set(OPENSSL_SSL_LIBRARY "${_OPENSSL_ROOT}/lib/libssl.a")
set(OPENSSL_VERSION "3.5.6")
EOF
else
  # 优先无版本号 .so；若不存在则取 soname 链接目标
  LIB_CRYPTO="$INSTALL_ROOT/lib/libcrypto.so"
  LIB_SSL="$INSTALL_ROOT/lib/libssl.so"
  if [[ ! -e "$LIB_CRYPTO" ]]; then
    LIB_CRYPTO="$(ls -1 "$INSTALL_ROOT"/lib/libcrypto.so.* 2>/dev/null | head -n1 || true)"
  fi
  if [[ ! -e "$LIB_SSL" ]]; then
    LIB_SSL="$(ls -1 "$INSTALL_ROOT"/lib/libssl.so.* 2>/dev/null | head -n1 || true)"
  fi
  [[ -n "$LIB_CRYPTO" && -e "$LIB_CRYPTO" ]] || { echo "ERROR: missing libcrypto.so under $INSTALL_ROOT/lib" >&2; exit 1; }
  [[ -n "$LIB_SSL" && -e "$LIB_SSL" ]] || { echo "ERROR: missing libssl.so under $INSTALL_ROOT/lib" >&2; exit 1; }
  cat >"$CMAKE_DIR/OpenSSLConfig.cmake" <<'EOF'
if(TARGET OpenSSL::SSL)
  return()
endif()
get_filename_component(_OPENSSL_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(_CRYPTO_SO "${_OPENSSL_ROOT}/lib/libcrypto.so")
set(_SSL_SO "${_OPENSSL_ROOT}/lib/libssl.so")
if(NOT EXISTS "${_CRYPTO_SO}")
  file(GLOB _CRYPTO_CAND "${_OPENSSL_ROOT}/lib/libcrypto.so.*")
  list(GET _CRYPTO_CAND 0 _CRYPTO_SO)
endif()
if(NOT EXISTS "${_SSL_SO}")
  file(GLOB _SSL_CAND "${_OPENSSL_ROOT}/lib/libssl.so.*")
  list(GET _SSL_CAND 0 _SSL_SO)
endif()
add_library(OpenSSL::Crypto SHARED IMPORTED)
set_target_properties(OpenSSL::Crypto PROPERTIES
  IMPORTED_LOCATION "${_CRYPTO_SO}"
  INTERFACE_INCLUDE_DIRECTORIES "${_OPENSSL_ROOT}/include"
  INTERFACE_LINK_LIBRARIES "pthread;dl")
add_library(OpenSSL::SSL SHARED IMPORTED)
set_target_properties(OpenSSL::SSL PROPERTIES
  IMPORTED_LOCATION "${_SSL_SO}"
  INTERFACE_INCLUDE_DIRECTORIES "${_OPENSSL_ROOT}/include"
  INTERFACE_LINK_LIBRARIES "OpenSSL::Crypto")
set(OPENSSL_FOUND TRUE)
set(OPENSSL_INCLUDE_DIR "${_OPENSSL_ROOT}/include")
set(OPENSSL_CRYPTO_LIBRARY "${_CRYPTO_SO}")
set(OPENSSL_SSL_LIBRARY "${_SSL_SO}")
set(OPENSSL_VERSION "3.5.6")
EOF
fi

cat >"$INSTALL_ROOT/PACKAGE_META.yaml" <<EOF
name: openssl
version: "3.5.6"
kind: compiled
license: Apache-2.0
os: linux
arch: ${ARCH}
linkage: ${LINKAGE}
config: ${CONFIG}
toolchain:
  generator: make
  preferred: clang
  exception: "perl Configure + make (OpenSSL official Unix path)"
  abi: system
EOF

echo "OpenSSL staged: $INSTALL_ROOT"
