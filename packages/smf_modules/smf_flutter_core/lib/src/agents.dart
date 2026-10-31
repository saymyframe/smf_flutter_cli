/// The note of the module in the guide for coding agents of the app, in the
/// section of the app entry: what its files add to what the role says.
const agentNote = '''
After a change, run:

```bash
dart format lib test
flutter analyze
flutter test
```

Format only `lib/` and `test/`: `dart format .` also formats what Flutter writes into `build/`. The app as generated is formatted, `flutter analyze` finds no issue in it and `flutter test` passes.

- `App` in `lib/app.dart` is the root widget of the app and creates its one `MaterialApp`. Create no other in `lib/`: every screen is below it.
- The `theme`, `darkTheme`, `themeMode`, `locale` and localizations of the app go into the arguments of that `MaterialApp`.
- Tests mirror `lib/`: the test of `lib/<path>.dart` is `test/<path>_test.dart`.
- The app has only an Android and an iOS project, in `android/` and `ios/`.
- The entitlements of the iOS app, such as Push Notifications or Sign in with Apple, are in `ios/Runner/Runner.entitlements`. Every build configuration of the Runner target signs with this file, even while it is empty. The Signing & Capabilities tab of Xcode edits the same file.
- Each flavor is in `productFlavors` of `android/app/build.gradle.kts`, and on iOS in `ios/Runner.xcodeproj/xcshareddata/xcschemes/<flavor>.xcscheme` and in the build configurations `Debug-<flavor>`, `Profile-<flavor>` and `Release-<flavor>` of `ios/Runner.xcodeproj/project.pbxproj`. Change both places together. A new setting of the Runner target goes into each of its twelve build configurations.
''';
