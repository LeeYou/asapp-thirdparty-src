#!/usr/bin/env bash
# 构建 asapp-linux-build:glibc228-{amd64|arm64}，支持传入 HTTP(S) 代理（拉 GitHub 等）。
#
# 用法示例：
#   ./docker/build_linux_image.sh --arch amd64 --proxy http://127.0.0.1:7890
#   ./docker/build_linux_image.sh --arch amd64 \
#       --http-proxy http://127.0.0.1:7890 --https-proxy http://127.0.0.1:7890
#   HTTP_PROXY=http://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890 \
#       ./docker/build_linux_image.sh --arch arm64
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ARCH="amd64"
IMAGE=""
PROXY=""
HTTP_PROXY_ARG="${HTTP_PROXY:-${http_proxy:-}}"
HTTPS_PROXY_ARG="${HTTPS_PROXY:-${https_proxy:-}}"
ALL_PROXY_ARG="${ALL_PROXY:-${all_proxy:-}}"
NO_PROXY_ARG="${NO_PROXY:-${no_proxy:-localhost,127.0.0.1}}"

usage() {
  cat <<'EOF'
用法: build_linux_image.sh [选项]

  --arch amd64|arm64     目标架构（默认 amd64）
  --image NAME           镜像名（默认 asapp-linux-build:glibc228-<arch>）
  --proxy URL            同时设置 HTTP_PROXY 与 HTTPS_PROXY（及小写形式）
  --http-proxy URL       仅设置 HTTP 代理
  --https-proxy URL      仅设置 HTTPS 代理
  --all-proxy URL        socks 等（可选）
  --no-proxy LIST        NO_PROXY（默认 localhost,127.0.0.1）
  -h, --help             帮助

也可用环境变量：HTTP_PROXY / HTTPS_PROXY / ALL_PROXY / NO_PROXY（及小写）。
拉取基础镜像 debian:10 若失败，请同时配置 Docker 守护进程代理或宿主机代理。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      ARCH="${2:?}"
      shift 2
      ;;
    --image)
      IMAGE="${2:?}"
      shift 2
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
      echo "ERROR: unknown arg: $1" >&2
      usage >&2
      exit 2
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
    ;;
  arm64|aarch64)
    PLATFORM="linux/arm64"
    IMAGE="${IMAGE:-asapp-linux-build:glibc228-arm64}"
    ;;
  *)
    echo "ERROR: 不支持的 --arch=${ARCH}" >&2
    exit 2
    ;;
esac

BUILD_ARGS=(
  --platform "${PLATFORM}"
  -f "${REPO_ROOT}/docker/Dockerfile.linux-glibc228"
  -t "${IMAGE}"
  --load
)

append_proxy_arg() {
  local key="$1"
  local val="$2"
  if [[ -n "${val}" ]]; then
    BUILD_ARGS+=(--build-arg "${key}=${val}")
  fi
}

# 大小写都传，兼容 apt/curl/wget
append_proxy_arg HTTP_PROXY "${HTTP_PROXY_ARG}"
append_proxy_arg HTTPS_PROXY "${HTTPS_PROXY_ARG}"
append_proxy_arg ALL_PROXY "${ALL_PROXY_ARG}"
append_proxy_arg NO_PROXY "${NO_PROXY_ARG}"
append_proxy_arg http_proxy "${HTTP_PROXY_ARG}"
append_proxy_arg https_proxy "${HTTPS_PROXY_ARG}"
append_proxy_arg all_proxy "${ALL_PROXY_ARG}"
append_proxy_arg no_proxy "${NO_PROXY_ARG}"

if [[ -n "${HTTP_PROXY_ARG}${HTTPS_PROXY_ARG}${ALL_PROXY_ARG}" ]]; then
  echo "==> 使用代理构建（值不完整打印以免泄露）：HTTP/HTTPS/ALL 已设置"
  echo "    NO_PROXY=${NO_PROXY_ARG}"
else
  echo "==> 未设置代理（直连）；若 curl GitHub 失败请加 --proxy"
fi

echo "==> docker buildx build → ${IMAGE} (${PLATFORM})"

# 代理指向宿主机 127.0.0.1 时，构建容器内访问不到；尽量补 host.docker.internal
EXTRA_HOST_ARGS=()
if [[ "${HTTP_PROXY_ARG}${HTTPS_PROXY_ARG}" == *127.0.0.1* ]] || [[ "${HTTP_PROXY_ARG}${HTTPS_PROXY_ARG}" == *localhost* ]]; then
  echo "==> 警告: 代理含 127.0.0.1/localhost，构建容器内通常不可达。"
  echo "    建议改为 host.docker.internal 或宿主机局域网 IP；已尝试添加 --add-host=host.docker.internal:host-gateway"
  EXTRA_HOST_ARGS+=(--add-host=host.docker.internal:host-gateway)
fi

docker buildx build "${EXTRA_HOST_ARGS[@]}" "${BUILD_ARGS[@]}" "${REPO_ROOT}"
echo "==> 完成: ${IMAGE}"
