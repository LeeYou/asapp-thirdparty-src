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

# 专用脚本包：勿走 cmake/packages 占位 recipe
SKIP_HINT_PKGS="openssl grpc libffi libcef"

IFS=',' read -ra PKGS <<< "$PACKAGES"
for raw in "${PKGS[@]}"; do
  pkg="$(echo "$raw" | xargs)"
  [[ -z "$pkg" ]] && continue

  for skip in $SKIP_HINT_PKGS; do
    if [[ "$pkg" == "$skip" ]]; then
      case "$pkg" in
        openssl) echo "SKIP openssl: use scripts/build_openssl_linux.sh (or build_linux_x64_matrix.sh)" ;;
        grpc) echo "SKIP grpc: use scripts/build_grpc_linux.sh (or build_linux_x64_matrix.sh)" ;;
        libffi) echo "SKIP libffi: use scripts/build_libffi_linux.sh (autotools; Windows uses libffi.cmake)" ;;
        libcef) echo "SKIP libcef: Linux packaging not available yet (Windows: package_libcef_windows.ps1)" ;;
        *) echo "SKIP $pkg: dedicated script required" ;;
      esac
      continue 2
    fi
  done

  recipe="$REPO_ROOT/cmake/packages/${pkg}.cmake"
  if [[ ! -f "$recipe" ]]; then
    echo "ERROR: unknown package '$pkg' (missing $recipe)" >&2
    exit 1
  fi
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
