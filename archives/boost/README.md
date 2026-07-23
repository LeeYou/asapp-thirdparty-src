# archives/boost — 受控归档索引

- version: **1.90.0**
- archive: `boost_1_90_0.zip`（已放入本目录）
- source_sha256: `bdc79f179d1a4a60c10fe764172946d0eeafad65e576a8703c4d89d49949973c`
- 解压：`.\scripts\extract_archive.ps1 -Package boost` → `sources/boost/src/`（含 `boost/asio.hpp`，gitignore）
- 制品：header-only 切片（`scripts/sync_boost_headers.ps1` / `build.ps1 -Packages boost`）

说明：历史上官方 archives.boost.io 另一镜像的 sha256 可能不同；以本仓实测哈希为准。
