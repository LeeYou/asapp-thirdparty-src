# openssl — Windows 由 scripts/build_openssl_windows.ps1 构建（perl+nmake 例外）
# 本文件仅用于文档化：CMake 超级构建不直接编 OpenSSL。

message(FATAL_ERROR
    "OpenSSL is built via scripts/build_openssl_windows.ps1 (perl+nmake toolchain exception).\n"
    "  Example:\n"
    "  .\\scripts\\build_openssl_windows.ps1 -Arch x64 -Linkage static -Config release")
