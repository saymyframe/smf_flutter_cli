# smf_firebase_core

The SMF module of [Firebase](https://firebase.google.com/docs/flutter/setup) for the Flutter app that SMF generates. It sets up [firebase_core](https://pub.dev/packages/firebase_core), which the other Firebase packages of an app build on.

The module:

- adds `firebase_core` to the dependencies of the app;
- adds `lib/firebase_options.dart` with `DefaultFirebaseOptions`, the options of the Firebase app of each platform;
- makes `bootstrap()`, which runs before the app starts, initialize Firebase with the options of the platform that runs the app: `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);`, among the platform services, before the services of the app;
- raises the minimum iOS version of the app to 15.0, the lowest that the Firebase SDKs support.

`flutterfire configure` of the [FlutterFire CLI](https://pub.dev/packages/flutterfire_cli) registers the app in a Firebase project and writes its options. Until it runs, `lib/firebase_options.dart` is a placeholder: the file that flutterfire_cli 1.4 writes for an app with no platform configured, where each platform throws an `UnsupportedError`, so the app compiles but stops at start-up. The FlutterFire CLI fills the placeholder in place.

## The machine

Before it generates the app, SMF checks that the machine can run `flutterfire configure`:

- the [Firebase CLI](https://firebase.google.com/docs/cli), which the FlutterFire CLI runs to reach the Firebase projects;
- a login of the Firebase CLI, which `firebase login:list --json` reports. `firebase login` waits for the browser to come back to a server on the machine, so on a remote machine, such as over SSH, log in with `firebase login --no-localhost` instead;
- the FlutterFire CLI in version 1.4.1 or a later 1.x, activated globally, as `dart pub global activate flutterfire_cli 1.4.1` does. For an app with Crashlytics, the FlutterFire CLI adds a build phase to the Xcode project that uploads the debug symbols. The phase of 1.4.0 does not find the upload script of Crashlytics where Flutter puts the Swift packages of the app, so with Swift Package Manager `flutter run` and `flutter build ios` fail in that phase. The tests of this module repeat the changes that 1.4.1 makes to the Gradle files and the options of the app; a later 1.x that is active already is used as it is;
- on macOS, the Ruby gem xcodeproj 1.23.0 or newer, with which the FlutterFire CLI sets up the iOS app in its Xcode project; without it, `flutterfire configure` fails there after it registered the apps, before it writes the options. It does that only on macOS: elsewhere it registers the iOS app and writes its options, but leaves the Xcode project as it is, without the build phases that it adds for some Firebase packages, such as the upload of the debug symbols of Crashlytics, so SMF warns to run `flutterfire configure` again on a Mac.

The app compiles without any of them, so a missing one only brings a warning with instructions. In a run with a terminal, unless it skips external setup (`--skip-external-setup`), SMF offers to install the Firebase CLI with npm, and Node.js first when it is missing or older than 20, to log in with `firebase login`, and to activate flutterfire_cli 1.4.1 when no version or an older one is active, but never in place of a newer major version, which other apps may need; it asks before each. When npm fails on macOS or Linux, it offers the standalone binary of the Firebase CLI instead.

The installation of the Firebase CLI can take minutes, and its progress shows what it is doing. It may install Node.js with Homebrew or nvm on macOS, with nvm on Linux, and with winget, Chocolatey, Scoop or its portable ZIP on Windows. It adds the directory of the Firebase CLI to the PATH of new terminals when it is not there yet: in the profile of the shell, or on Windows in the PATH of the user. On Linux, it also moves the global directory of npm to `~/.npm-global`, so that it needs no sudo, and adds a `firebase` command to `~/.local/bin`. SMF lists these changes after the installation.

## After generation

Once the app has its packages, SMF runs `flutterfire configure --platforms=android,ios --overwrite-firebase-options` in it, through `dart pub global run flutterfire_cli:flutterfire`, with the terminal: it asks for the Firebase project and writes the options into `lib/firebase_options.dart`. It asks first, so you can leave it for later. A run without a terminal, or that skips external setup, prints the command to run later instead, and so does a run that lacks the Firebase CLI, the login, the FlutterFire CLI or, on macOS, the gem xcodeproj, without asking, since `flutterfire configure` would fail without them.

The command also gives flutterfire the ids of the Android and iOS apps, with `--android-package-name` and `--ios-bundle-id`. flutterfire reads the bundle id from the Xcode project only when it is not in quotes, and saves the project with the Ruby gem xcodeproj, which puts a bundle id with a hyphen, such as `com.example.my-app`, in quotes, so configuring the app again would ask for it. An id that flutterfire would not take in an option, such as an application id with an underscore in its first part, is left out, for flutterfire to read.

Right after `flutterfire configure`, on macOS, SMF fixes the phase for Crashlytics that flutterfire_cli 1.4.1 adds to the Xcode project of an app with Crashlytics, so that `flutter build ipa` finds the upload script of Crashlytics too. The phase looks for the script in `$BUILD_DIR/SourcePackages`, among the Swift packages in the build directory of Xcode. `flutter run` and `flutter build ios` set that directory to `build/ios`, where Flutter puts the Swift packages, but `flutter build ipa` does not, since Xcode would not copy the debug symbols into the archive then, so the archive fails in that phase. With Ruby, SMF replaces the path in the Xcode project with `$SRCROOT/../build/ios/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run`, the same place for the other builds, and changes nothing else: an app without the phase, or with a phase without that path, stays as it is. The fix is part of the configuration, so when `flutterfire configure` does not run or fails, the fix waits with it, and SMF prints its command after that of `flutterfire configure`; elsewhere than on macOS, where flutterfire adds no phase, it waits for a Mac. `flutterfire configure` writes the phase again each time, so the README of the app gives the command to run after it.

If an older flutterfire_cli, such as 1.4.0, configured an app with Crashlytics, the app keeps the phase of that version in its Xcode project, so with Swift Package Manager `flutter run` and `flutter build ios` fail even after 1.4.1 is activated. To replace the phase, activate 1.4.1 and configure the app again on a Mac, in its directory:

```bash
dart pub global activate flutterfire_cli 1.4.1
flutterfire configure --platforms=android,ios --overwrite-firebase-options
```

Then, for `flutter build ipa`, fix the new phase with the command of the README of the app.

The README of the app gets a section on Firebase: how to configure the app again, such as for another Firebase project or on another machine, with flutterfire_cli 1.4.1 or a later 1.x, that the build phases that the FlutterFire CLI adds to the Xcode project for some Firebase packages, such as the upload of the debug symbols of Crashlytics, run `flutterfire` from `~/.pub-cache/bin`, and how to fix the phase for Crashlytics after `flutterfire configure` for `flutter build ipa`.

## Use with SMF CLI

`smf create` asks which infrastructure modules the app has, and offers this one. To choose it without the question, name it with `-m`:

```bash
smf create my_app -m firebase_core
```

This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_firebase_core) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
