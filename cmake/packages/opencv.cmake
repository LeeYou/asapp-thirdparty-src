# opencv — OpenCV 4.5.5（Win7 基线；仅 core/imgproc/imgcodecs）
# 源码期望：sources/opencv/src（上游解压根，含 CMakeLists.txt）
# 导出：OpenCVConfig.cmake / OpenCV::opencv_*（上游 install）
#
# ★ 两层约定（勿混用）：
#   1) 制品切片（打包 / SyncToPrebuilt / deps-*）：必须 **shared-release**
#      例：windows-x86-shared-release、linux-x64-shared-release
#      构建传 -Linkage shared -Config release（build.ps1 默认 Linkage=static，勿误用）
#   2) OpenCV 库形态：无论切片 linkage，配方内 **强制 STATIC**
#      供 AsApp 私有图像 facade 静态链入，避免与插件/其它第三方 OpenCV 动态库版本冲突
#      禁止产出/交付 opencv_*.dll / libopencv_*.so 作为运行时依赖
#
# static-release / *-debug 切片仅本地实验；禁止默认 SyncToPrebuilt。

set(_OPENCV_SRC "${ASAPP_DEP_SOURCE_ROOT}/opencv/src")
if(NOT EXISTS "${_OPENCV_SRC}/CMakeLists.txt")
    message(FATAL_ERROR "opencv source missing: ${_OPENCV_SRC}/CMakeLists.txt (extract archives/opencv/opencv-4.5.5.zip)")
endif()

if(NOT ASAPP_DEP_LINKAGE STREQUAL "shared" OR NOT ASAPP_DEP_CONFIG STREQUAL "release")
    message(WARNING
        "opencv: ship slice is shared-release; current is ${ASAPP_DEP_OS}-${ASAPP_DEP_ARCH}-${ASAPP_DEP_LINKAGE}-${ASAPP_DEP_CONFIG}. "
        "Do NOT SyncToPrebuilt / tag as delivery unless you intentionally want this non-ship slice.")
endif()

# 制品布局对齐规格 03：强制 lib/bin/include（避免 GNUInstallDirs 的 lib64）
set(CMAKE_INSTALL_LIBDIR "lib" CACHE STRING "" FORCE)
set(CMAKE_INSTALL_BINDIR "bin" CACHE STRING "" FORCE)
set(CMAKE_INSTALL_INCLUDEDIR "include" CACHE STRING "" FORCE)

# AsApp 全仓 C++17 硬上限；OpenCV 4.5.x 默认 C++11，抬到 17 安全
set(CMAKE_CXX_STANDARD 17 CACHE STRING "" FORCE)
set(CMAKE_CXX_STANDARD_REQUIRED ON CACHE BOOL "" FORCE)
set(CMAKE_CXX_EXTENSIONS OFF CACHE BOOL "" FORCE)

# ★ OpenCV 强制静态：覆盖 AsAppDepOptions 按切片注入的 BUILD_SHARED_LIBS
# 切片仍是 shared-release（动态 CRT /MD）；库本身为 .lib/.a，由业务 facade 私有链接
set(BUILD_SHARED_LIBS OFF CACHE BOOL "opencv always static (slice may still be shared-release)" FORCE)
message(STATUS "opencv: library=STATIC (forced); ship_slice=shared-release; current_slice=${ASAPP_DEP_SLICE}")

# Windows 上游默认静态装到 staticlib/；强制 lib/（规格 03），与 sqlite/zxing 等一致
# 须在 add_subdirectory 前 set，ocv_update 仅在未定义时赋值
if(WIN32)
    set(OPENCV_INSTALL_BINARIES_PREFIX "")
    set(OPENCV_INSTALL_BINARIES_SUFFIX "lib")
    set(OPENCV_BIN_INSTALL_PATH "bin")
    set(OPENCV_LIB_INSTALL_PATH "lib")
    set(OPENCV_LIB_ARCHIVE_INSTALL_PATH "lib")
    set(OPENCV_3P_LIB_INSTALL_PATH "lib")
    set(OPENCV_CONFIG_INSTALL_PATH "lib/cmake/opencv4")
    set(OPENCV_INCLUDE_INSTALL_PATH "include")
