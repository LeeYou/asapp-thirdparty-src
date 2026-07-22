# Boost source（header-only 消费）

- Version: **1.90.0**
- AsApp 实际消费：Boost.Asio + Boost.Beast（header-only；默认构建门控关闭）
- Phase 3.5：**不跑 b2**，只向制品仓发布整棵 `boost/` 头树（~147MB）

## Source intake

上游树放在 `sources/boost/src`（本地落库；体积约 1GB，**不提交**到本仓，见根 `.gitignore`）。

```powershell
# 示例：从官方归档展开到 src/
$Archive = "archives/boost/boost_1_90_0.zip"  # 或企业制品库路径
Expand-Archive $Archive -DestinationPath sources/boost/_tmp
# strip 一层到 src/
robocopy sources\boost\_tmp\boost_1_90_0 sources\boost\src /E /NFL /NDL /NJH /NJS
```

关键标记：`sources/boost/src/boost/asio.hpp`、`sources/boost/src/boost/beast/core.hpp`。

## 安装到制品切片

```powershell
.\scripts\sync_boost_headers.ps1 `
  -SourceRoot sources\boost\src `
  -DestRoot <prebuilt>\windows-x64-static-release\boost
```

或经 superbuild：

```powershell
.\scripts\build.ps1 -Packages boost -InstallPrefix <prebuilt-slice-root>
```

制品布局：

```
windows-x64-static-release/boost/
  include/boost/...
  lib/cmake/boost/boostConfig.cmake
  PACKAGE_META.yaml
```

Include 根为 `include/`（`#include <boost/asio.hpp>`）。
