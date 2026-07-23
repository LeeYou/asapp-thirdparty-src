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

# openssl / grpc / libcef：POSIX 矩阵尚未提供专用脚本
SKIP_HINT_PKGS="openssl grpc libcef"

IFS=',' read -ra PKGS <<< "$PACKAGES"
for raw in "${PKGS[@]}"; do
  pkg="$(echo "$raw" | xargs)"
  [[ -z "$pkg" ]] && continue

  for skip in $SKIP_HINT_PKGS; do
    if [[ "$pkg" == "$skip" ]]; then
      echo "SKIP $pkg: no POSIX recipe yet (Windows: scripts/build_*_windows.ps1 / package_libcef_windows.ps1)"
      continue 2
    fi
  done

  recipe="$REPO_ROOT/cmake/packages/${pkg}.cmake"
  if [[ ! -f "$recipe" ]]; then
    echo "ERROR: unknown package '$pkg' (missing $recipe)" >&2
    exit 1
  fi

  # openssl.cmake / grpc.cmake 是 FATAL 占位；上面已跳过同名包
  pkg_build="$REPO_ROOT/build/$SLICE/$pkg"
  pkg_dest="$INSTALL_ROOT/$pkg"
  rm -rf "$pkg_build" "$pkg_dest"
  mkdir -p "$pkg_build" "$pkg_dest"

  echo "Building: $pkg"
  cmake -G Ninja \
    -S "$REPO_ROOT/cmake" \
    -B "$pkg_build" \
    --toolchain "$TOOLCHAIN" \
    -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
    -DCMAKE_INSTALL_PREFIX="$pkg_dest" \
    -DASAPP_DEP_OS="$OS" \
    -DASAPP_DEP_ARCH="$ARCH" \
    -DASAPP_DEP_LINKAGE="$LINKAGE" \
    -DASAPP_DEP_CONFIG="$CONFIG" \
    -DASAPP_DEP_PACKAGES="$pkg"

  cmake --build "$pkg_build" --parallel "$JOBS"
  cmake --install "$pkg_build"
done

echo "Done. Slice root: $INSTALL_ROOT"
