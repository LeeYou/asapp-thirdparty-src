# 构建入口（源码仓）

> **工具链权威（无歧义）：** AsApp `docs/enterprisev3.0/third_party/12-全平台工具链兼容矩阵.md` + 本仓 `TOOLCHAINS.md`（C++17；Windows 仅 VS2022；禁止 VS2017/2019 混链）  
> 切片名：`{os}-{arch}-{linkage}-{config}`  
> 权威矩阵：AsApp `docs/enterprisev3.0/third_party/09-主交付编译矩阵.md`  
> 目录前缀职责：AsApp `docs/enterprisev3.0/third_party/03-制品目录与命名规格.md` **§3.6**  
> **新增库逐步操作：** AsApp `docs/enterprisev3.0/third_party/10-新增第三方库操作手册.md`  
> **分平台编库并集成 AsApp：** AsApp `docs/enterprisev3.0/third_party/11-分平台构建与AsApp集成手册.md`

## 目录规格（与业务仓对齐切片、区分前缀）

| 路径 | 用途 |
|------|------|
| `build/<slice>/<pkg>/` | 临时 CMake/Ninja 构建树（可删） |
| `dist/<slice>/<pkg>/` | 安装暂存；矩阵 `-SyncToPrebuilt` 的源 |
| `prebuilt/<slice>/<pkg>/` | 嵌套制品子模块（正式交付布局，**裸切片**） |

`<slice>` = `{os}-{arch}-{linkage}-{config}`，例：`windows-x86-static-debug`。

**不要**把本仓路径写成 AsApp 那种扁平 `build-windows-x86-static-debug`——那是**业务整仓**输出树；本仓是**按包**构建，必须用 `build/<slice>/<pkg>`。

## 工作区：嵌套制品子模块（推荐）

本仓通过 git submodule 挂载制品仓：

```text
asapp-thirdparty-src/
└── prebuilt/          # → https://github.com/LeeYou/asapp-thirdparty-prebuilt.git
```

```powershell
git submodule update --init --recursive prebuilt
```

**日常新增/升级库只需在本仓操作：** 编译 → `-SyncToPrebuilt` 写入 `./prebuilt` → 进入 `prebuilt/` commit + 打 `deps-*` tag → 回到本仓提交 submodule 指针。  
AsApp 再 bump 其 `third_party/prebuilt` 到同一 tag。

| 对象 | 结论 |
|------|------|
| GitHub `asapp-thirdparty-prebuilt` **远程** | **必须保留**（本仓与 AsApp 共同消费） |
| 本机再单独 clone 一份制品仓 | **不必须**；优先用本仓 `prebuilt/` |

## 环境变量（禁止硬编码业务仓路径）

| 变量 | 用途 |
|------|------|
| `ASAPP_PREBUILT_ROOT` | 制品工作树；**默认可用本仓 `./prebuilt`**（`-SyncToPrebuilt` 时） |
| `ASAPP_BOOST_SRC` | Boost 头树根（含 `boost/asio.hpp`） |
| `ASAPP_CEF_BUNDLE` | CEF 官方 binary 根（含 `include/cef_app.h`） |
| `ASAPP_LEGACY_STAGED` | 仅 `import_legacy_windows_x86.ps1` 用 |

未设置 `ASAPP_PREBUILT_ROOT` 时，矩阵脚本按顺序尝试：本仓 `prebuilt/` → 同级目录 `asapp-thirdparty-prebuilt`。

## Windows x86 四组合（主交付）

```powershell
# 推荐：产物同步进嵌套子模块 ./prebuilt
.\scripts\build_windows_x86_matrix.ps1 -SyncToPrebuilt -Jobs 26

# 显式指定（仅当不用嵌套子模块时）
.\scripts\build_windows_x86_matrix.ps1 -PrebuiltRoot D:\asapp-thirdparty-prebuilt -SyncToPrebuilt
```

