#!/bin/sh

#  Automatic build script for expat
#  for iPhoneOS and iPhoneSimulator
#
#  Created by Felix Schulze on 19.02.12.
#  Copyright 2012 Felix Schulze. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
###########################################################################
#  Change values here													  #
#																		  #
VERSION="2.2.3"                                                           #
SDKVERSION="10.3"                                                          #
MIN_VERSION="10.3"                                                         #
#																		  #
###########################################################################
#																		  #
# Don't change anything under this line!								  #
#																		  #
###########################################################################


CURRENTPATH=`pwd`
ARCHS="i386 x86_64 armv7 armv7s arm64"
DEVELOPER=`xcode-select -print-path`

set -e
if [ ! -e expat-${VERSION}.tar.bz2 ]; then
	echo "Downloading expat-${VERSION}.tar.gz"
    curl -L -O http://sourceforge.net/projects/expat/files/expat/${VERSION}/expat-${VERSION}.tar.bz2
else
	echo "Using expat-${VERSION}.tar.bz2"
fi

mkdir -p "${CURRENTPATH}/src"
mkdir -p "${CURRENTPATH}/bin"
mkdir -p "${CURRENTPATH}/ios/lib"
#mkdir -p "${CURRENTPATH}/ios/framework"

for ARCH in ${ARCHS}
do
	tar jxf expat-${VERSION}.tar.bz2 -C "${CURRENTPATH}/src"
	cd "${CURRENTPATH}/src/expat-${VERSION}"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]];
	then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
	fi

	echo "Building expat-${VERSION} for ${PLATFORM} ${SDKVERSION} ${ARCH}"
	echo "Please stand by..."

	export DEVROOT="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export SDKROOT="${DEVROOT}/SDKs/${PLATFORM}${SDKVERSION}.sdk"

    export LD=${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ld
    export CC=${DEVELOPER}/usr/bin/gcc
    export CXX=${DEVELOPER}/usr/bin/g++

    export AR=${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar
    export AS=${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/as
    export NM=${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/nm
    export RANLIB=${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib

    export LDFLAGS="-arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -L${CURRENTPATH}/lib -miphoneos-version-min=${MIN_VERSION} -fheinous-gnu-extensions"
    export CFLAGS="-arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${CURRENTPATH}/include -miphoneos-version-min=${MIN_VERSION} -fheinous-gnu-extensions"
    export CPPFLAGS="-arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${CURRENTPATH}/include -miphoneos-version-min=${MIN_VERSION} -fheinous-gnu-extensions"
    export CXXFLAGS="-arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${CURRENTPATH}/include -miphoneos-version-min=${MIN_VERSION} -fheinous-gnu-extensions"

    HOST="${ARCH}"
    if [ "${ARCH}" == "arm64" ];
    then
        echo "0-----------------"
        HOST="aarch64"

        echo "Patch..."
        #Patch config.sub to support aarch64
        #patch -R -p0 < "../../config.sub.diff" >> "${LOG}" 2>&1
        #patch -R -p0 < "../../config.sub.diff"

        #Patch readfilemap.c to support aarch64
        perl -i -pe 's|#include <stdio.h>|#include <stdio.h>$/#include <unistd.h>|g' "${CURRENTPATH}/src/expat-${VERSION}/xmlwf/readfilemap.c"
        echo "1-----------------"
    fi

	mkdir -p "${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
	LOG="${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/build-expat-${VERSION}.log"

    echo "Configure..."
	./configure --host="${HOST}-apple-darwin" --prefix="${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk" --disable-shared --enable-static > "${LOG}" 2>&1
    echo "Make..."
    make -j4 >> "${LOG}" 2>&1
    echo "Make install..."
    make install >> "${LOG}" 2>&1
	cd "${CURRENTPATH}"
	rm -rf "${CURRENTPATH}/src/expat-${VERSION}"
    echo "2-----------------"
done
echo "3-----------------"
echo "Build library..."
lipo -create ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-i386.sdk/lib/libexpat.a ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-x86_64.sdk/lib/libexpat.a ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-armv7.sdk/lib/libexpat.a ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-armv7s.sdk/lib/libexpat.a ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-arm64.sdk/lib/libexpat.a -output ${CURRENTPATH}/ios/lib/libexpat.a
lipo -info ${CURRENTPATH}/ios/lib/libexpat.a
mkdir -p ${CURRENTPATH}/ios/include/
cp  ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-i386.sdk/include/expat* ${CURRENTPATH}/ios/include/
echo "Building done."


# echo "Build Framework.."

# FRAMEWORKDIR:=`pwd`/ios/framework
# BUILDDIR:="${CURRENTPATH}/bin"

# VERSION_TYPE=Alpha
# FRAMEWORK_NAME=libexpat
# FRAMEWORK_VERSION=A

# FRAMEWORK_CURRENT_VERSION=$LIB_VERSION
# FRAMEWORK_COMPATIBILITY_VERSION=$LIB_VERSION

# FRAMEWORK_BUNDLE=$FRAMEWORKDIR/$FRAMEWORK_NAME.framework
# echo "Framework: Building $FRAMEWORK_BUNDLE from $BUILDDIR..."

# rm -rf $FRAMEWORK_BUNDLE

# echo "Framework: Setting up directories..."
# mkdir -p $FRAMEWORK_BUNDLE
# mkdir -p $FRAMEWORK_BUNDLE/Versions
# mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION
# mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Resources
# mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Headers
# mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Documentation

# echo "Framework: Creating symlinks..."
# ln -s $FRAMEWORK_VERSION               $FRAMEWORK_BUNDLE/Versions/Current
# ln -s Versions/Current/Headers         $FRAMEWORK_BUNDLE/Headers
# ln -s Versions/Current/Resources       $FRAMEWORK_BUNDLE/Resources
# ln -s Versions/Current/Documentation   $FRAMEWORK_BUNDLE/Documentation
# ln -s Versions/Current/$FRAMEWORK_NAME $FRAMEWORK_BUNDLE/$FRAMEWORK_NAME

# FRAMEWORK_INSTALL_NAME=$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME

# #echo "Lipoing library into $FRAMEWORK_INSTALL_NAME..."
# #$ARM_DEV_CMD lipo -create $BUILDDIR/*/lib/libexpat.a -o "$FRAMEWORK_INSTALL_NAME" || abort "Lipo $1 failed"

# echo "Framework: Copying includes..."
# cp -r $BUILDDIR/*/include/*  $FRAMEWORK_BUNDLE/Headers/

# echo "Framework: Creating plist..."
# cat > $FRAMEWORK_BUNDLE/Resources/Info.plist <<EOF
# <?xml version="1.0" encoding="UTF-8"?>
# <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
# <plist version="1.0">
# <dict>
# <key>CFBundleDevelopmentRegion</key>
# <string>English</string>
# <key>CFBundleExecutable</key>
# <string>${FRAMEWORK_NAME}</string>
# <key>CFBundleIdentifier</key>
# <string>io.github.libexpat</string>
# <key>CFBundleInfoDictionaryVersion</key>
# <string>6.0</string>
# <key>CFBundlePackageType</key>
# <string>FMWK</string>
# <key>CFBundleSignature</key>
# <string>????</string>
# <key>CFBundleVersion</key>
# <string>${FRAMEWORK_CURRENT_VERSION}</string>
# </dict>
# </plist>
# EOF


echo "Done."
