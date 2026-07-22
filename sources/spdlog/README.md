# spdlog — 日志库 (header-only, Win7 兼容)

## 下载
```bash
cd third_party/sources/spdlog
# 源码放到 src/ 目录 (README.md 不会被覆盖)
curl -L -o spdlog-1.14.1.zip https://github.com/gabime/spdlog/archive/v1.14.1.zip
tar -xzf spdlog-1.14.1.zip --strip-components=1 -C src
```

## 安装 (header-only)
```bash
DST=../../staged/${PLATFORM}_${ARCH}/${CONFIG}/spdlog
mkdir -p $DST/include
cp -r src/include/spdlog $DST/include/
```
示例: `DST=../../staged/windows_x86/debug/spdlog`

## CMake 集成
```cmake
target_include_directories(your_target PRIVATE "${THIRD_PARTY_STAGED}/spdlog/include")
```