单包：`.\scripts\build.ps1 -Arch x86 -Linkage static -Config debug -Packages sqlite,gtest`

OpenCV 4.5.5（需先有归档）：

- **切片**：正式交付 / SyncToPrebuilt / deps-\* **仅** `*-shared-release`（Win/Linux 相同）
- **库形态**：**强制 STATIC**（配方覆盖；无 `opencv_*.dll` / `libopencv_*.so`）——供私有图像 facade 静态链入，避免与其它第三方 OpenCV 冲突
- **布局**：`include/` + `lib/`（Windows 覆盖上游 `staticlib/`）；`find_package(OpenCV)` 用 `CMAKE_PREFIX_PATH=<slice>/opencv`
- 勿把「切片 shared」理解成「OpenCV 动态库」；二者已解耦

```powershell
.\scripts\extract_archive.ps1 -Package opencv
# 交付：切片必须 shared+release（勿用 build.ps1 默认 Linkage=static → 错切片名）
.\scripts\build.ps1 -Arch x86 -Linkage shared -Config release -Packages opencv
# 矩阵默认只在 shared-release 编 opencv；其它切片须 -IncludeOpencvNonShip
# SyncToPrebuilt 对非 ship 切片会剔除 opencv（除非 -AllowOpencvNonShip）
```

特殊包：`build_openssl_windows.ps1` / `build_grpc_windows.ps1` / `package_libcef_windows.ps1`  
Linux 对应：`build_openssl_linux.sh` / `build_grpc_linux.sh` / `package_libcef_linux.sh`

### 发布制品 tag（在 prebuilt/ 内）

```powershell
cd prebuilt
git add -A
git commit -m "Update windows-x86 slices"
git tag deps-YYYY.MM.DD-N
git push origin HEAD
git push origin deps-YYYY.MM.DD-N
# 大文件按需：git lfs push origin --all
cd ..
git add prebuilt
git commit -m "Point prebuilt submodule to deps-YYYY.MM.DD-N"
git push
```

## Linux（国产兼容：UOS / 麒麟，x64 + arm64）

默认覆盖：`nlohmann_json,stb,spdlog,boost,sqlite,gtest`（CMake）+ `openssl` + `libffi` + `grpc` + `libcef`。  
`libcef` 为官方 binary 打包（`package_libcef_linux.sh`），仅写入 `linux-{x64|arm64}-shared-release`；无归档时可 `--skip-libcef`。

依赖工具：`cmake`≥3.24、`ninja`、`clang`/`clang++`≥15、`perl`、`make`；libffi 需上游 `configure`；libstdc++ 须提供 `<filesystem>`（**GCC ≥ 8**）。

### 正式路径：Docker（Debian 10 / glibc 2.28）

部署目标含 **统信 UOS 1050/1070**、**银河麒麟 2203/2403** 等时，**禁止**用 Ubuntu 20.04+（glibc 2.31）当默认构建根。  
正式构建根：**`debian:10`（glibc 2.28）**。

完整步骤、镜像构建、验收与排错见：

→ **[`docs/DOCKER_LINUX_BUILD.md`](DOCKER_LINUX_BUILD.md)**

快捷入口：

```bash
chmod +x scripts/*.sh docker/*.sh
git submodule update --init --recursive prebuilt

# 国内需代理拉 GitHub：把端口改成你的本地代理
PROXY=http://127.0.0.1:7890

# 仅构建镜像
./docker/build_linux_image.sh --arch amd64 --proxy "$PROXY"

# 构建镜像 + 跑 x64 四切片
./docker/run_linux_matrix_in_docker.sh --arch amd64 --jobs 16 --sync --build-image --proxy "$PROXY"

# arm64（需 arm64 机或 QEMU）
./docker/run_linux_matrix_in_docker.sh --arch arm64 --jobs 8 --sync --build-image --proxy "$PROXY"
```

### 增量编译（默认）

