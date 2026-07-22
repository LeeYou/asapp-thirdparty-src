# asapp-thirdparty-src

AsApp / ALS 平台 **第三方依赖源码与构建仓**（唯一源）。

配套制品仓：[asapp-thirdparty-prebuilt](https://github.com/LeeYou/asapp-thirdparty-prebuilt)  
业务仓通过 **制品仓子模块** 消费依赖，不直接编译本仓（除库管理/CI）。

权威设计（业务仓文档）：`AsApp/docs/enterprisev3.0/third_party/00–08`

## 目录

```text
sources/          纳管源码
patches/          可回放补丁
licenses/         许可证文本
archives/         上游归档索引（大文件可不入库）
manifests/        dependencies.yaml / SBOM 输入
cmake/            统一超级构建与 toolchain
scripts/          build / package / verify
prebuilt/         submodule → asapp-thirdparty-prebuilt（可选工作流）
docs/             本仓分支与构建说明
```

## 快速开始

```powershell
# Windows：clang-cl + Ninja，Win7 API 基线
.\scripts\build.ps1 -Os windows -Arch x64 -Linkage static -Config release -Packages nlohmann_json,stb
```

```bash
# Linux / macOS：clang + Ninja
./scripts/build.sh --os linux --arch x64 --linkage static --config release --packages nlohmann_json,stb
```

## 分支

见 [`docs/BRANCHING.md`](docs/BRANCHING.md)。日常开发在 `develop`，发布合入 `main` 并关联制品 tag。
