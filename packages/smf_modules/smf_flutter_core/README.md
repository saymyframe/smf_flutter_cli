# smf_flutter_core

The SMF module that creates the Flutter app every SMF app starts from. It provides the app entry role of SMF, which every app has exactly one provider of:

- the Android and iOS projects of `flutter create`;
- `lib/main.dart`, whose `main()` awaits `bootstrap()` and runs the root widget inside the wrappers of other modules;
- `lib/bootstrap.dart`, where modules put their start-up code, phase by phase;
- `lib/app.dart`, the root `MaterialApp`, which becomes `MaterialApp.router` when the app has a router;
- the fallback start screen, which an app shows while it has no screen to start on, with a widget test;
- `pubspec.yaml` with the dependencies of all modules, and `analysis_options.yaml`, which leaves `build/` out of the analysis.

The fallback start screen is for the developer of the app. It shows a cell with a symbol and a number made from the name of the app, the name itself, a hint that the app has no start screen yet, and the path of its own file, which a tap copies. An app with a feature whose route can start the app never shows it. The hint and the word that confirms the copy are in English and in Ukrainian. In an app with a module for the languages of the app, such as `gen_l10n`, the screen reads them from the texts of the app; in any other app they are in English.

The app runs on iOS 15 or newer. For iOS builds with Xcode 27, use Flutter 3.47 or newer; see [troubleshooting](https://doc.saymyframe.com/guides/troubleshooting#ios-builds-with-xcode-27).

## Use with the SMF CLI

Every app needs a module that provides the app entry role. While this is the only one, `smf create` adds it to every app by itself.

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Updating the Flutter template

The files in `bricks/flutter_core/__brick__` are those that `flutter create --platforms=android,ios --org com.example --no-pub my_app` writes with Flutter 3.44.2, with these changes:

- The names and ids come from the app. `android:label` and `CFBundleDisplayName` are its name in title case, and `CFBundleName` in Pascal case. The Android namespace, application id and Kotlin package path, and the iOS bundle id are variables of the brick.
- `IPHONEOS_DEPLOYMENT_TARGET`, in each build configuration of `project.pbxproj`, is the tag of the minimum iOS version, and the project has no `DEVELOPMENT_TEAM`.
- The Android manifest, `Info.plist` and the Gradle files hold the tags of the native sockets of the app entry role, each alone on its line.
- `lib/`, `test/`, `pubspec.yaml`, `README.md` and `analysis_options.yaml` are SMF's own.

`gradlew`, `gradle-wrapper.jar`, `local.properties`, `.idea/` and the `.iml` files are left out: Flutter writes the Gradle wrapper when it builds the app, and the rest belongs to one machine.

To move to a newer Flutter:

1. Run `flutter create` as above with it.
2. Copy every file it writes over those of the brick, but for the files that SMF owns or leaves out. The files to copy include `.metadata`, which names the commit of Flutter, and both `.gitignore` files.
3. Make the changes above again.
4. Compare `pubspec.yaml` and `analysis_options.yaml` of the new app with the brick's. Their SDK constraint, the version of `flutter_lints` and the lints follow Flutter's template, but no test compares these files. The brick's `analysis_options.yaml` keeps leaving `build/` out.
5. Update the minimum Flutter and iOS versions of `FlutterCoreModule`, and the Flutter of the CI workflow with the SHA-256 of its archive.
6. Bundle the bricks with `melos bootstrap`.

`test/flutter_create_test.dart` compares the brick with the app of `flutter create`, allowing only the changes above, and fails when Flutter asks for a later iOS than the brick. It runs when `SMF_FLUTTER_CREATE_APP` names that app, as the CI job `Generated apps (real)` does with the Flutter it pins:

```bash
flutter create --platforms=android,ios --org com.example --no-pub my_app
SMF_FLUTTER_CREATE_APP=$PWD/my_app dart test test/flutter_create_test.dart
```

## Documentation

- [The flutter_core module](https://doc.saymyframe.com/modules/flutter-core)
- [The generated app](https://doc.saymyframe.com/getting-started/generated-app)
