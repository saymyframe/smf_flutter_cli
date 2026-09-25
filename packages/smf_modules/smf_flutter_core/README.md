# smf_flutter_core

The module that creates the Flutter app every SMF app starts from. It provides the app entry role of the SMF module model:

- the Android and iOS projects of `flutter create`;
- `lib/main.dart`, whose `main()` awaits `bootstrap()` and runs the root widget inside the wrappers of other modules;
- `lib/bootstrap.dart`, where modules put their start-up code, phase by phase;
- `lib/app.dart`, the root `MaterialApp`, which becomes `MaterialApp.router` when a router module is present;
- a fallback start screen with a widget test;
- `pubspec.yaml` with the dependencies of all modules.

The app needs Flutter 3.44 or newer, and runs on iOS 15 or newer.

## Flutter and Xcode

Xcode 27 builds only for iOS 15 and newer, which Flutter follows from version 3.47. With Flutter 3.44 and Xcode 27:

- `flutter build ios --simulator` fails in `debug_unpack_ios`: Flutter passes both architectures of the simulator to `lipo -verify_arch`, which takes one in Xcode 27. Build for the architecture of your Mac, as in `FLUTTER_XCODE_ARCHS=arm64 flutter build ios --simulator`.
- A plugin that installs with CocoaPods and asks for iOS 13 or 14 keeps that version, which Xcode 27 refuses; Flutter 3.47 raises it to the version of the app.

So for iOS builds with Xcode 27, use Flutter 3.47 or newer.

## Use with SMF CLI
This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## Updating the Flutter template

The files in `bricks/flutter_core/__brick__` are those that `flutter create --platforms=android,ios --org com.example my_app` writes with Flutter 3.44.2, with these changes:

- The names and ids come from the app. `android:label` and `CFBundleDisplayName` are its name in title case, and `CFBundleName` in Pascal case. The Android namespace, application id and Kotlin package path, and the iOS bundle id are variables of the brick.
- `IPHONEOS_DEPLOYMENT_TARGET`, in each build configuration of `project.pbxproj`, is the tag of the minimum iOS version, and the project has no `DEVELOPMENT_TEAM`.
- The Android manifest, `Info.plist` and the Gradle files hold the tags of the native sockets of the app entry role, each alone on its line.
- `lib/`, `test/`, `pubspec.yaml`, `README.md` and `analysis_options.yaml` are SMF's own.

`gradlew`, `gradle-wrapper.jar`, `local.properties`, `.idea/` and the `.iml` files are left out: Flutter writes the Gradle wrapper when it builds the app, and the rest belongs to one machine.

To move to a newer Flutter, run `flutter create` with it, copy its native files over these, make the changes above again, update the minimum Flutter and iOS versions of `FlutterCoreModule`, and bundle the bricks with `melos bootstrap`.

`test/flutter_create_test.dart` compares the brick with the app of `flutter create`, allowing only the changes above. It runs when `SMF_FLUTTER_CREATE_APP` names that app, as the Flutter job of CI does with the Flutter it pins:

```bash
flutter create --platforms=android,ios --org com.example my_app
SMF_FLUTTER_CREATE_APP=$PWD/my_app dart test test/flutter_create_test.dart
```

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_flutter_core) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
