# 依赖集发布记录

| 源码 commit / tag | 制品 tag | 说明 |
|-------------------|----------|------|
| （bootstrap） | deps-bootstrap | 仓骨架 + header-only 试点切片 |
| d1abf51 | deps-2026.07.22 | sqlite / gtest / spdlog（windows-x64-static-release） |
| 1a56eb5 | deps-2026.07.22-1 | openssl / libffi（windows-x64-static-release） |
| 167d86f | deps-2026.07.22-2 | grpc 1.67.1 + bundled protobuf tools（windows-x64-static-release；PRE 大 .lib 使用 Git LFS） |
| debb513 | deps-2026.07.22-3 | boost 1.90.0 header-only（windows-x64-static-release） |
| 4760218 | deps-2026.07.22-4 | libcef 102.0.10 shared-runtime（windows-x64-shared-release；DLL/Resources/locales 使用 Git LFS） |
| （见源码仓 HEAD） | deps-2026.07.23-5 | Windows x86 主交付四切片；核心包 + gRPC **static** debug/release；libcef 仅 shared-release；gRPC shared Win32 暂缓（upb LNK1120） |
