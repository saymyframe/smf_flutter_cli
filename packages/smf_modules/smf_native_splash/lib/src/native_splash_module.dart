import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_native_splash/bundles/native_splash_bundle.dart';
import 'package:smf_native_splash/src/agents.dart';
import 'package:smf_native_splash/src/brand.dart';
import 'package:smf_native_splash/src/config.dart';

/// The module of the splash screen of the app, which provides the splash
/// role with flutter_native_splash: the mark of Say My Frame, in green on
/// cream in the light mode of the device and in cream on green in the dark
/// mode, in place of the white screen of `flutter create`.
///
/// Its brick has the two images that the role names and `configFile`, the
/// configuration of the tool, with the colours of `brand.dart`. The package
/// is a dev dependency of the app: no code of the app imports it, and the
/// native projects get what it makes.
///
/// The native projects belong to the provider of the app entry, so a step
/// after generation runs the tool, in every run, since it needs nothing
/// outside the app. The app is complete without the screen, so the step is
/// skippable: a tool that fails costs a warning with the command to run
/// later, and not the app.
///
/// All flavors of the app share the screen. The tool would write a screen of
/// a flavor for Android, but on iOS the app does not use the storyboard that
/// it writes for one, so the module offers none.
///
/// The README of the app gets a section with what the images show, where the
/// colours are and the command, and the guide for coding agents a note with
/// the command, and with `android_min_sdk`, which must stay out of the
/// configuration: the tool would then leave the launch background that
/// Android below 12 reads as it is, without an image.
final class NativeSplashModule extends SmfModule {
  /// Creates the module.
  const NativeSplashModule();

  /// The id of the module.
  static const id = ModuleId('native_splash');

  /// The heading of the section of the module in the README of the app.
  static const readmeHeading = 'Native splash';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A splash screen for the light and the dark mode, with '
            'flutter_native_splash',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(splashRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          nativeSplashBundle,
          vars: const {
            'light_background': splashLightBackground,
            'dark_background': splashDarkBackground,
            'light_image': SplashRole.lightImageFile,
            'dark_image': SplashRole.darkImageFile,
          },
        ),
        const PubspecContribution.hosted(
          'flutter_native_splash',
          '^2.4.8',
          dev: true,
        ),
        const PostGenStep(
          ToolRef('dart'),
          splashArguments,
          description: 'Making the splash screen from assets/branding',
          skippable: true,
        ),
        AppEntryRole.readmeSections.entry(readmeHeading, _readmeSection),
        AppEntryRole.agentSections.entry(
          splashRole.description,
          AgentNote(agentNote),
        ),
      ];
}

/// The section of the module in the README of the app: what the images show
/// now, where the colours are, and the command. What each image has to be is
/// in the section of the role.
const _readmeSection = '''
`${SplashRole.lightImageFile}` and `${SplashRole.darkImageFile}` show the mark of Say My Frame, in green for the light mode and in cream for the dark one. Replace them with your own before you release the app. The colours behind them are in `$configFile`: `color` and `color_dark`, and the same two under `android_12` for Android 12 and later.

After you change an image or that file, make the screen again and commit what changed under `android/` and `ios/`:

```bash
$splashCommand
```

The command rewrites `ios/Runner/Info.plist` with one more level of indentation. Keep `android_min_sdk` out of `$configFile`: with it, the tool leaves the launch background of Android below 12 as it is, and the screen there has no image.

A file `flutter_native_splash-<flavor>.yaml` does not give a flavor its own screen on iOS: the tool writes one, and the app keeps showing the screen of `$configFile`.
''';
