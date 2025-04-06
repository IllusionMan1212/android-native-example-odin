#!/bin/bash

## TODO: handle different ABIs, currently only builds for arm64

#ANDROID_JBR=/home/illusion/android-studio/jbr

# Create a debug signing key to sign our application.
if [ ! -f .keystore ]; then
	keytool -genkey -dname "CN=Android Debug, O=Android, C=US" -keystore .keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -validity 30000
	if [ $? -ne 0 ]; then exit 1; fi
fi

# Build the shared lib
odin build . -target:linux_arm64 -subtarget:android -build-mode:shared

# Create the proper lib directories and move the shared lib to them
# Rename the shared lib to match what we specified in the AndroidManifest.xml file
# for the android.app.lib_name metadata value
mkdir -p android/lib/lib/arm64-v8a
mv android-native-example-odin.so android/lib/lib/arm64-v8a/libmain.so

# Bundle the directory into an apk
odin bundle android android -android-keystore:.keystore -android-keystore-password:"android"

cleanup() {
	rm test.apk-build
}

cleanup
