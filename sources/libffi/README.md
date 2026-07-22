# libffi — 源码编译指南

## 说明
外部函数接口库，用于 System B 模块的 DynamicInvoke 机制。

## 下载
```bash
cd third_party/sources/libffi
curl -L -o libffi-3.4.6.tar.gz https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz
tar -xzf libffi-3.4.6.tar.gz --strip-components=1 -C src
```

## 编译 (Windows, Win7, 静态库)
```bash
mkdir build && cd build
cmake ../src -G "Visual Studio 17 2022" -A Win32  ^
  -DCMAKE_SYSTEM_VERSION=7.0  ^
  -DCMAKE_INSTALL_PREFIX=../../staged/windows_x86/debug/libffi
cmake --build . --config Debug --target install
```
