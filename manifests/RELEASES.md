# 依赖集发布记录

| 源码 commit / tag | 制品 tag | 说明 |
|-------------------|----------|------|
| （bootstrap） | deps-bootstrap | 仓骨架 + header-only 试点切片 |
| d1abf51 | deps-2026.07.22 | sqlite / gtest / spdlog（windows-x64-static-release，历史） |
| 1a56eb5 | deps-2026.07.22-1 | openssl / libffi（windows-x64-static-release，历史） |
| 167d86f | deps-2026.07.22-2 | grpc 1.67.1（windows-x64-static-release，历史） |
| debb513 | deps-2026.07.22-3 | boost 1.90.0 header-only（windows-x64-static-release，历史） |
| 4760218 | deps-2026.07.22-4 | libcef shared-runtime（windows-x64-shared-release，历史） |
| c1472d4 | deps-2026.07.23-5 | Windows x86 四切片 + static gRPC；libcef x86 shared-release |
| db6955a | deps-2026.07.23-6 | 移除全部 windows-x64 切片；仅保留 Win32 主交付四切片 |
| （本仓 HEAD） | deps-2026.07.23-7 | 补齐 gRPC **shared** Win32 debug/release（upb STATIC + TraceFlag GRPC_DLL + PATH for plugins） |
| feebdf2 | deps-2026.07.24-1 | spdlog Config 去掉 `SPDLOG_HEADER_ONLY`（修复 CEF `/WX` 下 MSVC C4005→C2220） |
