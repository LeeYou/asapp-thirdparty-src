#!/usr/bin/env bash
# 产出 Linux x64 主交付四切片：static|shared × debug|release
#
# 默认包：CMake recipe + openssl + libffi + grpc + libcef
# libcef：仅写入 linux-x64-shared-release（官方 binary，非重编）
#
# 用法：
#   ./scripts/build_linux_x64_matrix.sh
#   ./scripts/build_linux_x64_matrix.sh --packages nlohmann_json,stb,sqlite --jobs 16
#   ./scripts/build_linux_x64_matrix.sh --linkage static --config release
#   ./scripts/build_linux_x64_matrix.sh --skip-grpc --skip-openssl --skip-libcef
#   ASAPP_PREBUILT_ROOT=/path/to/prebuilt ./scripts/build_linux_x64_matrix.sh --sync
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=AsAppDepBuildParallel.sh
source "$REPO_ROOT/scripts/AsAppDepBuildParallel.sh"
PACKAGES="nlohmann_json,stb,spdlog,boost,sqlite,gtest,libffi,zxing,openssl,grpc,libcef"
LINKAGE_FILTER="all"
CONFIG_FILTER="all"
JOBS="$(nproc 2>/dev/null || echo 4)"
SYNC=0
SKIP_OPENSSL=0
SKIP_LIBFFI=0
SKIP_GRPC=0
SKIP_LIBCEF=0
CEF_BUNDLE_ROOT="${ASAPP_CEF_BUNDLE:-}"
PREBUILT_ROOT="${ASAPP_PREBUILT_ROOT:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --packages) PACKAGES="$2"; shift 2 ;;
    --linkage) LINKAGE_FILTER="$2"; shift 2 ;;
    --config) CONFIG_FILTER="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --sync) SYNC=1; shift ;;
    --prebuilt-root) PREBUILT_ROOT="$2"; shift 2 ;;
    --skip-openssl) SKIP_OPENSSL=1; shift ;;
    --skip-libffi) SKIP_LIBFFI=1; shift ;;
    --skip-grpc) SKIP_GRPC=1; shift ;;
    --skip-libcef) SKIP_LIBCEF=1; shift ;;
    --cef-bundle-root) CEF_BUNDLE_ROOT="$2"; shift 2 ;;
    --clean) export ASAPP_DEP_CLEAN=1; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

JOBS="$(asapp_dep_normalize_jobs "$JOBS")"
export CMAKE_BUILD_PARALLEL_LEVEL="$JOBS"

CLEAN_ARGS=()
if [[ "${ASAPP_DEP_CLEAN:-0}" == "1" ]]; then
  CLEAN_ARGS=(--clean)
  echo "NOTE: --clean / ASAPP_DEP_CLEAN=1 — force rebuild all packages in this matrix"
fi

LINKAGES=(static shared)
CONFIGS=(debug release)
[[ "$LINKAGE_FILTER" != "all" ]] && LINKAGES=("$LINKAGE_FILTER")
[[ "$CONFIG_FILTER" != "all" ]] && CONFIGS=("$CONFIG_FILTER")

# 解析包列表 → cmake / 专用脚本
IFS=',' read -ra PKG_ARR <<< "$PACKAGES"
CMAKE_PKGS=()
WANT_OPENSSL=0
WANT_LIBFFI=0
WANT_GRPC=0
WANT_LIBCEF=0
for raw in "${PKG_ARR[@]}"; do
  pkg="$(echo "$raw" | xargs)"
  [[ -z "$pkg" ]] && continue
  case "$pkg" in
    openssl) WANT_OPENSSL=1 ;;
    libffi) WANT_LIBFFI=1 ;;
    grpc) WANT_GRPC=1 ;;
    libcef) WANT_LIBCEF=1 ;;
    *) CMAKE_PKGS+=("$pkg") ;;
  esac
done
[[ "$SKIP_OPENSSL" -eq 1 ]] && WANT_OPENSSL=0
[[ "$SKIP_LIBFFI" -eq 1 ]] && WANT_LIBFFI=0
[[ "$SKIP_GRPC" -eq 1 ]] && WANT_GRPC=0
[[ "$SKIP_LIBCEF" -eq 1 ]] && WANT_LIBCEF=0

if [[ "$SYNC" -eq 1 ]]; then
  if [[ -z "$PREBUILT_ROOT" ]]; then
    # submodule 的 prebuilt/.git 多为文件（gitdir 指针），不能只用 -d 判断
    if [[ -e "$REPO_ROOT/prebuilt/.git" && -d "$REPO_ROOT/prebuilt" ]]; then
      PREBUILT_ROOT="$REPO_ROOT/prebuilt"
    elif [[ -d "$REPO_ROOT/prebuilt" ]]; then
      # 已检出工作树但尚未挂 .git（少见）；仍可作为 sync 目标
      PREBUILT_ROOT="$REPO_ROOT/prebuilt"
    elif [[ -d "$(dirname "$REPO_ROOT")/asapp-thirdparty-prebuilt" ]]; then
      PREBUILT_ROOT="$(dirname "$REPO_ROOT")/asapp-thirdparty-prebuilt"
    else
      echo "ERROR: set ASAPP_PREBUILT_ROOT or --prebuilt-root for --sync" >&2
      echo "  hint: git submodule update --init --recursive prebuilt" >&2
      echo "     or: --prebuilt-root $REPO_ROOT/prebuilt" >&2
      exit 1
    fi
  fi
  # 禁止把源码仓根目录当成制品仓（会污染源码树）
  if [[ "$(cd "$PREBUILT_ROOT" 2>/dev/null && pwd)" == "$REPO_ROOT" ]]; then
    echo "ERROR: --prebuilt-root must be the prebuilt repo/dir, not asapp-thirdparty-src root" >&2
    echo "  use: --prebuilt-root $REPO_ROOT/prebuilt" >&2
    exit 1
  fi
  echo "Sync target prebuilt root: $PREBUILT_ROOT"
