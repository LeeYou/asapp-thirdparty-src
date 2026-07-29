#!/usr/bin/env bash
# 构建 gRPC(+捆绑 protobuf) 到 dist/<slice>/grpc（Linux x64）
# 依赖：cmake、ninja、clang/gcc；同切片 OpenSSL（dist 或 prebuilt）
#
# 用法：
#   ./scripts/build_grpc_linux.sh --linkage static --config release --jobs 16
#   ./scripts/build_grpc_linux.sh --openssl-root /path/to/openssl
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="x64"
LINKAGE="static"
CONFIG="release"
SOURCE_ROOT=""
OPENSSL_ROOT=""
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
    --openssl-root) OPENSSL_ROOT="$2"; shift 2 ;;
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
  echo "ERROR: build_grpc_linux.sh supports --arch x64|arm64 (got $ARCH)" >&2
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
SOURCE_ROOT="${SOURCE_ROOT:-$REPO_ROOT/sources/grpc/src}"
INSTALL_ROOT="${INSTALL_ROOT:-$REPO_ROOT/dist/$SLICE/grpc}"
BUILD_ROOT="${BUILD_ROOT:-$REPO_ROOT/build/$SLICE/grpc}"
TOOLCHAIN="$REPO_ROOT/cmake/toolchains/linux-clang.cmake"

# 增量：已安装则跳过（--clean 强制重编）
if asapp_dep_skip_if_ready "grpc" "$INSTALL_ROOT/PACKAGE_META.yaml"; then
  exit 0
fi

if [[ ! -f "$SOURCE_ROOT/CMakeLists.txt" ]]; then
  echo "ERROR: gRPC CMakeLists.txt not found: $SOURCE_ROOT" >&2
  exit 1
fi
for tool in cmake ninja; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: $tool not found" >&2
    exit 1
  fi
done
if [[ ! -f "$TOOLCHAIN" ]]; then
  echo "ERROR: toolchain missing: $TOOLCHAIN" >&2
  exit 1
fi

# 早期失败：缺 <filesystem> 或 GCC8 未链 -lstdc++fs
if ! asapp_dep_clang_filesystem_ok; then
  asapp_dep_print_filesystem_help
  exit 1
fi

if [[ -z "$OPENSSL_ROOT" ]]; then
  for cand in "$REPO_ROOT/dist/$SLICE/openssl" "$REPO_ROOT/prebuilt/$SLICE/openssl"; do
    if [[ -f "$cand/include/openssl/ssl.h" ]]; then
      OPENSSL_ROOT="$cand"
      break
    fi
  done
fi
if [[ -z "$OPENSSL_ROOT" || ! -f "$OPENSSL_ROOT/include/openssl/ssl.h" ]]; then
  echo "ERROR: OpenSSL root with include/openssl/ssl.h required." >&2
  echo "  Pass --openssl-root or build openssl into dist/$SLICE/openssl first." >&2
  exit 1
fi

CMAKE_BUILD_TYPE="Debug"
[[ "$CONFIG" == "release" ]] && CMAKE_BUILD_TYPE="Release"
SHARED_FLAG="OFF"
[[ "$LINKAGE" == "shared" ]] && SHARED_FLAG="ON"

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT" "$BUILD_ROOT/logs"
rm -rf "$INSTALL_ROOT"
mkdir -p "$INSTALL_ROOT"

echo "gRPC build"
echo "  Source : $SOURCE_ROOT"
echo "  OpenSSL: $OPENSSL_ROOT"
echo "  Build  : $BUILD_ROOT"
echo "  Install: $INSTALL_ROOT"
echo "  Slice  : $SLICE"

CMAKE_ARGS=(
  -G Ninja
  -S "$SOURCE_ROOT"
  -B "$BUILD_ROOT"
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN"
  -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE"
  -DCMAKE_INSTALL_PREFIX="$INSTALL_ROOT"
  -DBUILD_SHARED_LIBS="$SHARED_FLAG"
  -DgRPC_BUILD_TESTS=OFF
  -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF
  -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF
  -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF
  -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF
  -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF
  -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF
  -DgRPC_INSTALL=ON
  -DgRPC_SSL_PROVIDER=package
  -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT"
  -DgRPC_ZLIB_PROVIDER=module
  -DgRPC_CARES_PROVIDER=module
  -DgRPC_RE2_PROVIDER=module
  -DgRPC_ABSL_PROVIDER=module
  -DgRPC_PROTOBUF_PROVIDER=module
  -Dprotobuf_BUILD_TESTS=OFF
  -Dprotobuf_INSTALL=ON
  -DCMAKE_CXX_STANDARD=17
)

# Linux shared：与 Windows 同策略，关闭 protobuf 自带 libupb，降低符号冲突风险
if [[ "$LINKAGE" == "shared" ]]; then
  CMAKE_ARGS+=(-Dprotobuf_BUILD_LIBUPB=OFF)
fi

LOG_DIR="$BUILD_ROOT/logs"
run_logged() {
  local name="$1"
  shift
  echo "  Running: $name"
  if ! "$@" >"$LOG_DIR/${name}.log" 2>&1; then
    echo "---- ${name}.log (tail) ----" >&2
    tail -n 60 "$LOG_DIR/${name}.log" >&2 || true
    echo "ERROR: gRPC $name failed" >&2
    exit 1
  fi
}

# shared：构建目录中的 .so 需可被 protoc 插件加载
export PATH="$BUILD_ROOT:$BUILD_ROOT/bin:${PATH:-}"
if [[ "$LINKAGE" == "shared" ]]; then
  export LD_LIBRARY_PATH="$BUILD_ROOT:$BUILD_ROOT/bin:${LD_LIBRARY_PATH:-}"
fi

run_logged configure cmake "${CMAKE_ARGS[@]}"

# shellcheck source=AsAppDepBuildParallel.sh
source "$REPO_ROOT/scripts/AsAppDepBuildParallel.sh"
JOBS="$(asapp_dep_normalize_jobs "$JOBS")"
echo "  Running: build (-j$JOBS, live ninja output)"
mkdir -p "$LOG_DIR"
if ! asapp_dep_cmake_build "$BUILD_ROOT" "$JOBS" "$LOG_DIR/build.log"; then
  echo "---- build.log (tail) ----" >&2
  tail -n 60 "$LOG_DIR/build.log" >&2 || true
  echo "ERROR: gRPC build failed" >&2
  exit 1
fi
run_logged install cmake --install "$BUILD_ROOT"

cat >"$INSTALL_ROOT/PACKAGE_META.yaml" <<EOF
name: grpc
version: "1.67.1"
kind: compiled
license: Apache-2.0
os: linux
arch: ${ARCH}
linkage: ${LINKAGE}
config: ${CONFIG}
components:
  - protobuf (bundled 27.2)
  - protoc
  - grpc_cpp_plugin
toolchain:
  generator: ninja
  preferred: clang
  exception: "Ninja + linux-clang.cmake; SSL via slice OpenSSL package"
  abi: system
EOF

for p in \
  "$INSTALL_ROOT/bin/protoc" \
  "$INSTALL_ROOT/bin/grpc_cpp_plugin" \
  "$INSTALL_ROOT/lib/cmake/grpc/gRPCConfig.cmake"
do
  if [[ ! -e "$p" ]]; then
    echo "ERROR: missing expected install artifact: $p" >&2
    exit 1
  fi
done

echo "Done. gRPC installed to $INSTALL_ROOT"
