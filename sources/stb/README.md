# stb — 单头文件图像库

## 说明
stb_image / stb_image_write / stb_truetype 是公共领域单头文件库。
**无需编译**，直接 `#include` 即可。

## 下载
```bash
cd third_party/sources/stb/src
curl -L -O https://raw.githubusercontent.com/nothings/stb/master/stb_image.h
curl -L -O https://raw.githubusercontent.com/nothings/stb/master/stb_image_write.h
curl -L -O https://raw.githubusercontent.com/nothings/stb/master/stb_truetype.h
```

## 安装
```bash
DST=../../staged/${PLATFORM}_${ARCH}/${CONFIG}/stb/include/stb
mkdir -p $DST
cp src/*.h $DST/
```

## CMake 集成
```cmake
target_include_directories(your_target PRIVATE "${THIRD_PARTY_STAGED}/stb/include")
```
