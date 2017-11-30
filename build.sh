#!/bin/bash
set -x

# get current script path and use it as the base directory

SCRIPT=$(readlink -f "$0")

export BASE_DIR=$(dirname "$SCRIPT")

export BUILD_DIR=$BASE_DIR/build
export RPI_ROOT=$BASE_DIR/rpi

# install required dependencies

sudo apt-get install apt qemu-user-static debootstrap clang build-essential g++-arm-linux-gnueabihf libglib2.0-dev 

# clean raspberry root?

if true; then

    rm -Rf $RPI_ROOT
    mkdir -p $RPI_ROOT
    cd $RPI_ROOT

    qemu-debootstrap --foreign --arch armhf jessie $RPI_ROOT http://ftp.debian.org/debian

    chroot $RPI_ROOT apt -q -y --force-yes install build-essential
    chroot $RPI_ROOT apt -q -y --force-yes install gcc-multilib g++-multilib
    chroot $RPI_ROOT apt -q -y --force-yes install libstdc++-4.8-dev
    chroot $RPI_ROOT apt -q -y --force-yes install libfontconfig1-dev
fi

# clean build?
if true; then

    rm -Rf $BUILD_DIR
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR

    git clone https://github.com/mono/SkiaSharp.git skia
    cd skia
    git checkout tags/v1.57.1
    git submodule update --init --recursive

    cd externals/skia

    python tools/git-sync-deps

    cd $BUILD_DIR/skia
    git apply $BASE_DIR/skiasharp.patch

    cd $BUILD_DIR/skia/externals/skia
    git apply $BASE_DIR/skia-build-script-changes.patch
    
fi

cd $BUILD_DIR/skia/externals/skia
export PATH="$PATH:$BUILD_DIR/skia/externals/depot_tools"

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
        "--sysroot='$RPI_ROOT'",
        "-I'$RPI_ROOT'/usr/include/c++/4.9",
        "-I'$RPI_ROOT'/usr/include/arm-linux-gnueabihf",
        "-I'$RPI_ROOT'/usr/include/arm-linux-gnueabihf/c++/4.9",
        "-I'$RPI_ROOT'/usr/include/freetype2",
        "-DSKIA_C_DLL"
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

ARCH=arm SUPPORT_GPU=0 CXX=arm-linux-gnueabihf-g++ CC=arm-linux-gnueabihf-g++ LDFLAGS="-Wl,-L $RPI_ROOT/usr/lib/arm-linux-gnueabihf -Wl,-g -Wl,-lfreetype" CXXFLAGS="-march=armv7-a -mthumb -mfpu=neon -mfloat-abi=hard" make

# ARCH=arm SUPPORT_GPU=0 CXX=clang++ CC=clang++ LDFLAGS="-target armv7a-linux -mfloat-abi=hard -mfpu=vfpv3 -Wl,-L /root/rpi/usr/lib/arm-linux-gnueabihf -Wl,-g -Wl,-lfreetype" CXXFLAGS="-target armv7a-linux -mfloat-abi=hard -mfpu=vfpv3 --sysroot=/root/rpi -std=c++11" make

cp bin/arm/libSkiaSharp.so.0.0.0 ../../../

mv ../../../libSkiaSharp.so.0.0.0 ../../../libSkiaSharp.so

echo built.
