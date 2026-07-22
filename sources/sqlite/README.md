# SQLite amalgamation source record

该目录用于存放受控纳管的 SQLite3 amalgamation 源码。

当前纳管方式：

- 版本：`3.53.3`（amalgamation year-code `3530300`）
- 来源：`https://www.sqlite.org/2026/sqlite-amalgamation-3530300.zip`
- 归档索引：`third_party/archives/sqlite/README.md`
- 落仓文件：
  - `third_party/sources/sqlite/src/sqlite3.c`
  - `third_party/sources/sqlite/src/sqlite3.h`
  - `third_party/sources/sqlite/src/sqlite3ext.h`
- ZIP SHA-256：`646421e12aac110282ef8cc68f1a62d4bb15fc7b8f09da0b53e29ee690500431`
- `sqlite3.c` SHA-256：`87497ab605bedd0dbee27a209c1eeff8c89b229b13f921a7efdbb81a13f779fd`
- 许可证：Public Domain（SQLite Blessing）
- 许可证文件：`third_party/licenses/sqlite-LICENSE.txt`
- 本地补丁目录：`third_party/patches/sqlite/`

## CMake 集成

由 `cmake/AsAppSqlite.cmake` 提供静态库目标 `asapp_sqlite3`（别名 `SQLite::SQLite3`）：

```cmake
include(${CMAKE_SOURCE_DIR}/cmake/AsAppSqlite.cmake)
asapp_ensure_sqlite3()
target_link_libraries(your_target PRIVATE asapp_sqlite3)
```

当前用于 `common/config` 配置中心后端（`als_config.db`）。后续若升级版本，需同步更新来源、哈希、许可证与补丁关系。