脚本**默认增量**：若 `dist/<slice>/<pkg>/PACKAGE_META.yaml` 已存在则 **SKIP**，不会重编 OpenSSL/gRPC 等。  
失败重跑可直接再执行矩阵，已完成的包会跳过。

- 强制全量重编：矩阵加 `--clean`，或 `ASAPP_DEP_CLEAN=1`
- CMake 包：未 `--clean` 且已有 `build.ninja` 时保留构建树做 ninja 增量

```bash
# 接着上次失败继续（推荐）
./scripts/build_linux_x64_matrix.sh --jobs 16 --sync

# 全量重来
./scripts/build_linux_x64_matrix.sh --jobs 16 --sync --clean
```

### 并行编译

- `--jobs N`：传给 **ninja/make 的 `-jN`**（gRPC 等大包主要靠这个）
- 同切片内：CMake 小包可包级并发（`ASAPP_DEP_PKG_PARALLEL`，默认约 `jobs/4`，上限 4）；`openssl` 与 `libffi` 并行；`grpc` 仍在 openssl 之后
- 若日志里看不到 `running: ninja ... -j16`，说明脚本未更新到含 `AsAppDepBuildParallel.sh` 的版本

### 裸机 / 非 Docker（仅排障）

若必须在宿主机直接编：宿主 glibc **不得高于** 最低目标机（建议宿主或 chroot 也是 **Debian 10 / glibc 2.28**）。  
Ubuntu 18.04 默认 **GCC 7** 无 `<filesystem>`，须装 **g++-8+**：

```bash
apt-get update && apt-get install -y g++-8
rm -rf build/linux-x64-* dist/linux-x64-*
./scripts/build_linux_x64_matrix.sh --jobs 16 --sync
```

`cmake/toolchains/linux-clang.cmake` 会自动探测 `/usr/lib/gcc/*/8..13` 并让 Clang 使用对应 libstdc++。

```bash
chmod +x scripts/*.sh
git submodule update --init --recursive prebuilt

./scripts/build_linux_x64_matrix.sh --jobs 16
./scripts/build_linux_x64_matrix.sh --sync
./scripts/build_linux_x64_matrix.sh --sync --prebuilt-root "$(pwd)/prebuilt"
ASAPP_PREBUILT_ROOT="$(pwd)/prebuilt" ./scripts/build_linux_x64_matrix.sh --sync

# arm64 四切片：
./scripts/build_linux_arm64_matrix.sh --jobs 8 --sync

# 仅 CMake 包（跳过 openssl/libffi/grpc/libcef）：
./scripts/build_linux_x64_matrix.sh --skip-openssl --skip-libffi --skip-grpc --skip-libcef --jobs 16

# 仅打包 libcef（需 archives 或已解压的官方包）：
./scripts/package_libcef_linux.sh --arch x64 \
  --dest-root dist/linux-x64-shared-release/libcef
```

单切片 / 单包：

```bash
./scripts/build.sh --arch x64 --linkage static --config release \
  --packages nlohmann_json,stb,sqlite,gtest --jobs 16

./scripts/build_openssl_linux.sh --arch x64 --linkage static --config release --jobs 16
./scripts/build_libffi_linux.sh --arch x64 --linkage static --config release --jobs 8
./scripts/build_grpc_linux.sh --arch x64 --linkage static --config release --jobs 16

# arm64 将 --arch 改为 arm64，并在 aarch64 容器/机器上执行
```

## 扩展新库

1. 源码仓：`cmake/packages/<pkg>.cmake` 或专用脚本（见 `cmake/packages/README.md`）  
2. 矩阵编包装入 `./prebuilt` → 制品打 `deps-*` → 本仓提交 submodule 指针  
3. AsApp：bump `third_party/prebuilt` + `asapp_ensure_*` + 重配编译  

完整检查清单见 AsApp 专项文档 **`10-新增第三方库操作手册.md`**。  
Windows / Linux 从矩阵到主程序编译的复制用命令见 **`11-分平台构建与AsApp集成手册.md`**。
