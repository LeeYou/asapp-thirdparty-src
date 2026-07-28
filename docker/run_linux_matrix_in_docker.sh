#!/usr/bin/env bash
# 在 Debian 10 (glibc 2.28) Docker 镜像内编译 Linux 第三方矩阵。
# 用法：
#   ./docker/run_linux_matrix_in_docker.sh --arch amd64 [--jobs N] [--sync]
#   ./docker/run_linux_matrix_in_docker.sh --arch amd64 --proxy http://127.0.0.1:7890 --build-image --sync
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ARCH="amd64"
JOBS="$(nproc 2>/dev/null || echo 8)"
DO_SYNC=0
EXTRA_ARGS=()
PROXY=""
HTTP_PROXY_ARG="${HTTP_PROXY:-${http_proxy:-}}"
HTTPS_PROXY_ARG="${HTTPS_PROXY:-${https_proxy:-}}"
ALL_PROXY_ARG="${ALL_PROXY:-${all_proxy:-}}"
NO_PROXY_ARG="${NO_PROXY:-${no_proxy:-localhost,127.0.0.1}}"

usage() {
  cat <<'EOF'
用法: run_linux_matrix_in_docker.sh [选项]

  --arch amd64|arm64   目标架构（默认 amd64）
  --jobs N             并行度（默认 nproc）
  --sync               传给矩阵脚本的 --sync
  --image NAME         覆盖镜像名
  --build-image        若镜像不存在则先构建（走 build_linux_image.sh，可带代理）
  --proxy URL          构建镜像 + 容器内运行均使用该 HTTP/HTTPS 代理
  --http-proxy URL     仅 HTTP
  --https-proxy URL    仅 HTTPS
  --all-proxy URL      ALL_PROXY（可选）
  --no-proxy LIST      NO_PROXY（默认 localhost,127.0.0.1）
  -h, --help           帮助

说明：正式构建根为 debian:10 / glibc 2.28，见 docs/DOCKER_LINUX_BUILD.md
EOF
}

IMAGE=""
BUILD_IMAGE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      ARCH="${2:?}"
      shift 2
      ;;
    --jobs)
      JOBS="${2:?}"
      shift 2
      ;;
    --sync)
      DO_SYNC=1
      shift
      ;;
    --image)
      IMAGE="${2:?}"
      shift 2
      ;;
    --build-image)
      BUILD_IMAGE=1
      shift
      ;;
    --proxy)
      PROXY="${2:?}"
      shift 2
      ;;
    --http-proxy)
      HTTP_PROXY_ARG="${2:?}"
      shift 2
      ;;
    --https-proxy)
      HTTPS_PROXY_ARG="${2:?}"
      shift 2
      ;;
    --all-proxy)
      ALL_PROXY_ARG="${2:?}"
      shift 2
      ;;
    --no-proxy)
      NO_PROXY_ARG="${2:?}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ -n "${PROXY}" ]]; then
  HTTP_PROXY_ARG="${PROXY}"
  HTTPS_PROXY_ARG="${PROXY}"
fi

case "$ARCH" in
  amd64|x64|x86_64)
    PLATFORM="linux/amd64"
    IMAGE="${IMAGE:-asapp-linux-build:glibc228-amd64}"
    MATRIX_CMD=("./scripts/build_linux_x64_matrix.sh" "--jobs" "${JOBS}")
    ;;
  arm64|aarch64)
    PLATFORM="linux/arm64"
    IMAGE="${IMAGE:-asapp-linux-build:glibc228-arm64}"
    MATRIX_CMD=("./scripts/build_linux_arm64_matrix.sh" "--jobs" "${JOBS}")
    ;;
  *)
    echo "ERROR: 不支持的 --arch=${ARCH}（仅 amd64|arm64）" >&2
    exit 2
    ;;
esac

if [[ "${DO_SYNC}" -eq 1 ]]; then
  MATRIX_CMD+=("--sync")
fi
if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  MATRIX_CMD+=("${EXTRA_ARGS[@]}")
fi

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  if [[ "${BUILD_IMAGE}" -eq 1 ]]; then
    BUILD_IMG_ARGS=(--arch "${ARCH}" --image "${IMAGE}")
    if [[ -n "${PROXY}" ]]; then
      BUILD_IMG_ARGS+=(--proxy "${PROXY}")
    else
      [[ -n "${HTTP_PROXY_ARG}" ]] && BUILD_IMG_ARGS+=(--http-proxy "${HTTP_PROXY_ARG}")
      [[ -n "${HTTPS_PROXY_ARG}" ]] && BUILD_IMG_ARGS+=(--https-proxy "${HTTPS_PROXY_ARG}")
      [[ -n "${ALL_PROXY_ARG}" ]] && BUILD_IMG_ARGS+=(--all-proxy "${ALL_PROXY_ARG}")
    fi
    [[ -n "${NO_PROXY_ARG}" ]] && BUILD_IMG_ARGS+=(--no-proxy "${NO_PROXY_ARG}")
    echo "==> 构建镜像 ${IMAGE} (${PLATFORM})"
    "${REPO_ROOT}/docker/build_linux_image.sh" "${BUILD_IMG_ARGS[@]}"
  else
    echo "ERROR: 镜像不存在: ${IMAGE}" >&2
    echo "请先执行：" >&2
    echo "  ./docker/build_linux_image.sh --arch ${ARCH} --proxy http://127.0.0.1:7890" >&2
    echo "或对本脚本加 --build-image --proxy ..." >&2
    exit 1
  fi
fi

RUN_ENV=(
  -e ASAPP_PREBUILT_ROOT=/work/src/prebuilt
  -e HOME=/tmp
)
# 容器内若还需访问 GitHub（子模块/补丁），把代理传进去
[[ -n "${HTTP_PROXY_ARG}" ]] && RUN_ENV+=(-e "HTTP_PROXY=${HTTP_PROXY_ARG}" -e "http_proxy=${HTTP_PROXY_ARG}")
[[ -n "${HTTPS_PROXY_ARG}" ]] && RUN_ENV+=(-e "HTTPS_PROXY=${HTTPS_PROXY_ARG}" -e "https_proxy=${HTTPS_PROXY_ARG}")
[[ -n "${ALL_PROXY_ARG}" ]] && RUN_ENV+=(-e "ALL_PROXY=${ALL_PROXY_ARG}" -e "all_proxy=${ALL_PROXY_ARG}")
[[ -n "${NO_PROXY_ARG}" ]] && RUN_ENV+=(-e "NO_PROXY=${NO_PROXY_ARG}" -e "no_proxy=${NO_PROXY_ARG}")

UID_GID="$(id -u):$(id -g)"
echo "==> docker run ${IMAGE} (${PLATFORM})"
echo "==> repo: ${REPO_ROOT}"
echo "==> cmd:  ${MATRIX_CMD[*]}"

docker run --rm -it \
  --platform "${PLATFORM}" \
  --user "${UID_GID}" \
  -v "${REPO_ROOT}:/work/src:rw" \
  -w /work/src \
  "${RUN_ENV[@]}" \
  "${IMAGE}" \
  bash -lc "${MATRIX_CMD[*]}"
