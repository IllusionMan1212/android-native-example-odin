This is a basic Android native example written completely in Odin. It adapts and rewrites mmozeiko's [C example](https://github.com/mmozeiko/android-native-example) to work with Odin.

This requires that you write some basic bindings to the Android NDK (or use mine https://github.com/illusionman1212/ndk-odin) in order to compile and run.

# Building

First you must adjust `build.sh` and `launch.sh` to have correct paths to Android SDK, Android NDK and the Jetbrains RT.
Then set `APK` variable to the desired apk package name. Use Android SDK to install build-tools and platform SDK. 

Now you can use `build.sh` to build and install the app, and `launch.sh` to run the application:

# License
The code is licensed under the Unlicense license. I do not own the app icon (Odin logo). The logo copyright is owned by [GingerBill](https://github.com/gingerbill)
