# Docker 构建 Linux 制品（国产系统兼容）

> 适用仓库：`asapp-thirdparty-src`（第三方）+ 后续 AsApp 业务仓  
> 部署目标：**统信 UOS 1050/1070**、**银河麒麟 2203/2403** 等，**x64 + arm64**  
> 工具链权威：AsApp `docs/enterprisev3.0/third_party/12` + 本仓 `TOOLCHAINS.md`

---

## 1. 一句话结论

| 问题 | 答案（无歧义） |
|------|----------------|
| Docker 基础镜像选哪个？ | **正式：`debian:10`（buster，glibc 2.28）** |
| 为何不选 Ubuntu 20.04？ | 20.04 为 **glibc 2.31**，在 UOS 1050 / 多数麒麟 V10（glibc **2.28**）上会报 `GLIBC_2.29+ not found` |
| Ubuntu 18.04 行不行？ | glibc 2.27 **偏旧可用**，但默认 GCC7 缺 `<filesystem>`，工具链折腾多；**不作为正式镜像** |
| 如何同时覆盖 x64 / arm64？ | **同一套 Debian 10 配方**，用 `docker buildx` 分别打 `linux/amd64` 与 `linux/arm64` 镜像后进容器编对应切片 |

**硬原则（Linux 二进制）：在「目标里最老的 glibc」上编，才能在更新的系统上跑；反过来不行。**

---

## 2. 目标系统与 glibc 基线（构建侧必须对齐）

| 部署目标（示例） | 常见基线 | 实测/公开信息中的 glibc |
|------------------|----------|-------------------------|
| 统信 UOS 桌面 20 · **1050** | Debian 10 系 | **2.28** |
| 统信 UOS 桌面 20 · **1070** | Debian 10 系（deepin 派生） | **2.28**（如 `Debian GLIBC 2.28.x-deepin`） |
| 银河麒麟 V10 · **2203 / 2403**（服务器常见） | 自有仓库 | 多款为 **glibc 2.28**（如 `glibc-2.28-*.ky10`） |
| 部分麒麟桌面 / 更新变体 | Debian 11 系 | 可能到 **2.31**（更高，兼容向下构建的产物） |

### 2.1 候选基础镜像对比

| 基础镜像 | glibc | 相对国产目标 | 结论 |
|----------|-------|--------------|------|
| **debian:10 / buster** | **2.28** | 与 UOS 1050/1070、麒麟 2.28 **对齐** | **正式选定** |
| ubuntu:18.04 | 2.27 | 可跑在 2.28+ 上，但 GCC7 / 旧包多 | 仅应急，不推荐 |
| ubuntu:20.04 | 2.31 | **高于** 多款国产 2.28 | **禁止**作为「通吃 1050/麒麟2.28」的正式构建根 |
| debian:11 / ubuntu:22.04 | 2.31 / 2.35 | 更新 | **禁止**（除非产品明确放弃 2.28 目标机） |

> 验收口诀：构建机 `ldd --version` 显示的 glibc **≤** 每一台目标机的 glibc。

### 2.2 除 glibc 外还要注意

| 项 | 要求 |
|----|------|
| C++ 标准库 | Clang 挂 **GCC ≥ 8** 的 libstdc++（提供 `<filesystem>`）；Debian 10 默认即 GCC 8.3，适合 |
| CMake / Ninja / Clang | CMake ≥ 3.24；Ninja ≥ 1.11；Clang ≥ 15（镜像内用官方二进制 / LLVM 源安装，勿依赖 buster 仓库里的过旧 cmake） |
| 链接形态 | 默认优先 **static 切片** 降低目标机缺 `.so` 的风险；shared 切片须在目标机做 `ldd` 验收 |
| 禁止 | 在 Ubuntu 20.04+/22.04 宿主机「直接编」却宣称兼容 UOS 1050；宿主机新、容器旧才正确 |

---

## 3. 切片与架构

| 架构 | 切片前缀 | 矩阵入口（当前） |
|------|----------|------------------|
| x86_64 | `linux-x64-{static\|shared}-{debug\|release}` | `./scripts/build_linux_x64_matrix.sh` |
| aarch64 | `linux-arm64-{static\|shared}-{debug\|release}` | `./scripts/build_linux_arm64_matrix.sh`；Docker：`./docker/run_linux_matrix_in_docker.sh --arch arm64` |

业务仓 AsApp preset：`linux-x64-*` / `linux-arm64-*`（见 `CMakePresets.json`）。

---

## 4. 镜像内容（`docker/Dockerfile.linux-glibc228`）

正式标签约定：

