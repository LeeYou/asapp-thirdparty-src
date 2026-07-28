#!/usr/bin/env bash
# 统一构建入口（POSIX）：按包独立 configure/build/install 到 dist/<slice>/<pkg>
# 用法示例：
#   ./scripts/build.sh --arch x64 --linkage static --config release \
#     --packages nlohmann_json,stb,sqlite,gtest
set -euo pipefail

OS="linux"
ARCH="x64"
LINKAGE="static"
CONFIG="release"
PACKAGES="nlohmann_json,stb"
INSTALL_ROOT=""
JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --os) OS="$2"; shift 2 ;;
    --arch) ARCH="$2"; shift 2 ;;
    --linkage) LINKAGE="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --packages) PACKAGES="$2"; shift 2 ;;
    --install-root) INSTALL_ROOT="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=AsAppDepBuildParallel.sh
source "$REPO_ROOT/scripts/AsAppDepBuildParallel.sh"
JOBS="$(asapp_dep_normalize_jobs "${JOBS:-}")"
SLICE="${OS}-${ARCH}-${LINKAGE}-${CONFIG}"
INSTALL_ROOT="${INSTALL_ROOT:-$REPO_ROOT/dist/$SLICE}"

case "$OS" in
  linux) TOOLCHAIN="$REPO_ROOT/cmake/toolchains/linux-clang.cmake" ;;
  macos) TOOLCHAIN="$REPO_ROOT/cmake/toolchains/macos-clang.cmake" ;;
  *) echo "Use build.ps1 for windows"; exit 1 ;;
esac

CMAKE_BUILD_TYPE="Debug"
[[ "$CONFIG" == "release" ]] && CMAKE_BUILD_TYPE="Release"

mkdir -p "$INSTALL_ROOT"
echo "Slice: $SLICE -> $INSTALL_ROOT (jobs=$JOBS)"
export CMAKE_BUILD_PARALLEL_LEVEL="$JOBS"

# 专用脚本包：勿走 cmake/packages 占位 recipe
SKIP_HINT_PKGS="openssl grpc libffi libcef"

# 同切片内独立 CMake 包可并行配置/编译；默认按 CPU 开包级并发，但限制以免内存爆炸
PKG_PARALLEL="${ASAPP_DEP_PKG_PARALLEL:-}"
if [[ -z "$PKG_PARALLEL" ]]; then
  PKG_PARALLEL=$(( JOBS / 4 ))
  [[ "$PKG_PARALLEL" -lt 1 ]] && PKG_PARALLEL=1
  [[ "$PKG_PARALLEL" -gt 4 ]] && PKG_PARALLEL=4
fi

build_one_cmake_pkg() {
  local pkg="$1"
  local recipe="$REPO_ROOT/cmake/packages/${pkg}.cmake"
  if [[ ! -f "$recipe" ]]; then
    echo "ERROR: unknown package '$pkg' (missing $recipe)" >&2
    return 1
  fi
  local pkg_build="$REPO_ROOT/build/$SLICE/$pkg"
  local pkg_dest="$INSTALL_ROOT/$pkg"
  # 包级并发时均分 -j，避免 4 包 × 全核 过订阅
  local pkg_jobs="$JOBS"
  if [[ "$PKG_PARALLEL" -gt 1 ]]; then
    pkg_jobs=$(( JOBS / PKG_PARALLEL ))
    [[ "$pkg_jobs" -lt 1 ]] && pkg_jobs=1
  fi

  rm -rf "$pkg_build" "$pkg_dest"
  mkdir -p "$pkg_build" "$pkg_dest"

  echo "Building: $pkg (pkg_jobs=$pkg_jobs)"
  # 使用 -DCMAKE_TOOLCHAIN_FILE（兼容 CMake < 3.21；勿用 --toolchain，旧版会把路径误当成 -S）
  cmake -G Ninja \
    -S "$REPO_ROOT/cmake" \
    -B "$pkg_build" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
    -DCMAKE_INSTALL_PREFIX="$pkg_dest" \
    -DASAPP_DEP_OS="$OS" \
    -DASAPP_DEP_ARCH="$ARCH" \
    -DASAPP_DEP_LINKAGE="$LINKAGE" \
    -DASAPP_DEP_CONFIG="$CONFIG" \
    -DASAPP_DEP_PACKAGES="$pkg"

  asapp_dep_cmake_build "$pkg_build" "$pkg_jobs"
  cmake --install "$pkg_build"
}

IFS=',' read -ra PKGS <<< "$PACKAGES"
TO_BUILD=()
for raw in "${PKGS[@]}"; do
  pkg="$(echo "$raw" | xargs)"
  [[ -z "$pkg" ]] && continue

  skip_it=0
  for skip in $SKIP_HINT_PKGS; do
    if [[ "$pkg" == "$skip" ]]; then
      case "$pkg" in
        openssl) echo "SKIP openssl: use scripts/build_openssl_linux.sh (or build_linux_x64_matrix.sh)" ;;
        grpc) echo "SKIP grpc: use scripts/build_grpc_linux.sh (or build_linux_x64_matrix.sh)" ;;
        libffi) echo "SKIP libffi: use scripts/build_libffi_linux.sh (autotools; Windows uses libffi.cmake)" ;;
        libcef) echo "SKIP libcef: Linux packaging not available yet (Windows: package_libcef_windows.ps1)" ;;
        *) echo "SKIP $pkg: dedicated script required" ;;
      esac
      skip_it=1
      break
    fi
  done
  [[ "$skip_it" -eq 1 ]] && continue
  TO_BUILD+=("$pkg")
done

echo "CMake packages (${#TO_BUILD[@]}), PKG_PARALLEL=$PKG_PARALLEL, JOBS=$JOBS"

fail=0
pids=()
names=()
for pkg in "${TO_BUILD[@]}"; do
  while [[ "${#pids[@]}" -ge "$PKG_PARALLEL" ]]; do
    if ! wait "${pids[0]}"; then
      echo "ERROR: package build failed: ${names[0]}" >&2
      fail=1
    fi
    pids=("${pids[@]:1}")
    names=("${names[@]:1}")
  done
  if [[ "$PKG_PARALLEL" -eq 1 ]]; then
    build_one_cmake_pkg "$pkg" || fail=1
  else
    build_one_cmake_pkg "$pkg" &
    pids+=("$!")
    names+=("$pkg")
  fi
done
for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then
    echo "ERROR: package build failed: ${names[$i]}" >&2
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "Done. Slice root: $INSTALL_ROOT"
