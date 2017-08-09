# Builds a Exiv2 framework for the iPhone and the iPhone Simulator.
# Creates a set of universal libraries that can be used on an iPhone and in the
# iPhone simulator. Then creates a pseudo-framework to make using libexiv2 in Xcode
# less painful.
#
# To configure the script, define:
#    IPHONE_SDKVERSION: iPhone SDK version (e.g. 8.1)
#
# Then go get the source tar.bz of the libexiv2 you want to build, shove it in the
# same directory as this script, and run "./libexiv2.sh". Grab a cuppa. And voila.
#===============================================================================

: ${LIB_VERSION:=0.26}

# Current iPhone SDK
: ${IPHONE_SDKVERSION:=`xcodebuild -showsdks | grep iphoneos | egrep "[[:digit:]]+\.[[:digit:]]+" -o | tail -1`}
# Specific iPhone SDK
# : ${IPHONE_SDKVERSION:=8.1}

: ${XCODE_ROOT:=`xcode-select -print-path`}

: ${TARBALLDIR:=`pwd`}
: ${SRCDIR:=`pwd`/src}
: ${IOSBUILDDIR:=`pwd`/ios/build}
: ${OSXBUILDDIR:=`pwd`/osx/build}
: ${PREFIXDIR:=`pwd`/ios/prefix}
: ${IOSFRAMEWORKDIR:=`pwd`/ios/framework}
: ${OSXFRAMEWORKDIR:=`pwd`/osx/framework}

LIB_TARBALL=$TARBALLDIR/exiv2-$LIB_VERSION.tar.gz
LIB_SRC=$SRCDIR/exiv2-trunk

#===============================================================================
ARM_DEV_CMD="xcrun --sdk iphoneos"
SIM_DEV_CMD="xcrun --sdk iphonesimulator"

#===============================================================================
# Functions
#===============================================================================

abort()
{
    echo
    echo "Aborted: $@"
    exit 1
}

doneSection()
{
    echo
    echo "================================================================="
    echo "Done"
    echo
}

#===============================================================================

cleanEverythingReadyToStart()
{
    echo Cleaning everything before we start to build...

    rm -rf iphone-build iphonesim-build
    rm -rf $IOSBUILDDIR
    rm -rf $PREFIXDIR
    rm -rf $IOSFRAMEWORKDIR/$FRAMEWORK_NAME.framework

    doneSection
}

#===============================================================================

downloadExiv2()
{
    if [ ! -s $LIB_TARBALL ]; then
        echo "Downloading libexiv2 ${LIB_VERSION}"
        curl -L -o $LIB_TARBALL http://www.exiv2.org/builds/exiv2-${LIB_VERSION}-trunk.tar.gz
    fi

    doneSection
}

#===============================================================================

unpackExiv2()
{
    [ -f "$LIB_TARBALL" ] || abort "Source tarball missing."

    echo Unpacking libexiv2 into $SRCDIR...

    [ -d $SRCDIR ]    || mkdir -p $SRCDIR
    [ -d $LIB_SRC ] || ( cd $SRCDIR; tar xfj $LIB_TARBALL )
    [ -d $LIB_SRC ] && echo "    ...unpacked as $LIB_SRC"

    doneSection
}

#===============================================================================

buildExiv2ForIPhoneOS()
{
    export CC=$XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang
    export CC_BASENAME=clang

    export CXX=$XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++
    export CXX_BASENAME=clang++

    # avoid the `LDFLAGS` env to include the homebrew Cellar
    export LDFLAGS=""

    # C preprocessor
    export CPP=$XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/cpp

    # Ensure that the zlib project has been created in the right path an compiled
    ZLIB_TARBALL_DIR=$TARBALLDIR/../_zlib
    if [ ! -s $ZLIB_TARBALL_DIR ]; then
        echo " !!! You need to create the directory $ZLIB_TARBALL_DIR and put the `libz.sh` script in it"
        exit 1
    fi
    ZLIB_PREFIX_DIR=$ZLIB_TARBALL_DIR/ios/prefix
    if [ ! -s $ZLIB_PREFIX_DIR ]; then
        echo " !!! You need to run the `libz.sh` script in $ZLIB_TARBALL_DIR"
        exit 1
    fi

    EXPAT_DIR=$TARBALLDIR/../_expat

    cd $LIB_SRC

    # echo Building Exiv2 for iPhoneSimulator
    # export CXXFLAGS="-O3 -arch i386 -arch x86_64 -isysroot $XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator${IPHONE_SDKVERSION}.sdk -mios-simulator-version-min=${IPHONE_SDKVERSION} -Wno-error-implicit-function-declaration"
    # export CPPFLAGS=""
    # export LDFLAGS="-arch i386 -arch x86_64 -isysroot $XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator${IPHONE_SDKVERSION}.sdk -mios-simulator-version-min=${IPHONE_SDKVERSION}"
    # make distclean
    # ./configure --host=x86_64-apple-darwin --prefix=$PREFIXDIR/iphonesim-build --disable-dependency-tracking --enable-static=yes --enable-shared=no --disable-dependency-tracking --enable-commercial --disable-nls --disable-lensdata --with-expat=$EXPAT_DIR --without-libiconv-prefix --without-zlib # --with-zlib=$ZLIB_PREFIX_DIR/iphonesim-build --disable-xmp
    # make
    # make install
    # doneSection

    echo Building Exiv2 for iPhone
    export CXXFLAGS="-O3 -arch armv7 -arch armv7s -arch arm64 -isysroot $XCODE_ROOT/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS${IPHONE_SDKVERSION}.sdk -mios-version-min=${IPHONE_SDKVERSION}"
    export CPPFLAGS=""
    export CPP="$(xcrun --sdk iphoneos -f cc) -E -D __arm__=1"
    export LDFLAGS="-arch armv7 -arch armv7s -arch arm64 -isysroot $XCODE_ROOT/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS${IPHONE_SDKVERSION}.sdk -mios-version-min=${IPHONE_SDKVERSION}"
    make clean
    make distclean
    ./configure --host=arm-apple-darwin --prefix=$PREFIXDIR/iphone-build --disable-dependency-tracking --enable-static=yes --enable-shared=no --disable-dependency-tracking --enable-commercial --disable-nls --disable-lensdata --with-expat=$EXPAT_DIR --without-libiconv-prefix --without-zlib # --with-zlib=$ZLIB_PREFIX_DIR/iphone-build --disable-xmp
    make
    make install
    doneSection
}

