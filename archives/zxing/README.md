# zxing-cpp archive index

- **Name**: zxing-cpp-2.3.0 (git tag `v2.3.0`)
- **Version**: 2.3.0
- **URL**: https://github.com/zxing-cpp/zxing-cpp/archive/refs/tags/v2.3.0.zip
- **Alternate**: https://github.com/zxing-cpp/zxing-cpp/archive/refs/tags/v2.3.0.tar.gz
- **SHA-256** (zip): `89b70f6175c6347d72bdc72722d643c0f461dc8a0d9bbc4c927a240b32b706f2`
- **Governed extract path**: `sources/zxing/src/`
- **License**: Apache-2.0 → `licenses/zxing-LICENSE.txt`

## 版本选型说明

- AsApp 全仓 **C++17** 硬上限（见业务仓 third_party 权威文档 12）。
- zxing-cpp **v3.x** 默认 `CMAKE_CXX_STANDARD 20`，不可直接采用。
- **v2.3.0** 核心声明 `cxx_std_17`，读码 + OLD 写码路径不依赖 zint git 子模块。

## 配方开关（`cmake/packages/zxing.cmake`）

| 选项 | 值 | 说明 |
|------|-----|------|
| `ZXING_READERS` | ON | 解码 |
| `ZXING_WRITERS` | OLD | 旧写码后端（无 zint） |
| `ZXING_EXAMPLES` / tests / python / C-API | OFF | 生产制品关闭 |
| `ZXING_DEPENDENCIES` | LOCAL | 禁止 FetchContent 拉外网 |

构建以 `sources/zxing/src` 为准；本目录可保留 tar/zip 以便离线复核（大文件已被 `.gitignore`）。
