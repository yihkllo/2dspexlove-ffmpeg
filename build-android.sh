set -eu
root=$(cd "$(dirname "$0")" && pwd)
abi=$1
: "${ANDROID_NDK_ROOT:?}"
src=$root/build/src
mkdir -p "$src" "$root/build/logs"
for component in ffmpeg-8.1.3 openh264-2.6.0 libvpx-1.17.0; do
if [ ! -d "$src/$component" ]; then
for archive in "$root/sources/$component".tar.*; do tar -xf "$archive" -C "$src"; done
fi
done
case "$abi" in
arm64-v8a) triple=aarch64-linux-android; arch=arm64; ffarch=aarch64; vpxtarget=arm64-android-gcc ;;
x86_64) triple=x86_64-linux-android; arch=x86_64; ffarch=x86_64; vpxtarget=x86_64-android-gcc ;;
*) exit 2 ;;
esac
ndk=$(cygpath -u "$ANDROID_NDK_ROOT")
ndk=$(cd "$ndk" && pwd)
rootwin=$(cygpath -m "$root")
toolbin=$ndk/toolchains/llvm/prebuilt/windows-x86_64/bin
build=$root/build/$abi
prefix=$root/build/prefix/$abi
logs=$root/build/logs
mkdir -p "$build/bin" "$root/build/host-bin"
printf '#!/bin/sh\nexec "%s/clang.exe" --target=%s28 "$@"\n' "$toolbin" "$triple" > "$build/bin/cc"
printf '#!/bin/sh\nexec "%s/clang++.exe" --target=%s28 "$@"\n' "$toolbin" "$triple" > "$build/bin/cxx"
printf '#!/bin/sh\nexec "%s/llvm-readelf.exe" "$@"\n' "$toolbin" > "$root/build/host-bin/readelf"
chmod +x "$build/bin/cc" "$build/bin/cxx" "$root/build/host-bin/readelf"
export PATH="$root/build/host-bin:$toolbin:/usr/bin:$PATH"
export CC="$build/bin/cc" CXX="$build/bin/cxx"
export AR="$toolbin/llvm-ar.exe" RANLIB="$toolbin/llvm-ranlib.exe" STRIP="$toolbin/llvm-strip.exe"
export CFLAGS="-O2 -fPIC -ffunction-sections -fdata-sections -ffile-prefix-map=$rootwin=. -ffile-prefix-map=$root=."
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-static-libstdc++ -Wl,-z,max-page-size=16384 -Wl,--gc-sections"
mkdir -p "$prefix" "$build/openh264" "$build/vpx" "$build/ffmpeg" "$root/dist/$abi"
cp -r "$src/openh264-2.6.0/." "$build/openh264/"
cd "$build/openh264"
make -j8 OS=android ARCH="$arch" NDKROOT="$ndk" TARGET=android-28 CC="$CC" CXX="$CXX" AR="$AR" CFLAGS="$CFLAGS -DANDROID_NDK -fstack-protector-strong" CXXFLAGS="-fno-rtti -fno-exceptions" PREFIX="$prefix" install-static > "$logs/$abi-openh264.log" 2>&1
printf '%s\n' "$abi OpenH264 complete"
cd "$build/vpx"
AS=nasm
if [ "$arch" = arm64 ]; then AS="$CC -c"; fi
export AS LD="$CC"
"$src/libvpx-1.17.0/configure" --target="$vpxtarget" --prefix="$prefix" --enable-pic --disable-shared --enable-static --disable-examples --disable-tools --disable-docs --disable-unit-tests --disable-vp8 --enable-vp9 --disable-vp9-decoder --disable-realtime-only > "$logs/$abi-vpx-config.log" 2>&1
sed -i "s#$root#<build-root>#g;s#$rootwin#<build-root>#g" vpx_config.c
make -j8 > "$logs/$abi-vpx.log" 2>&1
make install >> "$logs/$abi-vpx.log" 2>&1
printf '%s\n' "$abi libvpx complete"
cd "$build/ffmpeg"
export PKG_CONFIG_PATH="$prefix/lib/pkgconfig"
unset AS LD
"$src/ffmpeg-8.1.3/configure" --prefix="$prefix/ffmpeg" --target-os=android --arch="$ffarch" --enable-cross-compile --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --strip="$STRIP" --pkg-config=pkg-config --pkg-config-flags=--static --disable-autodetect --disable-everything --disable-doc --disable-debug --disable-network --disable-shared --enable-static --enable-small --disable-ffplay --disable-ffprobe --enable-ffmpeg --enable-avcodec --enable-avformat --enable-avfilter --enable-swscale --enable-swresample --enable-pthreads --enable-zlib --enable-libopenh264 --enable-libvpx --enable-encoder=libopenh264,libvpx_vp9,gif,png,mjpeg --enable-decoder=png,mjpeg,bmp,rawvideo --enable-demuxer=image2,image2pipe,rawvideo --enable-muxer=mp4,webm,gif,image2,rawvideo --enable-protocol=file,pipe --enable-filter=buffer,buffersink,format,scale,crop,split,palettegen,paletteuse,fps,null,transpose,vflip,hflip,setsar --extra-cflags="$CFLAGS -I$prefix/include" --extra-ldflags="$LDFLAGS -L$prefix/lib" --extra-libs="-lc++_static -lc++abi" > "$logs/$abi-ffmpeg-config.log" 2>&1
sed -i "s#$ndk#<ndk-root>#g;s#$rootwin#<build-root>#g;s#$root#<build-root>#g" config.h
make -j8 > "$logs/$abi-ffmpeg.log" 2>&1
cp ffmpeg "$root/dist/$abi/libffmpeg.so"
"$STRIP" --strip-unneeded "$root/dist/$abi/libffmpeg.so"
printf '%s\n' "$abi FFmpeg complete"