```text
asapp-linux-build:glibc228-amd64
asapp-linux-build:glibc228-arm64
```

镜像内预装：

- 构建：`clang-15`、`g++-8`（或系统 g++-8）、`ninja-build`、`cmake`（≥3.24 官方包）、`perl`、`make`、`autoconf`、`libtool`、`pkg-config`、`git`、`git-lfs`
- 校验：启动时打印 `ldd --version`、`clang++ --version`、`cmake --version`

---

## 5. 详细步骤（推荐复制执行）

### 5.1 宿主机准备

```bash
# Docker + buildx
docker version
docker buildx version

# 源码（含 submodule）
cd /path/to/asapp-thirdparty-src
git submodule update --init --recursive prebuilt
chmod +x scripts/*.sh docker/*.sh
```

### 5.2 代理（拉 GitHub / 基础镜像必看）

镜像构建会从 **GitHub** 下载 CMake、Clang 预编译包；国内环境通常需要代理。

| 场景 | 做法 |
|------|------|
| **推荐** | `./docker/build_linux_image.sh --proxy http://127.0.0.1:7890` |
| 手写 `docker buildx` | 传 `--build-arg HTTP_PROXY=...` / `HTTPS_PROXY=...`（大小写都传更稳） |
| 环境变量 | `export HTTP_PROXY=... HTTPS_PROXY=...` 后跑脚本（脚本会读入） |
| 拉 `debian:10` 失败 | 还要配 **Docker 守护进程代理**（仅 build-arg 管不了 `FROM` 拉层） |

**推荐一键（含代理）：**

```bash
# 把 7890 换成你的本地 HTTP 代理端口
export ASAPP_DOCKER_PROXY=http://127.0.0.1:7890

./docker/build_linux_image.sh --arch amd64 --proxy "$ASAPP_DOCKER_PROXY"
# 等价拆分：
# ./docker/build_linux_image.sh --arch amd64 \
#   --http-proxy "$ASAPP_DOCKER_PROXY" --https-proxy "$ASAPP_DOCKER_PROXY"
```

**手写 buildx（与脚本等价）：**

```bash
PROXY=http://127.0.0.1:7890

docker buildx build \
  --platform linux/amd64 \
  -f docker/Dockerfile.linux-glibc228 \
  -t asapp-linux-build:glibc228-amd64 \
  --build-arg HTTP_PROXY="$PROXY" \
  --build-arg HTTPS_PROXY="$PROXY" \
  --build-arg http_proxy="$PROXY" \
  --build-arg https_proxy="$PROXY" \
  --build-arg NO_PROXY=localhost,127.0.0.1 \
  --build-arg no_proxy=localhost,127.0.0.1 \
  --load \
  .
```

说明：

- Dockerfile 在装完工具链后会 **清空镜像内代理 ENV**，避免把办公代理写死进镜像。
- 容器内跑矩阵若还要访问外网，用 `run_linux_matrix_in_docker.sh --proxy ...` 再注入运行期环境变量。
- **代理地址不要用容器视角的 `127.0.0.1`（除非用 host 网络）。** 代理跑在宿主机时：
  - Docker Desktop（Windows/macOS）：常用 `http://host.docker.internal:7890`
  - Linux Docker：`http://172.17.0.1:7890`（docker0）或  
    `docker buildx build --add-host=host.docker.internal:host-gateway ...` 后用 `http://host.docker.internal:7890`
  - 也可用宿主机局域网 IP，例如 `http://192.168.x.x:7890`

### 5.3 构建构建镜像（x64）

```bash
cd /path/to/asapp-thirdparty-src

# 有代理（推荐）
./docker/build_linux_image.sh --arch amd64 --proxy http://127.0.0.1:7890

# 无代理（直连 GitHub 可用时）
./docker/build_linux_image.sh --arch amd64
```

### 5.4 构建构建镜像（arm64）

在 **arm64 机器**上原生编镜像最快；或在 x64 上用 QEMU（慢）：

```bash
# 一次性：注册 qemu（若尚未）
docker run --privileged --rm tonistiigi/binfmt --install all

./docker/build_linux_image.sh --arch arm64 --proxy http://127.0.0.1:7890
```

### 5.5 在容器内编第三方（x64 四切片）

```bash
REPO="$(pwd)"   # asapp-thirdparty-src 根
PROXY=http://127.0.0.1:7890   # 容器内若还需访问外网时传入

docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  -v "$REPO:/work/src:rw" \
  -w /work/src \
  -e ASAPP_PREBUILT_ROOT=/work/src/prebuilt \
  -e HTTP_PROXY="$PROXY" -e HTTPS_PROXY="$PROXY" \
  -e http_proxy="$PROXY" -e https_proxy="$PROXY" \
  asapp-linux-build:glibc228-amd64 \
  bash -lc './scripts/build_linux_x64_matrix.sh --jobs $(nproc) --sync'
```

