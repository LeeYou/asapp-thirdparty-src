# gRPC source

- Version: **1.67.1**
- Bundled protobuf / protoc: **27.2** (under `src/third_party/protobuf`)
- Build (Windows x64 static release):

```powershell
.\scripts\build_grpc_windows.ps1 -Arch x64 -Linkage static -Config release
```

Requires OpenSSL already available at `dist/<slice>/openssl` or `prebuilt/<slice>/openssl` (or pass `-OpenSslRoot`).

Toolchain exception: VsDevCmd + Ninja + MSVC `cl` (MSVC ABI), SSL via package OpenSSL.

## Source intake

Upstream tree lives at `sources/grpc/src` (local / managed checkout; not committed to this repo due to size ~589MB).
Place or clone gRPC 1.67.1 sources there before building.
