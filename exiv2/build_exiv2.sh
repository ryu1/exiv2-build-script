#!/bin/sh

GLOBAL_OUTDIR="`pwd`/output"

IOS_DEPLOY_TGT="8.0"

DEVELOPER=`xcode-select -print-path`
#export CC=${DEVELOPER}/usr/bin/gcc
#export CXX=${DEVELOPER}/usr/bin/g++

export CXX=`xcrun -find c++`
export CC=`xcrun -find cc`

export LD=`xcrun -find ld`
export AR=`xcrun -find ar`
export AS=`xcrun -find as`
export NM=`xcrun -find nm`
export RANLIB=`xcrun -find ranlib`

XCODE_DEVELOPER_PATH=/Applications/Xcode.app/Contents/Developer
XCODETOOLCHAIN_PATH=$XCODE_DEVELOPER_PATH/Toolchains/XcodeDefault.xctoolchain
SDK_IPHONEOS_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
SDK_IPHONESIMULATOR_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)

export PATH="$XCODETOOLCHAIN_PATH/usr/bin:$PATH"

declare -a archs
archs=(arm7 arm7s arm64 i386)

declare -a arch_name
arch_names=(arm-apple-darwin7 arm-apple-darwin7s arm-apple-darwin64 i386-apple-darwin)
#arch_names=(arm-apple-darwin arm-apple-darwin i386-apple-darwin)

setenv_all() {
    # Add internal libs
    export CFLAGS="$CFLAGS -I$GLOBAL_OUTDIR/include -L$GLOBAL_OUTDIR/lib -stdlib=libc++"

    export LDFLAGS="-L$SDKROOT/usr/lib/ -stdlib=libc++"

    export CPPFLAGS=$CFLAGS
    export CXXFLAGS=$CFLAGS
}

setenv_arm7() {
    unset DEVROOT SDKROOT CFLAGS CPP CXXCPP LDFLAGS CPPFLAGS CXXFLAGS

    export SDKROOT=$SDK_IPHONEOS_PATH

    export CFLAGS="-arch armv7 -pipe -no-cpp-precomp -isysroot $SDKROOT -miphoneos-version-min=$IOS_DEPLOY_TGT -I$SDKROOT/usr/include/"

    setenv_all
}

setenv_arm64() {
    unset DEVROOT SDKROOT CFLAGS CPP CXXCPP LDFLAGS CPPFLAGS CXXFLAGS

    export SDKROOT=$SDK_IPHONEOS_PATH

    export CFLAGS="-arch arm64 -pipe -no-cpp-precomp -isysroot $SDKROOT -miphoneos-version-min=$IOS_DEPLOY_TGT -I$SDKROOT/usr/include/"

    setenv_all
}

setenv_arm7s() {
    unset DEVROOT SDKROOT CFLAGS CPP CXXCPP LDFLAGS CPPFLAGS CXXFLAGS

    export SDKROOT=$SDK_IPHONEOS_PATH

    export CFLAGS="-arch armv7s -pipe -no-cpp-precomp -isysroot $SDKROOT -miphoneos-version-min=$IOS_DEPLOY_TGT -I$SDKROOT/usr/include/"

    setenv_all
}

setenv_i386() {
    unset DEVROOT SDKROOT CFLAGS CPP CXXCPP LDFLAGS CPPFLAGS CXXFLAGS

    export SDKROOT=$SDK_IPHONESIMULATOR_PATH

    export CFLAGS="-arch i386 -pipe -no-cpp-precomp -isysroot $SDKROOT -miphoneos-version-min=$IOS_DEPLOY_TGT"

    setenv_all
}

for n in "${!archs[@]}"
do
    make clean 2> /dev/null
    make distclean 2> /dev/null
    eval "setenv_${archs[$n]}"
    ./configure --host="${arch_names[$n]}" --enable-shared=no --with-expat=/Users/ryu/git/exiv2-build-script/_expat/ios --disable-nls --prefix=$GLOBAL_OUTDIR/${archs[$n]}
    cd src
    make install-lib -j12
    cd ..
done

mkdir -p Frameworks/exiv2.framework/Headers
cp $GLOBAL_OUTDIR/arm7/include/exiv2/* Frameworks/exiv2.framework/Headers/
libtool $GLOBAL_OUTDIR/*/lib/*.a -o Frameworks/exiv2.framework/exiv2

echo "Finished!"
