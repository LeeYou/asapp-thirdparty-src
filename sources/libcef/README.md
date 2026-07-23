# libcef（CEF）

官方 Chromium Embedded Framework **binary distribution**（非源码重编）。

## 版本

`102.0.10+gf249b2e+chromium-102.0.5005.115`（windows64 / windows32）

## 本地布局

大体积树默认不入库（见仓库 `.gitignore`）。解压到：

```text
sources/libcef/src/cef_binary_*_windows32/
sources/libcef/src/cef_binary_*_windows64/
```

或设置环境变量 `ASAPP_CEF_BUNDLE` 指向含 `include/cef_app.h` 的包根。

## 打包制品

```powershell
pwsh -File scripts/package_libcef_windows.ps1 `
  -Arch x86 `
  -DestRoot dist/windows-x86-shared-release/libcef
# 可选：-BundleRoot <cef_binary_..._windows32>
pwsh -File scripts/sync_to_prebuilt.ps1 -Slice windows-x86-shared-release
```

主交付切片：`windows-x86-shared-release/libcef`（任意业务 linkage/config 由 AsApp 自动回落）。
