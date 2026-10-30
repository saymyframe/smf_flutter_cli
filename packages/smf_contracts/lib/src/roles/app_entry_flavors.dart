part of 'app_entry.dart';

/// The modes of a build, each of which has an Xcode build configuration for
/// each flavor.
const _xcodeModes = ['Debug', 'Profile', 'Release'];

/// A native flavor of the app, one of [AppEntryRole.flavors].
///
/// The flavors of an app install next to each other on a device, each under
/// an id of its own. The role publishes them, so modules, other roles and
/// tools read their names and ids from here and know nothing of the native
/// projects of the provider.
@immutable
final class AppFlavor {
  const AppFlavor._(this.name, {this.idSuffix = ''});

  /// The name that `--flavor` of the `flutter` tool takes, such as `dev`,
  /// which is also the name of the Xcode scheme of the flavor.
  ///
  /// It has no hyphen, since Flutter splits the name of a build configuration
  /// on it to find the flavor.
  final String name;

  /// What the id of the flavor adds to the id of the app, such as `.dev`,
  /// and empty for the flavor that has the id of the app itself.
  final String idSuffix;

  /// The Android application id of this flavor of the app with [identity].
  String applicationIdIn(AppIdentity identity) =>
      '${identity.androidApplicationId}$idSuffix';

  /// The iOS bundle id of this flavor of the app with [identity].
  String bundleIdIn(AppIdentity identity) => '${identity.iosBundleId}$idSuffix';

  /// The Xcode build configurations of this flavor, one for each mode of a
  /// build, such as `Debug-dev`. Flutter finds the configuration of a build
  /// by this form of the name.
  List<String> get xcodeConfigurations => [
        for (final mode in _xcodeModes) '$mode-$name',
      ];

  /// The path of the shared Xcode scheme of this flavor, which
  /// `flutter build ios --flavor` selects by its name.
  String get xcodeSchemeFile =>
      'ios/Runner.xcodeproj/xcshareddata/xcschemes/$name.xcscheme';
}

/// The flavor for development; see [AppEntryRole.defaultFlavor].
const _devFlavor = AppFlavor._('dev', idSuffix: '.dev');

/// The flavor for testing a build before it reaches the stores.
const _stagingFlavor = AppFlavor._('staging', idSuffix: '.staging');

/// The flavor that users get; see [AppEntryRole.releaseFlavor].
const _prodFlavor = AppFlavor._('prod');

/// The section [AppEntryRole.flavorsHeading] of the README of the app with
/// [identity]: the id of each flavor, what a command without `--flavor`
/// builds, and how a build for a store names its flavor.
String _flavorsSection(AppIdentity identity) {
  const fallback = AppEntryRole.defaultFlavor;
  const release = AppEntryRole.releaseFlavor;
  String rowOf(AppFlavor flavor) => '| `${flavor.name}` '
      '| `${flavor.applicationIdIn(identity)}` '
      '| `${flavor.bundleIdIn(identity)}` |';

  return '''
The app has three flavors, which install next to each other on a device, each under an id of its own:

| Flavor | Android application id | iOS bundle id |
| --- | --- | --- |
${AppEntryRole.flavors.map(rowOf).join('\n')}

A `flutter` command without `--flavor` builds `${fallback.name}`, because `default-flavor` in `pubspec.yaml` says so. That holds in release mode too: `flutter build appbundle` and `flutter build ipa` build a release of `${fallback.name}`, under its id. For a store, name the flavor:

```bash
flutter run --flavor ${_stagingFlavor.name}
flutter build appbundle --flavor ${release.name}
flutter build ipa --flavor ${release.name}
```

Code reads the flavor from `appFlavor` of `package:flutter/services.dart`. A service that knows your app by its id, such as a store or a push provider, knows each flavor as an app of its own, so you repeat a step of its setup for each flavor that needs it.''';
}
