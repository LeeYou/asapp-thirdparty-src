#!/usr/bin/env bash
# 统一构建入口（POSIX）：CMake + Ninja + clang
set -euo pipefail

OS="linux"
ARCH="x64"
LINKAGE="static"
CONFIG="release"
PACKAGES="nlohmann_json,stb"
INSTALL_ROOT=""
BUILD_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --os) OS="$2"; shift 2 ;;
    --arch) ARCH="$2"; shift 2 ;;
    --linkage) LINKAGE="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --packages) PACKAGES="$2"; shift 2 ;;
    --install-root) INSTALL_ROOT="$2"; shift 2 ;;
    --build-root) BUILD_ROOT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLICE="${OS}-${ARCH}-${LINKAGE}-${CONFIG}"
INSTALL_ROOT="${INSTALL_ROOT:-$REPO_ROOT/dist/$SLICE}"
BUILD_ROOT="${BUILD_ROOT:-$REPO_ROOT/build/$SLICE}"
PKG_LIST="${PACKAGES//,/;}"

case "$OS" in
  linux) TOOLCHAIN="$REPO_ROOT/cmake/toolchains/linux-clang.cmake" ;;
  macos) TOOLCHAIN="$REPO_ROOT/cmake/toolchains/macos-clang.cmake" ;;
  *) echo "Use build.ps1 for windows"; exit 1 ;;
esac

CMAKE_BUILD_TYPE="Debug"
[[ "$CONFIG" == "release" ]] && CMAKE_BUILD_TYPE="Release"

mkdir -p "$BUILD_ROOT" "$INSTALL_ROOT"

cmake -G Ninja \
  -S "$REPO_ROOT/cmake" \
  -B "$BUILD_ROOT" \
  --toolchain "$TOOLCHAIN" \
  -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_ROOT" \
  -DASAPP_DEP_OS="$OS" \
  -DASAPP_DEP_ARCH="$ARCH" \
  -DASAPP_DEP_LINKAGE="$LINKAGE" \
  -DASAPP_DEP_CONFIG="$CONFIG" \
  -DASAPP_DEP_PACKAGES="$PKG_LIST"

cmake --build "$BUILD_ROOT"
STAGING="$BUILD_ROOT/_install_staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cmake --install "$BUILD_ROOT" --prefix "$STAGING"

IFS=',' read -ra PKGS <<< "$PACKAGES"
for pkg in "${PKGS[@]}"; do
  pkg="$(echo "$pkg" | xargs)"
  [[ -z "$pkg" ]] && continue
  dest="$INSTALL_ROOT/$pkg"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -a "$STAGING"/. "$dest/"
done

echo "Done. Slice root: $INSTALL_ROOT"
