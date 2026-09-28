set -eu
root=$(cd "$(dirname "$0")" && pwd)
rootwin=$(cygpath -m "$root")
: "${CLANG_CL:?}"
clangcl=$(cygpath -u "$CLANG_CL")
src=$root/build/src
build=$root/build/windows-x86_64
prefix=$root/build/prefix/windows-x86_64
logs=$root/build/logs
vcbin=$(cygpath -u "$VCToolsInstallDir")bin/Hostx64/x64
msbuild=$(cygpath -u "$VSINSTALLDIR")MSBuild/Current/Bin
export PATH="$vcbin:$msbuild:/usr/bin:$PATH"
mkdir -p "$src" "$build" "$prefix/lib/pkgconfig" "$prefix/include" "$logs" "$root/dist/windows-x86_64"
for component in ffmpeg-8.1.3 openh264-2.6.0 libvpx-1.17.0 zlib-1.3.1; do
if [ ! -d "$src/$component" ]; then
for archive in "$root/sources/$component".tar.*; do tar -xf "$archive" -C "$src"; done
fi
done
prefixwin=$(cygpath -m "$prefix")
rm -rf "$build/openh264" && cp -r "$src/openh264-2.6.0" "$build/openh264"
cd "$build/openh264"
make -j8 OS=msvc ARCH=x86_64 USE_ASM=Yes PREFIX="$prefix" install-static > "$logs/windows-openh264.log" 2>&1
sed "s#^prefix=.*#prefix=$prefixwin#;s#^libdir=.*#libdir=\${prefix}/lib#" openh264-static.pc > "$prefix/lib/pkgconfig/openh264.pc"
printf '%s\n' "windows OpenH264 complete"
rm -rf "$build/vpx" && mkdir -p "$build/vpx" && cd "$build/vpx"
"$src/libvpx-1.17.0/configure" --target=x86_64-win64-vs17 --prefix="$prefix" --enable-static-msvcrt --disable-shared --enable-static --disable-examples --disable-tools --disable-docs --disable-unit-tests --disable-vp8 --enable-vp9 --disable-vp9-decoder --disable-realtime-only > "$logs/windows-vpx-config.log" 2>&1
sed -i "s#$root#<build-root>#g;s#$rootwin#<build-root>#g" vpx_config.c
make -j8 > "$logs/windows-vpx.log" 2>&1
make install >> "$logs/windows-vpx.log" 2>&1
printf 'prefix=%s\nlibdir=${prefix}/lib/x64\nincludedir=${prefix}/include\n\nName: vpx\nDescription: WebM Project VPx codec implementation\nVersion: 1.17.0\nLibs: -L${libdir} -lvpxmt\nCflags: -I${includedir}\n' "$prefixwin" > "$prefix/lib/pkgconfig/vpx.pc"
printf '%s\n' "windows libvpx complete"
rm -rf "$build/zlib" && mkdir -p "$build/zlib" && cd "$build/zlib"
zsrc=$src/zlib-1.3.1
for f in adler32 compress crc32 deflate infback inffast inflate inftrees trees uncompr zutil; do
cl -nologo -c -O2 -MT -DNDEBUG -D_CRT_SECURE_NO_DEPRECATE -I"$(cygpath -m "$zsrc")" "$(cygpath -m "$zsrc/$f.c")" >> "$logs/windows-zlib.log" 2>&1
done
lib -nologo -out:zlib.lib *.obj >> "$logs/windows-zlib.log" 2>&1
cp zlib.lib "$prefix/lib/zlib.lib"
cp "$zsrc/zlib.h" "$zsrc/zconf.h" "$prefix/include/"
sed -i "s/^#ifdef HAVE_UNISTD_H.*/#if 0/" "$prefix/include/zconf.h"
printf '%s\n' "windows zlib complete"
sed -i 's/VSLANG=1033 $_cc -nologo- 2>\&1 | grep -q ^Microsoft/VSLANG=1033 $_cc -nologo- 2>\&1 | grep -q Microsoft/' "$src/ffmpeg-8.1.3/configure"
rm -rf "$build/ffmpeg" && mkdir -p "$build/ffmpeg" && cd "$build/ffmpeg"
export PKG_CONFIG_PATH="$prefix/lib/pkgconfig"
"$src/ffmpeg-8.1.3/configure" --prefix="$prefix/ffmpeg" --toolchain=msvc --arch=x86_64 --target-os=win64 --pkg-config=pkg-config --pkg-config-flags=--static --disable-autodetect --disable-everything --disable-doc --disable-debug --disable-network --disable-shared --enable-static --enable-small --disable-ffplay --disable-ffprobe --enable-ffmpeg --enable-avcodec --enable-avformat --enable-avfilter --enable-swscale --enable-swresample --enable-w32threads --enable-zlib --enable-libopenh264 --enable-libvpx --enable-encoder=libopenh264,libvpx_vp9,gif,png,mjpeg --enable-decoder=png,mjpeg,bmp,rawvideo --enable-demuxer=image2,image2pipe,rawvideo --enable-muxer=mp4,webm,gif,image2,rawvideo --enable-protocol=file,pipe --enable-filter=buffer,buffersink,format,scale,crop,split,palettegen,paletteuse,fps,null,transpose,vflip,hflip,setsar --extra-cflags="-MT -d1trimfile:$rootwin/build/src/ -d1trimfile:$(cygpath -w "$src")\\ -I$prefixwin/include" --extra-ldflags="-LIBPATH:$prefixwin/lib" --extra-libs="zlib.lib" > "$logs/windows-ffmpeg-config.log" 2>&1
sed -i "s#$rootwin#<build-root>#g;s#$root#<build-root>#g" config.h
sed -i 's#-d1trimfile:[^ ]*##g' config.h
cbs=$(make -n libavformat/cbs.o 2>/dev/null | grep -m1 "^printf" | sed "s/^printf [^;]*; //;s#^cl.exe #$clangcl --target=x86_64-pc-windows-msvc -Wno-everything /clang:-ffile-prefix-map=$rootwin/build/src/= #")
eval "$cbs" > "$logs/windows-ffmpeg.log" 2>&1
make -j8 >> "$logs/windows-ffmpeg.log" 2>&1
cp ffmpeg.exe "$root/dist/windows-x86_64/ffmpeg.exe"
printf '%s\n' "windows FFmpeg complete"
