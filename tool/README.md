# tool/ — 受控构建工具目录

源码仓构建脚本 **优先** 使用本目录中的工具，再回退到系统 PATH / Visual Studio 安装。  
目的：保证在干净机器上也能复现 Win32/Win64 矩阵构建。

## 布局约定

```text
tool/
  README.md                 ← 本说明
  jom/
    jom.exe                 ← OpenSSL 等 nmake 并行加速（可选但强烈推荐）
  nasm/
    nasm.exe                ← 若某包需要（可选）
  vs/
    VsDevCmd.bat            ← 可选：拷贝/包装 VS 开发者命令行入口
```

解析逻辑见 `scripts/AsAppDepCommon.ps1` 的 `Resolve-AsAppDepTool`。

## 必选 / 推荐

| 工具 | 是否必须 | 用途 | 获取 |
|------|----------|------|------|
| Visual Studio 2022 + MSVC | **必须**（系统安装） | VsDevCmd、cl、ml、link | VS Installer；**禁止用 VS2017/2019 替代**（见 `TOOLCHAINS.md` / AsApp `third_party/12`） |
| LLVM clang-cl / Ninja | **必须** | 常规包 CMake 构建 | 系统或 CI 镜像 |
| Strawberry/Git perl | **必须**（OpenSSL） | `Configure` | 系统 PATH |
| **jom** | **强烈推荐** | 替代 nmake 并行编译 OpenSSL | 见下方 |
| MASM `ml.exe` | 随 VS 提供 | libffi Win32 汇编 | VsDevCmd -arch=x86 |

## 安装 jom（推荐）

官方：https://wiki.qt.io/Jom （或 Qt 安装树中的 `jom.exe`）

```powershell
# 示例：将 jom.exe 放到
tool\jom\jom.exe
```

未放置时，OpenSSL 回退单线程 `nmake`（正确但慢）。

## 原则

1. **不要**把巨型 IDE 整包放进本目录；只放轻量可执行文件与说明。  
2. 新增工具时：更新本 README + `Resolve-AsAppDepTool` 候选路径。  
3. 业务仓 AsApp **不**依赖本目录；仅源码仓构建使用。