fi

CMAKE_JOINED=""
if [[ ${#CMAKE_PKGS[@]} -gt 0 ]]; then
  CMAKE_JOINED="$(IFS=,; echo "${CMAKE_PKGS[*]}")"
fi

echo "=== Linux x64 matrix: linkages=${LINKAGES[*]} configs=${CONFIGS[*]} ==="
echo "  cmake   : ${CMAKE_JOINED:-"(none)"}"
echo "  openssl : $WANT_OPENSSL  libffi: $WANT_LIBFFI  grpc: $WANT_GRPC  libcef: $WANT_LIBCEF  jobs=$JOBS"
echo "  note    : incremental skip if PACKAGE_META exists; --clean forces rebuild; ninja -j$JOBS"

for link in "${LINKAGES[@]}"; do
  for cfg in "${CONFIGS[@]}"; do
    slice="linux-x64-${link}-${cfg}"
    dist="$REPO_ROOT/dist/$slice"
    echo
    echo "======== $slice ========"
    mkdir -p "$dist"

    if [[ -n "$CMAKE_JOINED" ]]; then
      "$REPO_ROOT/scripts/build.sh" \
        --os linux --arch x64 --linkage "$link" --config "$cfg" \
        --packages "$CMAKE_JOINED" --install-root "$dist" --jobs "$JOBS" \
        "${CLEAN_ARGS[@]}"
    fi

    # openssl 与 libffi 无依赖，可并行
    pids=()
    names=()
    if [[ "$WANT_OPENSSL" -eq 1 ]]; then
      "$REPO_ROOT/scripts/build_openssl_linux.sh" \
        --arch x64 --linkage "$link" --config "$cfg" \
        --install-root "$dist/openssl" --jobs "$JOBS" \
        "${CLEAN_ARGS[@]}" &
      pids+=("$!")
      names+=("openssl")
    fi
    if [[ "$WANT_LIBFFI" -eq 1 ]]; then
      "$REPO_ROOT/scripts/build_libffi_linux.sh" \
        --arch x64 --linkage "$link" --config "$cfg" \
        --install-root "$dist/libffi" --jobs "$JOBS" \
        "${CLEAN_ARGS[@]}" &
      pids+=("$!")
      names+=("libffi")
    fi
    for i in "${!pids[@]}"; do
      if ! wait "${pids[$i]}"; then
        echo "ERROR: ${names[$i]} failed in slice $slice" >&2
        exit 1
      fi
    done

    if [[ "$WANT_GRPC" -eq 1 ]]; then
      "$REPO_ROOT/scripts/build_grpc_linux.sh" \
        --arch x64 --linkage "$link" --config "$cfg" \
        --openssl-root "$dist/openssl" \
        --install-root "$dist/grpc" --jobs "$JOBS" \
        "${CLEAN_ARGS[@]}"
    fi

    if [[ "$SYNC" -eq 1 ]]; then
      dest="$PREBUILT_ROOT/$slice"
      asapp_dep_sync_tree "$dist" "$dest"
    fi
  done
done

# libcef：仅 shared-release（官方 binary，与 Windows 矩阵一致）
if [[ "$WANT_LIBCEF" -eq 1 ]]; then
  cef_slice="linux-x64-shared-release"
  cef_dest="$REPO_ROOT/dist/$cef_slice/libcef"
  echo
  echo "======== libcef -> $cef_slice ========"
  CEF_ARGS=(--arch x64 --dest-root "$cef_dest")
  [[ -n "$CEF_BUNDLE_ROOT" ]] && CEF_ARGS+=(--bundle-root "$CEF_BUNDLE_ROOT")
  [[ "${ASAPP_DEP_CLEAN:-0}" == "1" ]] && CEF_ARGS+=(--clean)
  "$REPO_ROOT/scripts/package_libcef_linux.sh" "${CEF_ARGS[@]}"
  if [[ "$SYNC" -eq 1 ]]; then
    pre_cef="$PREBUILT_ROOT/$cef_slice/libcef"
    asapp_dep_sync_dir "$cef_dest" "$pre_cef"
  fi
fi

echo
echo "Done. dist roots under $REPO_ROOT/dist/linux-x64-*"
if [[ "$WANT_GRPC" -eq 1 && "$WANT_OPENSSL" -eq 0 ]]; then
  echo "NOTE: grpc requested without openssl in this run — ensure dist/<slice>/openssl exists."
fi
