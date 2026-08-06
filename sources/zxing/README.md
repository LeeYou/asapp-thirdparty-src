# ZXing (zxing-cpp) — 源码编译指南

C++ 条码读写库，包名 `zxing`，制品目标 `ZXing::ZXing`。

- **版本**：2.3.0（C++17；v3.x 默认 C++20，与 AsApp 硬上限冲突，勿升级）
- **上游**：https://github.com/zxing-cpp/zxing-cpp
- **许可证**：Apache-2.0 → `licenses/zxing-LICENSE.txt`

## 下载

```powershell
cd sources/zxing
# 源码放到 src/（本 README 不会被覆盖）
git clone --depth 1 -b v2.3.0 https://github.com/zxing-cpp/zxing-cpp.git src
# 或离线包（OLD writers 不需要 zint 子模块，GitHub 自动源码包可用）：
# curl -L -o zxing-cpp-2.3.0.tar.gz https://github.com/zxing-cpp/zxing-cpp/archive/refs/tags/v2.3.0.tar.gz
# mkdir src; tar -xzf zxing-cpp-2.3.0.tar.gz --strip-components=1 -C src
```

归档索引见 `archives/zxing/README.md`。

## 构建（经超级构建 recipe）

```powershell
# 单切片冒烟（Windows x86 shared-release）
.\scripts\build.ps1 -Os windows -Arch x86 -Linkage shared -Config release `
  -Packages zxing -Jobs 26

# 主交付四切片并同步 prebuilt
.\scripts\build_windows_x86_matrix.ps1 -Packages zxing -SyncToPrebuilt -Jobs 26
```

Linux：

```bash
./scripts/build.sh --os linux --arch x64 --linkage shared --config release \
  --packages zxing --jobs 16
./scripts/build_linux_x64_matrix.sh --packages zxing --sync --jobs 16
```

## 产物布局

```text
{slice}/zxing/
  include/ZXing/...
  lib/libZXing.* | ZXing.lib
  bin/ZXing.dll          # shared 时
  lib/cmake/ZXing/ZXingConfig.cmake
  PACKAGE_META.yaml
```

## AsApp 消费

```cmake
asapp_ensure_zxing()
target_link_libraries(my_target PRIVATE ZXing::ZXing)
# Windows shared：asapp_tp_copy_pkg_dlls(my_target zxing)
```