#===============================================================================

scrunchAllLibsTogetherInOneLibPerPlatform()
{
    cd $PREFIXDIR

    # iOS Device
    mkdir -p $IOSBUILDDIR/armv7
    mkdir -p $IOSBUILDDIR/armv7s
    mkdir -p $IOSBUILDDIR/arm64

    # iOS Simulator
    mkdir -p $IOSBUILDDIR/i386
    mkdir -p $IOSBUILDDIR/x86_64

    echo Splitting all existing fat binaries...

    $ARM_DEV_CMD lipo "iphone-build/lib/libexiv2.a" -thin armv7 -o $IOSBUILDDIR/armv7/libexiv2.a
    $ARM_DEV_CMD lipo "iphone-build/lib/libexiv2.a" -thin armv7s -o $IOSBUILDDIR/armv7s/libexiv2.a
    $ARM_DEV_CMD lipo "iphone-build/lib/libexiv2.a" -thin arm64 -o $IOSBUILDDIR/arm64/libexiv2.a

    $SIM_DEV_CMD lipo "iphonesim-build/lib/libexiv2.a" -thin i386 -o $IOSBUILDDIR/i386/libexiv2.a
    $SIM_DEV_CMD lipo "iphonesim-build/lib/libexiv2.a" -thin x86_64 -o $IOSBUILDDIR/x86_64/libexiv2.a
}

#===============================================================================
buildFramework()
{
    : ${1:?}
    FRAMEWORKDIR=$1
    BUILDDIR=$2

    VERSION_TYPE=Alpha
    FRAMEWORK_NAME=exiv2
    FRAMEWORK_VERSION=A

    FRAMEWORK_CURRENT_VERSION=$LIB_VERSION
    FRAMEWORK_COMPATIBILITY_VERSION=$LIB_VERSION

    FRAMEWORK_BUNDLE=$FRAMEWORKDIR/$FRAMEWORK_NAME.framework
    echo "Framework: Building $FRAMEWORK_BUNDLE from $BUILDDIR..."

    rm -rf $FRAMEWORK_BUNDLE

    echo "Framework: Setting up directories..."
    mkdir -p $FRAMEWORK_BUNDLE
    mkdir -p $FRAMEWORK_BUNDLE/Versions
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Resources
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Headers
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Documentation

    echo "Framework: Creating symlinks..."
    ln -s $FRAMEWORK_VERSION               $FRAMEWORK_BUNDLE/Versions/Current
    ln -s Versions/Current/Headers         $FRAMEWORK_BUNDLE/Headers
    ln -s Versions/Current/Resources       $FRAMEWORK_BUNDLE/Resources
    ln -s Versions/Current/Documentation   $FRAMEWORK_BUNDLE/Documentation
    ln -s Versions/Current/$FRAMEWORK_NAME $FRAMEWORK_BUNDLE/$FRAMEWORK_NAME

    FRAMEWORK_INSTALL_NAME=$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME

    echo "Lipoing library into $FRAMEWORK_INSTALL_NAME..."
    $ARM_DEV_CMD lipo -create $BUILDDIR/*/libexiv2.a -o "$FRAMEWORK_INSTALL_NAME" || abort "Lipo $1 failed"

    echo "Framework: Copying includes..."
    cp -r $PREFIXDIR/iphone-build/include/exiv2/*  $FRAMEWORK_BUNDLE/Headers/

    echo "Framework: Creating plist..."
    cat > $FRAMEWORK_BUNDLE/Resources/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>CFBundleDevelopmentRegion</key>
<string>English</string>
<key>CFBundleExecutable</key>
<string>${FRAMEWORK_NAME}</string>
<key>CFBundleIdentifier</key>
<string>org.libexiv2</string>
<key>CFBundleInfoDictionaryVersion</key>
<string>6.0</string>
<key>CFBundlePackageType</key>
<string>FMWK</string>
<key>CFBundleSignature</key>
<string>????</string>
<key>CFBundleVersion</key>
<string>${FRAMEWORK_CURRENT_VERSION}</string>
</dict>
</plist>
EOF

    doneSection
}

#===============================================================================
# Execution starts here
#===============================================================================

mkdir -p $IOSBUILDDIR

# cleanEverythingReadyToStart #may want to comment if repeatedly running during dev

echo "LIB_VERSION:       $LIB_VERSION"
echo "LIB_SRC:           $LIB_SRC"
echo "IOSBUILDDIR:       $IOSBUILDDIR"
echo "PREFIXDIR:         $PREFIXDIR"
echo "IOSFRAMEWORKDIR:   $IOSFRAMEWORKDIR"
echo "IPHONE_SDKVERSION: $IPHONE_SDKVERSION"
echo "XCODE_ROOT:        $XCODE_ROOT"
echo

downloadExiv2
unpackExiv2
buildExiv2ForIPhoneOS
scrunchAllLibsTogetherInOneLibPerPlatform
buildFramework $IOSFRAMEWORKDIR $IOSBUILDDIR

echo "Completed successfully"

#===============================================================================
