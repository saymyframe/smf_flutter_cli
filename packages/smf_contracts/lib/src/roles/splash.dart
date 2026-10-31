import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contracts/src/roles/image_steps.dart';

/// The splash role; see [SplashRole].
const splashRole = SplashRole._();

/// The role of the screen that the system shows while the app starts on
/// Android and iOS, in place of the white screen of `flutter create`.
///
/// No module gives the role data, and no code of the app reads it: the system
/// shows the screen before any Dart code runs. So the role has no sockets and
/// no Dart symbols. It holds the place of the two images that the screen is
/// made from, [lightImageFile] and [darkImageFile], one for each mode of the
/// device, which every provider generates ([RoleInterface.providerFiles]).
/// What they show and the colours behind them belong to the provider, as the
/// look of the app belongs to a provider of the [ThemeRole], and so does the
/// tool that makes the screen from them.
///
/// The native projects are files of the provider of the [AppEntryRole], so
/// the provider makes the screen in a [PostGenStep] that a run without a
/// terminal runs too (the rule `splash.step`). Its README section and its
/// note for coding agents give the command that makes the screen again after
/// a change of an image, and tell what the images show and which colours are
/// behind them.
///
/// The template writes the section [readmeHeading] of the README of the app
/// and the note of the role. All flavors of the app share the screen, since
/// one pair of images makes it.
///
/// Whether the screen reached the native projects shows only once the step
/// has run, so neither these rules nor a snapshot see it.
final class SplashRole extends Role<NoDsl> {
  const SplashRole._();

  /// The heading of the section of the role in the README of the app.
  static const readmeHeading = 'Splash screen';

  /// The logo for the light mode on a transparent background, 1152 by 1152,
  /// inside a circle of two thirds of its width, since Android 12 and later
  /// cut the rest.
  static const lightImageFile = 'assets/branding/splash_light.png';

  /// The logo for the dark mode, as [lightImageFile] is for the light one.
  static const darkImageFile = 'assets/branding/splash_dark.png';

  @override
  String get id => 'splash';

  @override
  String get description => 'Splash screen';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  RoleInterface get interface =>
      const RoleInterface(providerFiles: [lightImageFile, darkImageFile]);

  @override
  RoleTemplate<NoDsl> get template => const _SplashTemplate();

  @override
  List<ModuleRule<NoDsl>> get moduleRules => const [
        ModuleRule(
          id: 'splash.step',
          description: 'A provider has a PostGenStep that makes the screen and '
              'that a run without a terminal runs too: one that is neither '
              'external nor interactive, has no notice and no hosts, and '
              'continues no other step.',
          check: imageStepProblems,
        ),
      ];
}

const _agentNote = '''
- The sources of the splash screen are `${SplashRole.lightImageFile}` and `${SplashRole.darkImageFile}`, a logo for each mode of the device on a transparent background. Do not edit the images made from them in the Android and iOS projects. Change a source and run the command that the note of the provider below gives.
''';

const _readme = '''
The screen that the system shows while the app starts is made from two images, which the app does not bundle: `${SplashRole.lightImageFile}` for the light mode of the device and `${SplashRole.darkImageFile}` for the dark one. Each is 1152 by 1152, a logo on a transparent background. Keep the logo inside a circle of two thirds of the width of the image, since Android 12 and later cut the rest.

All flavors share the screen. The section of the module that provides the screen says what the images show now, where the colours behind them are, and which command to run after a change.
''';

/// The template of the [SplashRole]: the section of the role in the README of
/// the app and its note for coding agents.
final class _SplashTemplate extends RoleTemplate<NoDsl> {
  const _SplashTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        AppEntryRole.readmeSections.entry(SplashRole.readmeHeading, _readme),
        AppEntryRole.agentSections.entry(
          splashRole.description,
          AgentNote.ofRole(_agentNote),
        ),
      ];
}
