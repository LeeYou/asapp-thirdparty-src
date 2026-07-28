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
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

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

# 早期失败：Ubuntu 18.04 + 仅 GCC7 libstdc++ 时 Abseil 会缺 <filesystem>
if command -v clang++ >/dev/null 2>&1; then
  _fs_probe="$(mktemp -t asapp_fs_probe_XXXXXX.cpp)"
  _fs_bin="$(mktemp -t asapp_fs_probe_XXXXXX)"
  cat >"$_fs_probe" <<'EOF'
#include <filesystem>
int main() { return std::filesystem::temp_directory_path().empty() ? 1 : 0; }
EOF
  _fs_ok=0
  if [[ -d /usr/lib/gcc/x86_64-linux-gnu/8 ]] || [[ -d /usr/lib/gcc/x86_64-linux-gnu/9 ]] \
    || [[ -d /usr/lib/gcc/x86_64-linux-gnu/10 ]] || [[ -d /usr/lib/gcc/x86_64-linux-gnu/11 ]]; then
    # 探测时带上与 toolchain 相同的思路（具体 flags 由 CMake toolchain 注入）
    if clang++ -std=c++17 --gcc-toolchain=/usr -o "$_fs_bin" "$_fs_probe" >/dev/null 2>&1; then
      _fs_ok=1
    fi
  elif clang++ -std=c++17 -o "$_fs_bin" "$_fs_probe" >/dev/null 2>&1; then
    _fs_ok=1
  fi
  rm -f "$_fs_probe" "$_fs_bin"
  if [[ "$_fs_ok" -ne 1 ]]; then
    echo "ERROR: clang++ cannot compile #include <filesystem> (needed by gRPC/Abseil)." >&2
    echo "  On Ubuntu 18.04: apt-get install -y g++-8   then rm -rf build/linux-x64-* and retry." >&2
    echo "  Prefer Ubuntu 20.04+ build hosts. See docs/BUILD.md." >&2
    exit 1
  fi
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
