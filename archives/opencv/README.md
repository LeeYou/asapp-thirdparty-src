# OpenCV archive index

- **Name**: opencv-4.5.5 (git tag `4.5.5`)
- **Version**: 4.5.5
- **URL**: https://github.com/opencv/opencv/archive/refs/tags/4.5.5.zip
- **SHA-256** (zip): `FB16B734DB3A28E5119D513BD7C61EF417EDF3756165DC6259519BB9D23D04E2`
- **Size**: 94219100 bytes
- **Governed extract path**: `sources/opencv/src/`
- **License**: Apache-2.0 → `licenses/opencv-LICENSE.txt`

## 版本选型说明

- AsApp **必须支持 Windows 7**（`_WIN32_WINNT=0x0601`）。
- 选定 **4.5.5** 作为 Win7 友好的 4.x 基线；不追 4.10+/5.x。
- 禁止回退到 OpenCV 2.4 / 3.x。

## 交付约定（必须分清两层）

| 层级 | 权威取值 | 说明 |
|------|----------|------|
| **制品切片**（路径 / SyncToPrebuilt / deps-\*） | `*-shared-release` | Win/Linux 唯一正式打包目标，例：`windows-x86-shared-release` |
| **OpenCV 库形态** | **强制 STATIC** | 配方覆盖 `BUILD_SHARED_LIBS=OFF`；产出 `.lib`/`.a`，**无** `opencv_*.dll` / `libopencv_*.so` |
| **安装布局** | `include/` + `lib/` | Windows 也强制 `lib/`（覆盖上游默认 `staticlib/`）；Config 在 `lib/cmake/opencv4` |

为何静态：私有链入 AsApp 图像 facade，避免与插件/其它第三方 OpenCV 动态库版本冲突；勿向插件重导出 `cv::*`。

| 用途 | 切片 | OpenCV 库 | 说明 |
|------|------|-----------|------|
| **正式交付** | `*-shared-release` | static | **唯一默认**；`-Linkage shared -Config release` |
| 本地实验 | `*-static-release` 等 | 仍是 static | 须显式非 ship 开关；**禁止**误当交付物入库 |

`build.ps1` / `build.sh` 默认 `Linkage=static` 会落到 **错误切片名**（`*-static-release`）。编 opencv 交付物时**必须** `-Linkage shared -Config release`；这只决定切片目录，不决定 OpenCV 动态/静态（库永远 static）。

## 配方开关（`cmake/packages/opencv.cmake`）

| 选项 | 值 | 说明 |
|------|-----|------|
| `BUILD_SHARED_LIBS` | **OFF（强制）** | 与切片 shared-release 解耦 |
| `BUILD_LIST` | `core,imgproc,imgcodecs` | 编解码 + 图像处理（轮廓/透视） |
| CUDA / OpenCL / IPP | OFF | 体积与 Win7 兼容 |
| JPEG / PNG / ZLIB | 上游 3rdparty 内建 | 离线可编；BMP 无需外库 |
| tests / examples / apps / python | OFF | 生产制品关闭 |

## 解压与构建

```powershell
.\scripts\extract_archive.ps1 -Package opencv

# 正式交付：切片 shared-release；库仍为 static
.\scripts\build.ps1 -Arch x86 -Linkage shared -Config release -Packages opencv

# 非交付实验切片（仍强制 static 库；勿 SyncToPrebuilt）
# .\scripts\build.ps1 -Arch x86 -Linkage static -Config release -Packages opencv
```

构建以 `sources/opencv/src` 为准；本目录 zip 已被 `.gitignore`（大文件），README 作索引。
