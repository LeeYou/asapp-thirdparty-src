# grpc — Windows 由 scripts/build_grpc_windows.ps1 构建（VsDevCmd+Ninja+MSVC 例外）
# 捆绑 protobuf；产物目标名 gRPC::grpc++ / protobuf::libprotobuf / bin/protoc

message(FATAL_ERROR
    "gRPC is built via scripts/build_grpc_windows.ps1 (MSVC+Ninja toolchain exception).\n"
    "  Example:\n"
    "  .\\scripts\\build_grpc_windows.ps1 -Arch x64 -Linkage static -Config release\n"
    "  Requires OpenSSL already in dist/<slice>/openssl or prebuilt/<slice>/openssl.")
