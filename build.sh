#!/bin/bash

# Create a debug signing key to sign our application.
if [ ! -f .keystore ]; then
	keytool -genkey -dname "CN=Android Debug, O=Android, C=US" -keystore .keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -validity 30000
	if [ $? -ne 0 ]; then exit 1; fi
fi

# Build the shared lib
if [[ $1 == "release" ]]; then
	odin build . -target:linux_arm64 -subtarget:android -build-mode:shared -o:speed -define:RELEASE_BUILD=true
else
	odin build . -target:linux_arm64 -subtarget:android -build-mode:shared -debug -show-system-calls
fi

name=$(basename "$PWD")

# Create the proper lib directories and move the shared lib to them
# Rename the shared lib to match what we specified in the AndroidManifest.xml file
# for the android.app.lib_name metadata value
mkdir -p android/lib/lib/arm64-v8a
mv $name.so android/lib/lib/arm64-v8a/libmain.so || exit 1

# Bundle the directory into an apk
odin bundle android android -android-keystore:.keystore -android-keystore-password:"android"

cleanup() {
	rm test.apk-build
}

cleanup
