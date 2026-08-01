#!/usr/bin/env bash
# 将官方 CEF binary bundle 打包为制品切片 linux-{x64|arm64}-shared-release/libcef。
#
# CEF 以官方预编译包为主（非源码重编）。输出适配器布局：
#   include/ cmake/ libcef_dll/ Release/ Resources/ locales/ lib/libcef.so
# 并生成 AsApp::libcef 的 Config。
# 默认排除 chrome-sandbox（体积/权限；app-gui 当前 USE_SANDBOX=OFF）。
# 官方包通常仅提供 Release runtime → 对应 shared-release 切片。
# 发布场景：拷贝后对 Release/*.so 执行 strip（官方 Linux 包含 ~1GB 调试符号）。
#
# 用法：
#   ./scripts/package_libcef_linux.sh --arch x64 \
#     --dest-root dist/linux-x64-shared-release/libcef
#   ./scripts/package_libcef_linux.sh --arch arm64 --bundle-root /path/to/cef_binary_*_linuxarm64
#   ASAPP_CEF_BUNDLE=/path/to/bundle ./scripts/package_libcef_linux.sh --arch x64 --dest-root ...
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=AsAppDepIncremental.sh
source "$REPO_ROOT/scripts/AsAppDepIncremental.sh"

ARCH="x64"
BUNDLE_ROOT=""
DEST_ROOT=""
VERSION="102.0.10+gf249b2e+chromium-102.0.5005.115"
INCLUDE_SANDBOX=0
CLEAN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch) ARCH="$2"; shift 2 ;;
    --bundle-root) BUNDLE_ROOT="$2"; shift 2 ;;
    --dest-root) DEST_ROOT="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --include-sandbox) INCLUDE_SANDBOX=1; shift ;;
    --clean) CLEAN=1; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done
[[ "$CLEAN" -eq 1 ]] && export ASAPP_DEP_CLEAN=1

if [[ "$ARCH" != "x64" && "$ARCH" != "arm64" ]]; then
  echo "ERROR: --arch must be x64|arm64 (got $ARCH)" >&2
  exit 1
fi

BUNDLE_SUFFIX="linux64"
[[ "$ARCH" == "arm64" ]] && BUNDLE_SUFFIX="linuxarm64"

DEST_ROOT="${DEST_ROOT:-$REPO_ROOT/dist/linux-${ARCH}-shared-release/libcef}"

if asapp_dep_skip_if_ready "libcef" "$DEST_ROOT/PACKAGE_META.yaml"; then
  exit 0
fi

# 解析官方 CEF binary 根（含 include/cef_app.h）
resolve_cef_bundle() {
  local hint="$1"
  local suffix="$2"
  local candidates=()
  local c src_root hit archive

  [[ -n "$hint" ]] && candidates+=("$hint")
  [[ -n "${ASAPP_CEF_BUNDLE:-}" ]] && candidates+=("$ASAPP_CEF_BUNDLE")

  for c in "${candidates[@]}"; do
    if [[ -n "$c" && -f "$c/include/cef_app.h" ]]; then
      (cd "$c" && pwd)
      return 0
    fi
  done

  src_root="$REPO_ROOT/sources/libcef/src"
  if [[ -f "$src_root/include/cef_app.h" ]]; then
    (cd "$src_root" && pwd)
    return 0
  fi
  if [[ -d "$src_root" ]]; then
    hit="$(find "$src_root" -mindepth 1 -maxdepth 1 -type d -name "cef_binary_*_${suffix}" 2>/dev/null \
      | sort -r | head -n 1 || true)"
    if [[ -n "$hit" && -f "$hit/include/cef_app.h" ]]; then
      (cd "$hit" && pwd)
      return 0
    fi
  fi

  # 可选：从 archives/libcef 解压到 sources/libcef/src（仅本机/CI 有归档时）
  archive="$(find "$REPO_ROOT/archives/libcef" -maxdepth 1 -type f \
    -name "cef_binary_*_${suffix}.tar.bz2" 2>/dev/null | sort -r | head -n 1 || true)"
  if [[ -n "$archive" && -f "$archive" ]]; then
    # 进度信息必须走 stderr，stdout 仅返回 bundle 路径（供 BUNDLE="$(...)" 捕获）
    echo "Extracting CEF archive: $archive" >&2
    mkdir -p "$src_root"
    tar -xjf "$archive" -C "$src_root"
    hit="$(find "$src_root" -mindepth 1 -maxdepth 1 -type d -name "cef_binary_*_${suffix}" 2>/dev/null \
      | sort -r | head -n 1 || true)"
    if [[ -n "$hit" && -f "$hit/include/cef_app.h" ]]; then
      (cd "$hit" && pwd)
      return 0
    fi
  fi

  return 1
}