endif()

# 精简模块：编解码 + 图像处理（证件外框/轮廓/透视裁剪）
set(BUILD_LIST "core,imgproc,imgcodecs" CACHE STRING "" FORCE)
set(WITH_OPENJPEG OFF CACHE BOOL "" FORCE)
set(BUILD_OPENJPEG OFF CACHE BOOL "" FORCE)

# clang-cl + 空 CMAKE_SYSTEM_PROCESSOR 时 OpenCV 会把 CV_SIMD 关掉，arithm.simd.hpp 宏炸
# 工具链已补 processor；此处再钉 baseline，保证 x86 至少 SSE2
if(ASAPP_DEP_ARCH STREQUAL "x86")
    set(CPU_BASELINE "SSE2" CACHE STRING "" FORCE)
elseif(ASAPP_DEP_ARCH STREQUAL "x64")
    set(CPU_BASELINE "SSE3" CACHE STRING "" FORCE)
elseif(ASAPP_DEP_ARCH STREQUAL "arm64")
    set(CPU_BASELINE "NEON" CACHE STRING "" FORCE)
endif()

set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(BUILD_PERF_TESTS OFF CACHE BOOL "" FORCE)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_opencv_apps OFF CACHE BOOL "" FORCE)
set(BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(BUILD_JAVA OFF CACHE BOOL "" FORCE)
set(BUILD_opencv_python2 OFF CACHE BOOL "" FORCE)
set(BUILD_opencv_python3 OFF CACHE BOOL "" FORCE)
set(BUILD_opencv_js OFF CACHE BOOL "" FORCE)
set(BUILD_opencv_world OFF CACHE BOOL "" FORCE)
set(OPENCV_ENABLE_NONFREE OFF CACHE BOOL "" FORCE)

# 关重依赖 / 可选加速，利于 Win7 与体积
set(WITH_CUDA OFF CACHE BOOL "" FORCE)
set(WITH_CUFFT OFF CACHE BOOL "" FORCE)
set(WITH_CUBLAS OFF CACHE BOOL "" FORCE)
set(WITH_CUDNN OFF CACHE BOOL "" FORCE)
set(WITH_OPENCL OFF CACHE BOOL "" FORCE)
set(WITH_OPENCLAMDFFT OFF CACHE BOOL "" FORCE)
set(WITH_OPENCLAMDBLAS OFF CACHE BOOL "" FORCE)
set(WITH_IPP OFF CACHE BOOL "" FORCE)
set(WITH_ITT OFF CACHE BOOL "" FORCE)
set(WITH_TBB OFF CACHE BOOL "" FORCE)
set(WITH_EIGEN OFF CACHE BOOL "" FORCE)
set(WITH_OPENMP OFF CACHE BOOL "" FORCE)
set(WITH_PTHREADS_PF OFF CACHE BOOL "" FORCE)
set(WITH_FFMPEG OFF CACHE BOOL "" FORCE)
set(WITH_GSTREAMER OFF CACHE BOOL "" FORCE)
set(WITH_MSMF OFF CACHE BOOL "" FORCE)
set(WITH_DSHOW OFF CACHE BOOL "" FORCE)
set(WITH_V4L OFF CACHE BOOL "" FORCE)
set(WITH_LIBV4L OFF CACHE BOOL "" FORCE)
set(WITH_QT OFF CACHE BOOL "" FORCE)
set(WITH_GTK OFF CACHE BOOL "" FORCE)
set(WITH_WIN32UI OFF CACHE BOOL "" FORCE)
set(WITH_VTK OFF CACHE BOOL "" FORCE)
set(WITH_OPENGL OFF CACHE BOOL "" FORCE)
set(WITH_OPENEXR OFF CACHE BOOL "" FORCE)
set(WITH_WEBP OFF CACHE BOOL "" FORCE)
set(WITH_TIFF OFF CACHE BOOL "" FORCE)
set(WITH_GDAL OFF CACHE BOOL "" FORCE)
set(WITH_GDCM OFF CACHE BOOL "" FORCE)
set(WITH_IMGCODEC_HDR OFF CACHE BOOL "" FORCE)
set(WITH_IMGCODEC_SUNRASTER OFF CACHE BOOL "" FORCE)
set(WITH_IMGCODEC_PXM OFF CACHE BOOL "" FORCE)
set(WITH_IMGCODEC_PFM OFF CACHE BOOL "" FORCE)
set(WITH_PROTOBUF OFF CACHE BOOL "" FORCE)
set(WITH_QUIRC OFF CACHE BOOL "" FORCE)
set(WITH_ADE OFF CACHE BOOL "" FORCE)

# JPEG/PNG/ZLIB：强制走上游 3rdparty，离线可编（BMP 无需外库）
set(WITH_JPEG ON CACHE BOOL "" FORCE)
set(WITH_PNG ON CACHE BOOL "" FORCE)
set(WITH_JASPER OFF CACHE BOOL "" FORCE)
set(BUILD_JPEG ON CACHE BOOL "" FORCE)
set(BUILD_PNG ON CACHE BOOL "" FORCE)
set(BUILD_ZLIB ON CACHE BOOL "" FORCE)
set(BUILD_TIFF OFF CACHE BOOL "" FORCE)
set(BUILD_WEBP OFF CACHE BOOL "" FORCE)
set(BUILD_OPENEXR OFF CACHE BOOL "" FORCE)
set(BUILD_PROTOBUF OFF CACHE BOOL "" FORCE)
set(BUILD_QUIRC OFF CACHE BOOL "" FORCE)
set(OPENCV_FORCE_3RDPARTY_BUILD ON CACHE BOOL "" FORCE)

# MSVC ABI：与业务动态 CRT 对齐（勿强制静态 CRT）
set(BUILD_WITH_STATIC_CRT OFF CACHE BOOL "" FORCE)

# 不可 EXCLUDE_FROM_ALL，否则默认 ninja 不编译目标
add_subdirectory("${_OPENCV_SRC}" "${CMAKE_BINARY_DIR}/_deps/opencv")

# 补充 PACKAGE_META（上游自带 install + OpenCVConfig.cmake）
set(_META_DIR "${CMAKE_CURRENT_BINARY_DIR}/_meta/opencv")
file(MAKE_DIRECTORY "${_META_DIR}")
# ship_slice=shared-release；library_linkage=static（与切片 linkage 解耦，见文件头注释）
file(WRITE "${_META_DIR}/PACKAGE_META.yaml" "name: opencv
version: \"4.5.5\"
kind: compiled
license: Apache-2.0
windows_min_os: win7
upstream: opencv/opencv
cxx_standard: \"17\"
ship_slice: shared-release
library_linkage: static
slice: ${ASAPP_DEP_SLICE}
notes: \"OpenCV is always built STATIC; install only into *-shared-release. Consume via private AsApp image facade; do not ship opencv DLLs/SOs or re-export cv::*. find_package via CMAKE_PREFIX_PATH=<slice>/opencv (lib/cmake/opencv4).\"
features:
  modules: \"core,imgproc,imgcodecs\"
  library_linkage: static
  cuda: false
  opencl: false
  ipp: false
  jpeg: bundled
  png: bundled
install_layout: \"include/ + lib/ (+ lib/cmake/opencv4 on Windows)\"
toolchain:
  generator: ninja
  preferred: clang-ninja
  windows_driver: clang-cl
  abi: msvc
")
install(FILES "${_META_DIR}/PACKAGE_META.yaml" DESTINATION .)

# 安装后断言：切片可为 shared-release，但制品树禁止出现 OpenCV 动态库
install(CODE [[
  set(_ocv_root "${CMAKE_INSTALL_PREFIX}")
  file(GLOB_RECURSE _ocv_dyn
    "${_ocv_root}/*.dll"
    "${_ocv_root}/*.so"
    "${_ocv_root}/*.so.*"
    "${_ocv_root}/*.dylib")
  if(_ocv_dyn)
    message(FATAL_ERROR
      "opencv must be STATIC-only (no runtime DLL/SO); found:\n  ${_ocv_dyn}\n"
      "Check BUILD_SHARED_LIBS=OFF and OPENCV_*_INSTALL_PATH in cmake/packages/opencv.cmake")
  endif()
]])
