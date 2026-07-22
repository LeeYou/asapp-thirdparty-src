# libcef（CEF）

官方 Chromium Embedded Framework **binary distribution**（非源码重编）。

## 版本

`102.0.10+gf249b2e+chromium-102.0.5005.115`（windows64 / windows32）

## 本地布局

大体积树默认不入库（见仓库 `.gitignore`）。开发机可从 AsApp 既有纳管树引用，或解压到：

```text
sources/libcef/src/cef_binary_*_windows64/
```

## 打包制品

```powershell
pwsh -File scripts/package_libcef_windows.ps1 `
  -DestRoot dist/windows-x64-shared-release/libcef
pwsh -File scripts/sync_to_prebuilt.ps1 -Slice windows-x64-shared-release
```

产出切片：`windows-x64-shared-release/libcef`（shared 运行时 + import lib + wrapper 源）。
