# 工具链基线 — asapp-thirdparty-src

对齐 AsApp `docs/enterprisev3.0/third_party/08`。

## 正式组合

| OS | Generator | Compiler | ABI / 备注 |
|----|-----------|----------|------------|
| Windows | Ninja | **clang-cl** | MSVC ABI；`_WIN32_WINNT=0x0601`（Win7 SP1+） |
| Linux | Ninja | clang / clang++ | 目标 glibc/sysroot |
| macOS | Ninja | Apple Clang 或 LLVM Clang | 设定 deployment target |

## CMake toolchain 文件

| 文件 | 用途 |
|------|------|
| `cmake/toolchains/windows-clang-cl.cmake` | Windows 正式 |
| `cmake/toolchains/linux-clang.cmake` | Linux 正式 |
| `cmake/toolchains/macos-clang.cmake` | macOS 正式 |

## 版本锁定（落地时钉死具体号）

在 CI 与本文件更新为确切版本：

- CMake ≥ 3.24  
- Ninja ≥ 1.11  
- Windows：Clang（clang-cl）主版本与 AsApp 业务仓一致；需满足当前 MSVC STL 要求  
- Windows SDK：与 Win7 交付策略兼容的已验证版本  

## 应急通道

允许短期使用 MSVC `cl` + Ninja，但必须在包 `PACKAGE_META` / 发布说明中标注；不得作为新包默认路径。  
**禁止** 将 MinGW ABI 产物写入默认 Windows 切片。
