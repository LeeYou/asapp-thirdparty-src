# 构建入口（源码仓）

> 切片名：`{os}-{arch}-{linkage}-{config}`  
> 权威矩阵：AsApp `docs/enterprisev3.0/third_party/09-主交付编译矩阵.md`  
> 目录前缀职责：AsApp `docs/enterprisev3.0/third_party/03-制品目录与命名规格.md` **§3.6**  
> **新增库逐步操作：** AsApp `docs/enterprisev3.0/third_party/10-新增第三方库操作手册.md`

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

特殊包：`build_openssl_windows.ps1` / `build_grpc_windows.ps1` / `package_libcef_windows.ps1`

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

## Linux x64 四组合

默认覆盖：`nlohmann_json,stb,spdlog,boost,sqlite,gtest`（CMake）+ `openssl` + `libffi` + `grpc`。  
**尚未**：`libcef`（无 Linux 官方 binary 打包入口）。

依赖工具：`cmake`、`ninja`、`clang`/`gcc`、`perl`、`make`；libffi 需上游 `configure`。

```bash
chmod +x scripts/*.sh
./scripts/build_linux_x64_matrix.sh --jobs 16
# 同步到嵌套子模块：
./scripts/build_linux_x64_matrix.sh --sync
# 或：
ASAPP_PREBUILT_ROOT="$(pwd)/prebuilt" ./scripts/build_linux_x64_matrix.sh --sync

# 仅 CMake 包（跳过 openssl/libffi/grpc）：
./scripts/build_linux_x64_matrix.sh --skip-openssl --skip-libffi --skip-grpc --jobs 16
```

单切片 / 单包：

```bash
./scripts/build.sh --arch x64 --linkage static --config release \
  --packages nlohmann_json,stb,sqlite,gtest --jobs 16

./scripts/build_openssl_linux.sh --linkage static --config release --jobs 16
./scripts/build_libffi_linux.sh --linkage static --config release --jobs 8
./scripts/build_grpc_linux.sh --linkage static --config release --jobs 16
```

## 扩展新库

1. 源码仓：`cmake/packages/<pkg>.cmake` 或专用脚本（见 `cmake/packages/README.md`）  
2. 矩阵编包装入 `./prebuilt` → 制品打 `deps-*` → 本仓提交 submodule 指针  
3. AsApp：bump `third_party/prebuilt` + `asapp_ensure_*` + 重配编译  

完整检查清单见 AsApp 专项文档 **`10-新增第三方库操作手册.md`**。
