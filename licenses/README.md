# licenses 目录说明

本目录存放 Win32 预编译依赖集所涉第三方组件的完整许可证文本，供源码仓与制品仓一并发布、合规归档。

## 包索引

| 包 | 许可证文件 |
|----|------------|
| nlohmann/json | [nlohmann-LICENSE.MIT](nlohmann-LICENSE.MIT) |
| SQLite | [sqlite-LICENSE.txt](sqlite-LICENSE.txt) |
| Google Test (gtest) | [gtest/LICENSE](gtest/LICENSE) |
| spdlog | [spdlog/LICENSE](spdlog/LICENSE) |
| OpenSSL | [openssl/LICENSE.txt](openssl/LICENSE.txt) |
| libffi | [libffi/LICENSE](libffi/LICENSE) |
| Boost | [boost/LICENSE_1_0.txt](boost/LICENSE_1_0.txt) |
| gRPC（顶层 LICENSE，不含 third_party 嵌套树） | [grpc/LICENSE](grpc/LICENSE) |
| stb | [stb/LICENSE.txt](stb/LICENSE.txt) |
| Chromium Embedded Framework (libcef) | [libcef/LICENSE.txt](libcef/LICENSE.txt) |
| zxing-cpp | [zxing-LICENSE.txt](zxing-LICENSE.txt) |
| OpenCV | [opencv-LICENSE.txt](opencv-LICENSE.txt) |

## 维护

- 文本优先从 `sources/<pkg>/src/` 对应 upstream 文件复制；libcef 来自制品切片 `windows-x86-shared-release/libcef`。
- 同步到制品仓：`scripts/sync_licenses_to_prebuilt.ps1`（robocopy 至 `asapp-thirdparty-prebuilt/licenses`）。

补充说明见各 `*-README.md`（若存在）。
