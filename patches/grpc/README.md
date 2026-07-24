# gRPC patches

## Windows shared

| 补丁脚本 | 作用 |
|----------|------|
| `scripts/apply_grpc_win32_shared_upb_static.ps1` | Win32/x64 **shared** 构建前：① `upb_*`/`utf8`/`grpc*_unsecure` 强制 STATIC；② `trace_flags` 全局 `TraceFlag` 加 `GRPC_DLL`，修 `grpc++.dll` 对 `grpc.dll` 数据符号 LNK1120。主 DLL：`gpr`/`grpc`/`grpc++`。 |

同时 `build_grpc_windows.ps1` 在 `-Linkage shared` 时增加 `-Dprotobuf_BUILD_LIBUPB=OFF`，避免 bundled protobuf 的 libupb 与 vendored upb 冲突（见 grpc#35794）。

## Linux

`scripts/build_grpc_linux.sh` 使用官方 CMake + `linux-clang.cmake`，SSL 来自同切片 OpenSSL。  
shared 同样传 `-Dprotobuf_BUILD_LIBUPB=OFF`；**不**应用 Windows upb STATIC 补丁（POSIX 动态链接模型不同）。若 Linux shared 出现 upb 符号问题，再在本目录补 POSIX 补丁。
