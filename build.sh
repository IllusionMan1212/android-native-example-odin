#!/bin/bash

## TODO: handle different ABIs, currently only builds for arm64

APK=native_example.apk
ANDROID_SDK_ROOT=/home/illusion/Android/Sdk
ANDROID_NDK=$ANDROID_SDK_ROOT/ndk/26.1.10909125
ANDROID_TOOLCHAIN=$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64
ANDROID_JBR=/home/illusion/android-studio/jbr
BUILD_TOOLS=34.0.0
PLATFORM=34

# Create required dirs
mkdir -p lib/lib/arm64-v8a
mkdir -p bin

# Compile the glue code that comes with the NDK to an object using the aarch64 crosscompiler.
$ANDROID_TOOLCHAIN/bin/aarch64-linux-android24-clang -c $ANDROID_NDK/sources/android/native_app_glue/android_native_app_glue.c  -o android_native_app_glue.o -I $ANDROID_TOOLCHAIN/sysroot/usr/include/

# Create a static lib from the glue code object
$ANDROID_TOOLCHAIN/bin/llvm-ar rcs libandroid_native_app_glue.a android_native_app_glue.o

# Compile our odin code to an object. relocation mode is set to PIC because the linker complains.
# freestanding_arm64 should probably be preferred but raylib projects need linux_arm64, otherwise the android dynamic linker fails to find our main function.
odin build jni/ -build-mode:obj -target:linux_arm64 -reloc-mode:pic || exit 1

# Link the static library with our object and create the shared library that will hold all our native code.
## We pass "-u ANativeActivity_onCreate" to the linker here because that symbol gets stripped by the linker even though it's required
## This is exactly what the official ndk-build building process does, see: https://github.com/android/ndk/issues/381
$ANDROID_TOOLCHAIN/bin/aarch64-linux-android24-clang -shared -o libmain.so jni.o libandroid_native_app_glue.a -L $ANDROID_TOOLCHAIN/sysroot/usr/lib/aarch64-linux-android/$PLATFORM/ -landroid -llog -lEGL -lGLESv3 -u ANativeActivity_onCreate 

# Move the shared lib to the lib directory
cp libmain.so lib/lib/arm64-v8a

# Pack the assets of the app using a basic android jar that comes with the SDK
## If there are asset files that need to be loaded during runtime then they should be put in an `assets` directory
## and "-A assets" should be appended after the -I option.
$ANDROID_SDK_ROOT/build-tools/$BUILD_TOOLS/aapt package -f -M AndroidManifest.xml -S res -I $ANDROID_SDK_ROOT/platforms/android-$PLATFORM/android.jar -A assets -F "bin/$APK.build" lib

# Create a debug signing key to sign our application.
if [ ! -f .keystore ]; then
	"$ANDROID_JBR/bin/keytool" -genkey -dname "CN=Android Debug, O=Android, C=US" -keystore .keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -validity 30000
	if [ $? -ne 0 ]; then exit 1; fi
fi

# Sign the jar
$ANDROID_JBR/bin/jarsigner -storepass android -keystore .keystore "bin/$APK.build" androiddebugkey > /dev/null

# Make it into an apk
$ANDROID_SDK_ROOT/build-tools/$BUILD_TOOLS/zipalign -f 4 "bin/$APK.build" "bin/$APK"


cleanup() {
	rm jni.o android_native_app_glue.o libandroid_native_app_glue.a bin/$APK.build
}

cleanup
