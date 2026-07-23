#!/usr/bin/env bash
# 产出 Linux x64 主交付四切片骨架：static|shared × debug|release
#
# 当前覆盖（CMake packages）：nlohmann_json, stb, spdlog, boost, sqlite, gtest
# 未覆盖（待后续脚本）：openssl, grpc, libffi(视平台), libcef
#
# 用法：
#   ./scripts/build_linux_x64_matrix.sh
#   ./scripts/build_linux_x64_matrix.sh --packages nlohmann_json,stb,sqlite --jobs 16
#   ./scripts/build_linux_x64_matrix.sh --linkage static --config release
#   ASAPP_PREBUILT_ROOT=/path/to/prebuilt ./scripts/build_linux_x64_matrix.sh --sync
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGES="nlohmann_json,stb,spdlog,boost,sqlite,gtest"
LINKAGE_FILTER="all"
CONFIG_FILTER="all"
JOBS="$(nproc 2>/dev/null || echo 4)"
SYNC=0
PREBUILT_ROOT="${ASAPP_PREBUILT_ROOT:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --packages) PACKAGES="$2"; shift 2 ;;
    --linkage) LINKAGE_FILTER="$2"; shift 2 ;;
    --config) CONFIG_FILTER="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --sync) SYNC=1; shift ;;
    --prebuilt-root) PREBUILT_ROOT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

LINKAGES=(static shared)
CONFIGS=(debug release)
[[ "$LINKAGE_FILTER" != "all" ]] && LINKAGES=("$LINKAGE_FILTER")
[[ "$CONFIG_FILTER" != "all" ]] && CONFIGS=("$CONFIG_FILTER")

if [[ "$SYNC" -eq 1 ]]; then
  if [[ -z "$PREBUILT_ROOT" ]]; then
    if [[ -d "$REPO_ROOT/prebuilt/.git" ]]; then
      PREBUILT_ROOT="$REPO_ROOT/prebuilt"
    elif [[ -d "$(dirname "$REPO_ROOT")/asapp-thirdparty-prebuilt" ]]; then
      PREBUILT_ROOT="$(dirname "$REPO_ROOT")/asapp-thirdparty-prebuilt"
    else
      echo "ERROR: set ASAPP_PREBUILT_ROOT or --prebuilt-root for --sync" >&2
      exit 1
    fi
  fi
fi

echo "=== Linux x64 matrix: linkages=${LINKAGES[*]} configs=${CONFIGS[*]} packages=$PACKAGES jobs=$JOBS ==="

for link in "${LINKAGES[@]}"; do
  for cfg in "${CONFIGS[@]}"; do
    slice="linux-x64-${link}-${cfg}"
    dist="$REPO_ROOT/dist/$slice"
    echo
    echo "======== $slice ========"
    mkdir -p "$dist"
    "$REPO_ROOT/scripts/build.sh" \
      --os linux --arch x64 --linkage "$link" --config "$cfg" \
      --packages "$PACKAGES" --install-root "$dist" --jobs "$JOBS"

    if [[ "$SYNC" -eq 1 ]]; then
      dest="$PREBUILT_ROOT/$slice"
      echo "Sync $dist -> $dest"
      rm -rf "$dest"
      mkdir -p "$dest"
      cp -a "$dist"/. "$dest"/
    fi
  done
done

echo
echo "Done. dist roots under $REPO_ROOT/dist/linux-x64-*"
echo "NOTE: openssl / grpc / libcef Linux recipes are not in this matrix yet."