BUNDLE="$(resolve_cef_bundle "$BUNDLE_ROOT" "$BUNDLE_SUFFIX" || true)"
if [[ -z "$BUNDLE" ]]; then
  echo "ERROR: CEF ${BUNDLE_SUFFIX} bundle not found." >&2
  echo "  Pass --bundle-root / set ASAPP_CEF_BUNDLE," >&2
  echo "  or place under sources/libcef/src/cef_binary_*_${BUNDLE_SUFFIX}/," >&2
  echo "  or put archive at archives/libcef/cef_binary_*_${BUNDLE_SUFFIX}.tar.bz2" >&2
  exit 1
fi

echo "Arch:   $ARCH ($BUNDLE_SUFFIX)"
echo "Bundle: $BUNDLE"
echo "Dest:   $DEST_ROOT"

if [[ -e "$DEST_ROOT" ]]; then
  chmod -R u+w "$DEST_ROOT" 2>/dev/null || true
  rm -rf "$DEST_ROOT"
fi
mkdir -p "$DEST_ROOT"

copy_tree() {
  local src="$1"
  local dst="$2"
  if [[ ! -d "$src" ]]; then
    echo "ERROR: Missing source: $src" >&2
    exit 1
  fi
  mkdir -p "$dst"
  cp -a "$src"/. "$dst"/
}

copy_tree "$BUNDLE/include" "$DEST_ROOT/include"
copy_tree "$BUNDLE/cmake" "$DEST_ROOT/cmake"
copy_tree "$BUNDLE/libcef_dll" "$DEST_ROOT/libcef_dll"

RELEASE_SRC="$BUNDLE/Release"
RELEASE_DST="$DEST_ROOT/Release"
if [[ ! -d "$RELEASE_SRC" ]]; then
  echo "ERROR: Missing Release/: $RELEASE_SRC" >&2
  exit 1
