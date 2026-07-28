# 工具链基线 — asapp-thirdparty-src

> **权威无歧义矩阵**：AsApp `docs/enterprisev3.0/third_party/12-全平台工具链兼容矩阵.md`  
> 本文是源码仓侧摘要；与 `12` 冲突时以 `12` 为准。

## 语言标准

- **C++17 only**（第三方与业务一致；禁止以 C++20 作为默认）

## 正式组合

| OS | Generator | Compiler | 最低版本 | ABI / 运行目标 |
|----|-----------|----------|----------|----------------|
| Windows | Ninja | **clang-cl** | Clang **≥ 19** + **VS2022** MsVc STL（`VsDevCmd`） | **MSVC ABI**；`_WIN32_WINNT=0x0601`（Win7 SP1+） |
| Linux | Ninja | clang / clang++ | Clang **≥ 15**；libstdc++ 须提供 `<filesystem>`（**GCC ≥ 8**） | elf-sysv；**正式构建根 Debian 10 / glibc 2.28**（兼容 UOS 1050/1070、麒麟 2203/2403）；见 `docs/DOCKER_LINUX_BUILD.md`；**禁止**用 Ubuntu 20.04+ 作为通吃国产 2.28 的默认构建根 |
| macOS | Ninja | Apple Clang 或 LLVM Clang | AppleClang **≥ 14** 或 Clang **≥ 15** | mach-o；deployment target 显式钉死 |

## Windows 例外（仍须 VS2022，写入 PACKAGE_META）

| 包 | 驱动 | 说明 |
|----|------|------|
| OpenSSL | nmake/jom + MSVC | 官方 Windows 路径 |
| gRPC | Ninja + MSVC `cl`，C++17 | 可靠性例外；SSL 用已产出 OpenSSL |
| libcef | 官方预编译 | 只消费 MSVC ABI |

## CMake toolchain 文件

| 文件 | 用途 |
|------|------|
| `cmake/toolchains/windows-clang-cl.cmake` | Windows 正式 |
| `cmake/toolchains/linux-clang.cmake` | Linux 正式 |
| `cmake/toolchains/macos-clang.cmake` | macOS 正式 |

## 公共版本下限

- CMake ≥ **3.24**
- Ninja ≥ **1.11**
- Windows 宿主：**仅 Visual Studio 2022**（脚本只解析 2022 `VsDevCmd`）

## 明确禁止

| 禁止 | 原因 |
|------|------|
| VS2017 / VS2019 编默认 `windows-*` 切片 | 与 v143 CRT/STL 及当前业务门禁不兼容 |
| MinGW ABI 写入默认 Windows 切片 | 与 MSVC/CEF/gRPC 冲突 |
| 开发者本机随意换 toolset 后覆盖 `prebuilt` | 破坏 `deps-*` 可复现性 |
| 在 glibc ≥ 2.31 环境编 Linux 切片却声称兼容 UOS 1050 / 麒麟 2.28 | 目标机 `GLIBC_2.29+ not found` |

## 应急通道

允许短期使用 **VS2022** 的 MSVC `cl` + Ninja，但必须在包 `PACKAGE_META` / 发布说明中标注；不得作为新包默认路径（OpenSSL/gRPC 已登记例外除外）。  
**禁止** 将 MinGW ABI 产物写入默认 Windows 切片。
