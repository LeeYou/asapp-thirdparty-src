# OpenCV sources

受控源码树（gitignore，不入库）：

- 归档：`archives/opencv/opencv-4.5.5.zip`
- 解压：`.\scripts\extract_archive.ps1 -Package opencv`
- 期望根：`sources/opencv/src/CMakeLists.txt`

配方：`cmake/packages/opencv.cmake`（OpenCV 4.5.5；`core` + `imgproc` + `imgcodecs`）。

## 交付约定（两层，勿混）

| 层级 | 取值 |
|------|------|
| **制品切片** | `*-shared-release`（`-Linkage shared -Config release`） |
| **OpenCV 库** | **强制 STATIC**（无 dll/so；链入私有图像 facade） |
| **布局** | `include/` + `lib/`（含 `lib/cmake/opencv4`） |

- 非 `shared-release` 切片：仅显式实验；勿默认 SyncToPrebuilt
