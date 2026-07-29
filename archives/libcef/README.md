# archives/libcef — 受控归档索引

官方 CEF **binary distribution**（非源码重编）。大体积 `.tar.bz2` 仅本地保留，**不入库**（见根 `.gitignore`）。

## 版本

`102.0.10+gf249b2e+chromium-102.0.5005.115`

## 当前归档（本机）

| 架构 | archive_filename | archive_sha256 | 约大小 |
|------|------------------|----------------|--------|
| linux64 | `cef_binary_102.0.10+gf249b2e+chromium-102.0.5005.115_linux64.tar.bz2` | `4433ceeb2dcf16e9c1bb94375197c612034ae6825243d9d2b5dc790eed472161` | ~680 MB |
| linuxarm64 | `cef_binary_102.0.10+gf249b2e+chromium-102.0.5005.115_linuxarm64.tar.bz2` | `853e7fe4c589ac4e7b5c258d350d4295bb9ede2c6b267556f28b13e535794302` | ~716 MB |

- **官方索引**：https://cef-builds.spotifycdn.com/index.html#102.0.10+gf249b2e+chromium-102.0.5005.115
- **intake_time**：2026-07-24
- **storage_location**：本目录（或企业制品库同名对象 + 上表 SHA-256）

Windows 官方包历史上多在业务仓 / 本机 `sources/libcef/src/` 落位；本目录当前以 **Linux x64 / arm64** 归档为主。

## 解压策略

- **Windows 开发机：不必解压 Linux 包。** `.so` / 资源无法在本机链接或冒烟；保留归档即可。
- **在目标 Linux（x64 或 arm64）上再解压并打包切片**，避免无意义占用磁盘与误提交。

```bash
# 在对应架构的 Linux 上执行示例
mkdir -p sources/libcef/src
tar -xjf archives/libcef/cef_binary_*_linux64.tar.bz2 -C sources/libcef/src
# arm64 主机同理使用 *_linuxarm64.tar.bz2
```

解压目标：

```text
sources/libcef/src/cef_binary_*_linux64/
sources/libcef/src/cef_binary_*_linuxarm64/
```

关键标记：目录内存在 `include/cef_app.h`。

## 制品切片（Linux）

产出权威切片（与 Windows 一致，仅 shared-release）：

- `linux-x64-shared-release/libcef`
- `linux-arm64-shared-release/libcef`

打包脚本：`scripts/package_libcef_linux.sh`（对齐 `package_libcef_windows.ps1`）。  
也可由矩阵脚本自动调用（`--skip-libcef` 可跳过）。完成后 `sync` 进 prebuilt 并打制品 `deps-*` tag。详见 `sources/libcef/README.md`。
