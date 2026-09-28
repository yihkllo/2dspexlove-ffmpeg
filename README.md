# 2dspexlove-ffmpeg

SpineLoveEX 附带的 FFmpeg（LGPL）源码与构建脚本。

The FFmpeg (LGPL) sources and build scripts for the ffmpeg bundled with SpineLoveEX.

- `sources/`：FFmpeg 8.1.3、OpenH264 2.6.0、libvpx 1.17.0、zlib 1.3.1 官方源码包，未作修改
- `build-windows.bat`：Windows x64，需要 Visual Studio 2022、MSYS2（make、nasm、pkgconf）以及 `CLANG_CL` 指向 clang-cl.exe
- `build-android.sh`：Android arm64-v8a / x86_64，在 MSYS2 中运行，需要 `ANDROID_NDK_ROOT`
- `NOTICES.txt`：许可证