fi
mkdir -p "$RELEASE_DST"
shopt -s nullglob dotglob
for item in "$RELEASE_SRC"/*; do
  name="$(basename "$item")"
  if [[ "$INCLUDE_SANDBOX" -eq 0 && "$name" == "chrome-sandbox" ]]; then
    echo "Skip $name"
    continue
  fi
  cp -a "$item" "$RELEASE_DST/"
done
shopt -u nullglob dotglob

if [[ ! -f "$RELEASE_DST/libcef.so" ]]; then
  echo "ERROR: Release/libcef.so missing after copy" >&2
  exit 1
fi

# 发布体积：官方 Linux CEF 的 libcef.so 等带完整调试符号（常 >1GB）。
# strip 后通常降至 ~200MB 量级，不影响运行时行为；仅丢失有意义的本地栈符号。
strip_cef_release_sos() {
  local dir="$1"
  local strip_bin=""
  local so before after

  if command -v strip >/dev/null 2>&1; then
    strip_bin="strip"
  elif command -v llvm-strip >/dev/null 2>&1; then
    strip_bin="llvm-strip"
  else
    echo "WARNING: strip/llvm-strip not found; keeping unstripped CEF .so (large)." >&2
    return 0
  fi

  shopt -s nullglob
  for so in "$dir"/*.so "$dir"/*.so.*; do
    [[ -f "$so" && ! -L "$so" ]] || continue
    before="$(stat -c '%s' "$so" 2>/dev/null || stat -f '%z' "$so")"
    if "$strip_bin" --strip-unneeded "$so" 2>/dev/null || "$strip_bin" -S "$so" 2>/dev/null; then
      after="$(stat -c '%s' "$so" 2>/dev/null || stat -f '%z' "$so")"
      echo "Stripped $(basename "$so"): $((before / 1024 / 1024))MB -> $((after / 1024 / 1024))MB ($strip_bin)"
    else
      echo "WARNING: failed to strip $so" >&2
    fi
  done
  shopt -u nullglob
}

strip_cef_release_sos "$RELEASE_DST"

# Resources（不含 locales）+ 顶层 locales（与 Windows / 历史 stage 一致）
RES_SRC="$BUNDLE/Resources"
RES_DST="$DEST_ROOT/Resources"
LOC_DST="$DEST_ROOT/locales"
mkdir -p "$RES_DST" "$LOC_DST"
if [[ -d "$RES_SRC" ]]; then
  shopt -s nullglob dotglob
  for item in "$RES_SRC"/*; do
    name="$(basename "$item")"
    if [[ "$name" == "locales" ]]; then
      continue
    fi
    cp -a "$item" "$RES_DST/"
  done
  shopt -u nullglob dotglob
  if [[ -d "$RES_SRC/locales" ]]; then
    copy_tree "$RES_SRC/locales" "$LOC_DST"
  fi
fi

# lib/：写 GNU ld INPUT 脚本指向 Release/（勿用裸 symlink：经 Windows/Git 同步会落成
# 文本 "../Release/libcef.so"，ld 报 file format not recognized）
LIB_DST="$DEST_ROOT/lib"
mkdir -p "$LIB_DST"
printf 'INPUT(../Release/libcef.so)\n' >"$LIB_DST/libcef.so"

CMAKE_DIR="$DEST_ROOT/lib/cmake/libcef"
mkdir -p "$CMAKE_DIR"
cat >"$CMAKE_DIR/libcefConfig.cmake" <<'EOF'
if(TARGET AsApp::libcef)
  return()
endif()
get_filename_component(_LIBCEF_PREFIX "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
add_library(AsApp::libcef UNKNOWN IMPORTED)
if(WIN32)
  set_target_properties(AsApp::libcef PROPERTIES
    IMPORTED_LOCATION "${_LIBCEF_PREFIX}/lib/libcef.lib"
    INTERFACE_INCLUDE_DIRECTORIES "${_LIBCEF_PREFIX}/include")
else()
  set_target_properties(AsApp::libcef PROPERTIES
    IMPORTED_LOCATION "${_LIBCEF_PREFIX}/Release/libcef.so"
    INTERFACE_INCLUDE_DIRECTORIES "${_LIBCEF_PREFIX}/include")
endif()
set(AsApp_libcef_PREFIX "${_LIBCEF_PREFIX}" CACHE PATH "AsApp libcef package root")
set(AsApp_libcef_BIN_DIR "${_LIBCEF_PREFIX}/Release" CACHE PATH "AsApp libcef runtime bin (Release/)")
set(AsApp_libcef_RELEASE_DIR "${_LIBCEF_PREFIX}/Release" CACHE PATH "AsApp libcef Release")
set(AsApp_libcef_RESOURCES_DIR "${_LIBCEF_PREFIX}/Resources" CACHE PATH "AsApp libcef Resources")
set(AsApp_libcef_LOCALES_DIR "${_LIBCEF_PREFIX}/locales" CACHE PATH "AsApp libcef locales")
set(AsApp_libcef_SDK_ROOT "${_LIBCEF_PREFIX}" CACHE PATH "AsApp libcef SDK root (FindCEF/libcef_dll)")
EOF

cat >"$DEST_ROOT/PACKAGE_META.yaml" <<EOF
name: libcef
version: "$VERSION"
kind: shared-runtime
license: BSD-like
linux_min_glibc: "2.28"
notes: "Official CEF binary stage (no rebuild). chrome-sandbox excluded by default. Release/*.so stripped for publish size (upstream ships ~1GB debug symbols). Wrapper sources under libcef_dll/. Runtime SOs live in Release/ (CEF upstream layout)."
linkage: shared
toolchain:
  generator: n/a-official-binary
  preferred: official-cef-binary
runtime_files:
  - Release/*.so
  - Release/*.so.*
  - Release/*.bin
  - Release/*.json
plugin_dirs:
  - locales
  - Resources
paths:
  include: include
  lib: lib
  bin: Release
  resources: Resources
  locales: locales
  sdk_cmake: cmake
  sdk_wrapper: libcef_dll
EOF

for name in LICENSE.txt README.txt; do
  if [[ -f "$BUNDLE/$name" ]]; then
    cp -a "$BUNDLE/$name" "$DEST_ROOT/"
  fi
done

echo "libcef package ready at $DEST_ROOT"
ls -1 "$DEST_ROOT" | sed 's/^/  /'