一键脚本（等价，含构建镜像代理）：

```bash
./docker/run_linux_matrix_in_docker.sh \
  --arch amd64 --jobs 16 --sync --build-image \
  --proxy http://127.0.0.1:7890
```

### 5.6 arm64 切片（容器）

```bash
./docker/run_linux_matrix_in_docker.sh \
  --arch arm64 --jobs 8 --sync --build-image \
  --proxy http://127.0.0.1:7890
# 容器内等价于：./scripts/build_linux_arm64_matrix.sh --jobs 8 --sync
```

### 5.7 编完后在制品仓打 tag

```bash
cd prebuilt
git status
git add linux-x64-*   # 以及 linux-arm64-*（若已产出）
git commit -m "Add linux glibc228 slices for UOS/Kylin"
git tag deps-YYYY.MM.DD-N
git push origin HEAD
git push origin deps-YYYY.MM.DD-N
cd ..
git add prebuilt
git commit -m "Point prebuilt to deps-YYYY.MM.DD-N"
```

AsApp：`git -C third_party/prebuilt fetch --tags && git submodule update --remote`（或钉到同一 tag）后：

```bash
cmake --preset linux-x64-release
cmake --build --preset linux-x64-release
```

**业务仓同样建议在 `asapp-linux-build:glibc228-*` 容器内配置/编译**，避免宿主机新 glibc 链出不兼容二进制。

---

## 6. 兼容性验收（必须做）

在 **真实 UOS 1050 / 麒麟 2203（或同等 glibc 2.28）** 上：

```bash
ldd --version
# 对可执行文件 / .so：
ldd ./asapp_host | head
# 或只检查 glibc 符号上限：
objdump -T ./asapp_host | grep -o 'GLIBC_[0-9.]*' | sort -V | uniq | tail
```

期望：

- 无 `not found`
- 最高 `GLIBC_*` **不超过** 目标机提供的版本（对 2.28 机，不应出现 2.29+）

可选烟雾：在 Debian 10 干净容器里跑一次同产物（近似 UOS 1050 用户态）。

---

## 7. 常见错误

| 现象 | 原因 | 处理 |
|------|------|------|
| 目标机 `GLIBC_2.31 not found` | 在 Ubuntu 20.04+ 或过新镜像里编的 | 改用本文件的 **debian:10** 镜像重编 |
| `'filesystem' file not found` | libstdc++ 过旧（如裸 18.04 + GCC7） | 用本 Dockerfile（Debian10 + g++-8）；或装 g++-8 |
| `cmake version 3.10` | 系统自带 cmake | 镜像已装 ≥3.24；勿用宿主机 `/usr/bin/cmake` 进错 PATH |
| `--sync` 找不到 prebuilt | 子模块未 init 或 root 指错 | `git submodule update --init prebuilt`；`--prebuilt-root` 指向 `.../prebuilt` |
| arm64 上 OpenSSL Configure 失败 | 仍用 `linux-x86_64` 目标 | 更新后的 `build_openssl_linux.sh` 按 `uname -m` 选择 `linux-aarch64` |
| `curl: (7) Failed to connect` / GitHub 超时 | 构建期未走代理 | `./docker/build_linux_image.sh --proxy http://host:port` |
| `FROM debian:10-slim` 拉失败 | 守护进程无代理 | 配置 Docker Desktop / daemon `proxies`，或系统级 HTTP(S)_PROXY |

---

## 8. 与文档体系关系

| 文档 | 关系 |
|------|------|
| 本文件 | **Docker + 国产 glibc 基线** 操作权威 |
| `BUILD.md` | 通用矩阵命令；Linux 节指向本文 |
| `TOOLCHAINS.md` / AsApp `12` | 编译器版本钉死；Linux 运行基线钉 **glibc 2.28（Debian 10 构建根）** |
| AsApp `11` | 编完后如何进 AsApp preset |

---

## 9. 变更规则

1. 若产品确认「最低只支持 glibc 2.31+」，才允许把正式镜像升到 Debian 11 / Ubuntu 20.04，并 **改写本文 + `12` + 全量重编 linux 切片**。  
2. 新增国产目标机：先在目标机跑 `ldd --version`，若 **&lt; 2.28** 则需再降低构建根（极少见）。  
3. 禁止同一 `deps-*` tag 混入不同 glibc 构建根的 linux 切片。
