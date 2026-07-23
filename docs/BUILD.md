# 构建入口（源码仓）

> 切片名：`{os}-{arch}-{linkage}-{config}`  
> 权威矩阵：AsApp `docs/enterprisev3.0/third_party/09-主交付编译矩阵.md`

## 环境变量（禁止硬编码业务仓路径）

| 变量 | 用途 |
|------|------|
| `ASAPP_PREBUILT_ROOT` | 制品仓工作树（`sync` / 矩阵 `-SyncToPrebuilt`） |
| `ASAPP_BOOST_SRC` | Boost 头树根（含 `boost/asio.hpp`） |
| `ASAPP_CEF_BUNDLE` | CEF 官方 binary 根（含 `include/cef_app.h`） |
| `ASAPP_LEGACY_STAGED` | 仅 `import_legacy_windows_x86.ps1` 用 |

默认在本仓查找：`sources/boost/src`、`sources/libcef/src/cef_binary_*`、嵌套/同级 `prebuilt`。

## Windows x86 四组合（主交付）

```powershell
.\scripts\build_windows_x86_matrix.ps1 -SyncToPrebuilt -Jobs 26
# 或指定制品仓：
.\scripts\build_windows_x86_matrix.ps1 -PrebuiltRoot D:\asapp-thirdparty-prebuilt -SyncToPrebuilt
```

单包：`.\scripts\build.ps1 -Arch x86 -Linkage static -Config debug -Packages sqlite,gtest`

特殊包：`build_openssl_windows.ps1` / `build_grpc_windows.ps1` / `package_libcef_windows.ps1`

## Linux x64 四组合（骨架）

当前矩阵覆盖 CMake recipe 包：`nlohmann_json,stb,spdlog,boost,sqlite,gtest`。  
**尚未**：openssl / grpc / libcef（需后续 POSIX 脚本）。

```bash
chmod +x scripts/build.sh scripts/build_linux_x64_matrix.sh
./scripts/build_linux_x64_matrix.sh --jobs 16
ASAPP_PREBUILT_ROOT=/path/to/asapp-thirdparty-prebuilt ./scripts/build_linux_x64_matrix.sh --sync
```

单切片：

```bash
./scripts/build.sh --arch x64 --linkage static --config release \
  --packages nlohmann_json,stb,sqlite,gtest --jobs 16
```

## 扩展新库

见 `cmake/packages/README.md`。
