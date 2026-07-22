# Google Test — 源码编译指南

## 下载
```bash
cd third_party/sources/gtest
# 源码放到 src/ 目录 (README.md 不会被覆盖)
git clone https://github.com/google/googletest.git -b v1.15.2 src
# 或离线包:
# curl -L -o googletest-1.15.2.tar.gz https://github.com/google/googletest/archive/v1.15.2.tar.gz
# tar -xzf googletest-1.15.2.tar.gz --strip-components=1 -C src
```

## 编译 (当前平台)
```bash
DST=../../staged/${PLATFORM}_${ARCH}/${CONFIG}/gtest
mkdir build && cd build
cmake ../src -G "Visual Studio 17 2022" -A Win32  ^
  -DCMAKE_SYSTEM_VERSION=7.0  ^
  -DCMAKE_CXX_STANDARD=17  ^
  -Dgtest_force_shared_crt=ON  ^
  -DCMAKE_INSTALL_PREFIX=$DST

cmake --build . --config Debug
cmake --install . --config Debug
```
示例: `DST=../../staged/windows_x86/debug/gtest`

## CMake 集成
```cmake
set(GTest_ROOT "${THIRD_PARTY_STAGED}/gtest")
find_package(GTest REQUIRED)
```
