# libcef（CEF）

官方 Chromium Embedded Framework **binary distribution**（非源码重编）。

## 版本

`102.0.10+gf249b2e+chromium-102.0.5005.115`

| 平台 | 官方包后缀 | 归档索引 |
|------|------------|----------|
| Windows x86 | `windows32` | 本地 `sources/libcef/src/`（历史落位） |
| Windows x64 | `windows64` | 本地 `sources/libcef/src/`（历史落位） |
| Linux x64 | `linux64` | `archives/libcef/README.md` |
| Linux arm64 | `linuxarm64` | `archives/libcef/README.md` |

## 本地布局

大体积树默认不入库（见仓库 `.gitignore` 中 `sources/libcef/src/`）。

```text
sources/libcef/src/cef_binary_*_windows32/
sources/libcef/src/cef_binary_*_windows64/
sources/libcef/src/cef_binary_*_linux64/      # 仅在 Linux x64 主机解压
sources/libcef/src/cef_binary_*_linuxarm64/  # 仅在 Linux arm64 主机解压
```

或设置环境变量 `ASAPP_CEF_BUNDLE` 指向含 `include/cef_app.h` 的包根。

**注意：** 在 Windows 上**无需**解压 Linux 官方包；归档放在 `archives/libcef/` 即可。解压与切片打包在对应 Linux 环境进行。

## 打包制品（Windows）

```powershell
pwsh -File scripts/package_libcef_windows.ps1 `
  -Arch x86 `
  -DestRoot dist/windows-x86-shared-release/libcef
# 可选：-BundleRoot <cef_binary_..._windows32>
pwsh -File scripts/sync_to_prebuilt.ps1 -Slice windows-x86-shared-release
```

主交付切片：`windows-x86-shared-release/libcef`（任意业务 linkage/config 由 AsApp 自动回落）。

## 打包制品（Linux，待脚本落地）

在 **Linux** 主机解压对应架构包后：

```bash
# 规划接口（对齐 Windows 脚本语义）
./scripts/package_libcef_linux.sh --arch x64 \
  --dest-root dist/linux-x64-shared-release/libcef
# arm64：--arch arm64 → linux-arm64-shared-release/libcef
./scripts/sync_to_prebuilt.sh --slice linux-x64-shared-release   # 名称以仓库现有 sync 脚本为准
```

权威切片：

- `linux-x64-shared-release/libcef`
- `linux-arm64-shared-release/libcef`
