/// The section of the README of the app on where its flavors are in the
/// native projects, for a developer who renames, adds or removes one.
const flavorProjectsSection = '''
Each flavor is in two places, so change both when you rename, add or remove one:

- Android: `productFlavors` in `android/app/build.gradle.kts`, with its id suffix and its name on the device.
- iOS: `ios/Runner.xcodeproj/xcshareddata/xcschemes/<flavor>.xcscheme`, and the build configurations `Debug-<flavor>`, `Profile-<flavor>` and `Release-<flavor>` in each configuration list of `ios/Runner.xcodeproj/project.pbxproj`. The name of a flavor has no hyphen, since Flutter splits the name of a configuration on it.

In Xcode, select the scheme of a flavor, not `Runner`. The scheme of a flavor builds that flavor, with its id, its name and its `appFlavor`. `Runner` builds the id and the name of `prod`, and takes `appFlavor` from `ios/Flutter/Generated.xcconfig`, which the last `flutter` command wrote. `flutter build ios --config-only --flavor <flavor>` gives that file a flavor.''';
