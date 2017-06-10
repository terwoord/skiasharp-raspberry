#!/bin/bash
set -x

#clean build?

if true; then

    rm -Rf /home/matthijs/skia
    mkdir /home/matthijs/skia
    cd /home/matthijs/skia

    git clone https://github.com/mono/SkiaSharp.git .
    git checkout tags/v1.57.1

    git submodule update --init --recursive

    cd externals/skia

    python tools/git-sync-deps

    cd /home/matthijs/skia
    git apply /home/matthijs/skia-script/skiasharp.patch

    cd /home/matthijs/skia/externals/skia
    git apply /home/matthijs/skia-script/skia-build-script-changes.patch
    
fi

cd /home/matthijs/skia/externals/skia
export PATH="$PATH:/home/matthijs/skia/externals/depot_tools"


if true; then

    rm -Rf out

    gn gen out/linux/arm --args='
      target_cpu = "arm" 
      cc = "clang-3.8" 
      cxx = "clang++-3.8"
      skia_enable_gpu = false
      skia_use_libjpeg_turbo = false
     
      is_official_build = true
      skia_enable_tools = false
     
      skia_use_icu = false
      skia_use_sfntly = false
      skia_use_system_freetype2 = false
      is_debug = false
     
      extra_cflags = [
        "-g",
        "-target", "armv7a-linux",
        "-mfloat-abi=hard",
        "-mfpu=neon",
        "--sysroot=/root/rpi",
        "-I/root/rpi/usr/include/c++/4.9",
        "-I/root/rpi/usr/include/arm-linux-gnueabihf",
        "-I/root/rpi/usr/include/arm-linux-gnueabihf/c++/4.9",
        "-I/root/rpi/usr/include/freetype2",
        "-DSKIA_C_DLL",
      ]
      extra_asmflags = [
        "-g",
            "-target", "armv7a-linux",
            "-mfloat-abi=hard",
            "-mfpu=neon",
          ]
        '
    
    ninja -C out/linux/arm

fi

# now skiasharp

cd ../../native-builds/libSkiaSharp_linux

make clean

ARCH=arm SUPPORT_GPU=0 CXX=arm-linux-gnueabihf-g++ CC=arm-linux-gnueabihf-g++ LDFLAGS="-Wl,-L /root/rpi/usr/lib/arm-linux-gnueabihf -Wl,-g -Wl,-lfreetype" CXXFLAGS="-march=armv7-a -mthumb -mfpu=neon -mfloat-abi=hard" make

# ARCH=arm SUPPORT_GPU=0 CXX=clang++ CC=clang++ LDFLAGS="-target armv7a-linux -mfloat-abi=hard -mfpu=vfpv3 -Wl,-L /root/rpi/usr/lib/arm-linux-gnueabihf -Wl,-g -Wl,-lfreetype" CXXFLAGS="-target armv7a-linux -mfloat-abi=hard -mfpu=vfpv3 --sysroot=/root/rpi -std=c++11" make

cp bin/arm/libSkiaSharp.so.0.0.0 ../../../

mv ../../../libSkiaSharp.so.0.0.0 ../../../libSkiaSharp.so

echo built.