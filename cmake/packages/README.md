# cmake/packages — 包级 recipe（工业级扩展点）

每个第三方包对应一个 `\<pkg\>.cmake`，由超级构建 `cmake/CMakeLists.txt` 按
`-DASAPP_DEP_PACKAGES=<pkg>` 加载。

## 契约

1. 读取全局选项：`ASAPP_DEP_OS/ARCH/LINKAGE/CONFIG`（`AsAppDepOptions.cmake`）
2. 源码根：`ASAPP_DEP_SOURCE_ROOT/<pkg>/...`
3. 产出：`install()` 到 `CMAKE_INSTALL_PREFIX`，布局符合制品规格 `03`：
   - `include/`、`lib/`、可选 `bin/`
   - `lib/cmake/<Name>/*Config.cmake`（imported / exported targets）
   - `PACKAGE_META.yaml`（name/version/kind/windows_min_os/toolchain）
4. Windows 必须尊重 Win7 宏（全局已注入 `0x0601`）
5. 禁止在 recipe 内写死仅 x64；新架构用 `ASAPP_DEP_ARCH` 分支

## 特殊包（脚本入口，非本目录 recipe）

| 包 | 入口 |
|----|------|
| openssl | Windows：`scripts/build_openssl_windows.ps1`；Linux：`scripts/build_openssl_linux.sh` |
| grpc | Windows：`scripts/build_grpc_windows.ps1`；Linux：`scripts/build_grpc_linux.sh` |
| libffi | Windows：`cmake/packages/libffi.cmake`；Linux：`scripts/build_libffi_linux.sh`（autotools） |
| libcef | `scripts/package_libcef_windows.ps1`（官方 binary stage；Linux 待办） |
| boost / spdlog / nlohmann / stb | Windows 可用 header 脚本；POSIX 走本目录 CMake recipe |

## 矩阵入口

| 平台 | 脚本 |
|------|------|
| Windows x86 四组合 | `scripts/build_windows_x86_matrix.ps1` |
| Linux x64 四组合 | `scripts/build_linux_x64_matrix.sh` |

详见 `docs/BUILD.md`。

## 新增库步骤

1. `sources/<pkg>/` + `archives/<pkg>/README.md`（及可选归档）
2. 新增 `cmake/packages/<pkg>.cmake` 或专用 `scripts/build_<pkg>_*.ps1`
3. 挂到 `scripts/build.ps1` / 矩阵脚本的包列表
4. 更新 `manifests/dependencies.yaml` 与制品 `MANIFEST.yaml`
