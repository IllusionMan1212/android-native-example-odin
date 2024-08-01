#!/bin/bash

APK=native_example.apk
ANDROID_SDK_ROOT=/home/illusion/Android/Sdk
ANDROID_NDK=$ANDROID_SDK_ROOT/ndk/26.1.10909125
ANDROID_TOOLCHAIN=$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64
ANDROID_JBR=/home/illusion/android-studio/jbr
BUILD_TOOLS=34.0.0

get_package_activity() {
  PACKAGE=$("$ANDROID_SDK_ROOT/build-tools/$BUILD_TOOLS/aapt" dump badging "bin/$APK" | grep package | awk -F"'" '{print $2}')
  ACTIVITY=$("$ANDROID_SDK_ROOT/build-tools/$BUILD_TOOLS/aapt" dump badging "bin/$APK" | grep launchable-activity | awk -F"'" '{print $2}')
}

launch() {
  get_package_activity
  "$ANDROID_SDK_ROOT/platform-tools/adb" shell am start -n "$PACKAGE/$ACTIVITY"
  if [ $? -ne 0 ]; then exit 1; fi
}

launch
