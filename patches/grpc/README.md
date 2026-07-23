# gRPC Windows shared patches

| 补丁脚本 | 作用 |
|----------|------|
| `scripts/apply_grpc_win32_shared_upb_static.ps1` | Win32/x64 **shared** 构建前：① `upb_*`/`utf8`/`grpc*_unsecure` 强制 STATIC；② `trace_flags` 全局 `TraceFlag` 加 `GRPC_DLL`，修 `grpc++.dll` 对 `grpc.dll` 数据符号 LNK1120。主 DLL：`gpr`/`grpc`/`grpc++`。 |

同时 `build_grpc_windows.ps1` 在 `-Linkage shared` 时增加 `-Dprotobuf_BUILD_LIBUPB=OFF`，避免 bundled protobuf 的 libupb 与 vendored upb 冲突（见 grpc#35794）。
