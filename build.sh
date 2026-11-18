#!/bin/bash

# Create a debug signing key to sign our application.
if [ ! -f .keystore ]; then
	keytool -genkey -dname "CN=Android Debug, O=Android, C=US" -keystore .keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -validity 30000
	if [ $? -ne 0 ]; then exit 1; fi
fi

# Build the shared lib
if [[ $1 == "release" ]]; then
	odin build . -target:linux_arm64 -subtarget:android -build-mode:shared -o:speed -define:RELEASE_BUILD=true -out:lib/arm64-v8a/libmain.so
else
	odin build . -target:linux_arm64 -subtarget:android -build-mode:shared -debug -show-system-calls -out:lib/arm64-v8a/libmain.so
fi

name=$(basename "$PWD")

# Bundle the directory into an apk
odin bundle android . -android-keystore:.keystore -android-keystore-password:"android"

cleanup() {
	rm test.apk-build
}

cleanup
