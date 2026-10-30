import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contracts/src/roles/image_steps.dart';

/// The app icon role; see [AppIconRole].
const appIconRole = AppIconRole._();

/// The role of the icon of the app on Android and iOS, in place of the logo
/// of Flutter that `flutter create` gives.
///
/// No module gives the role data, and no code of the app reads it, so the
/// role has no sockets and no Dart symbols. It holds the place of the two
/// images that the icon is made from, [imageFile] and [foregroundFile], which
/// every provider generates ([RoleInterface.providerFiles]). What they show
/// and the colours around them belong to the provider, as the look of the app
/// belongs to a provider of the [ThemeRole], and so does the tool that makes
/// the icon from them.
///
/// The native projects are files of the provider of the [AppEntryRole], so
/// the provider makes the icon in a [PostGenStep], which every run of
/// `smf create` runs (the rule `app_icon.step`). Its README section and its
/// note for coding agents give the command that makes the icon again after a
/// change of an image, and tell what the images show.
///
/// The template writes the section [readmeHeading] of the README of the app
/// and the note of the role. All flavors of the app share the icon, since one
/// pair of images makes it.
///
/// Whether the icon reached the native projects shows only once the step has
/// run, so neither these rules nor a snapshot see it.
final class AppIconRole extends Role<NoDsl> {
  const AppIconRole._();

  /// The heading of the section of the role in the README of the app.
  static const readmeHeading = 'App icon';

  /// The square image of the icon, 1024 by 1024 and opaque, as the App Store
  /// asks.
  static const imageFile = 'assets/branding/icon.png';

  /// The logo on a transparent background, 1024 by 1024, for the adaptive
  /// icon of Android.
  static const foregroundFile = 'assets/branding/icon_foreground.png';

  @override
  String get id => 'app_icon';

  @override
  String get description => 'App icon';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  RoleInterface get interface =>
      const RoleInterface(providerFiles: [imageFile, foregroundFile]);

  @override
  RoleTemplate<NoDsl> get template => const _AppIconTemplate();

  @override
  List<ModuleRule<NoDsl>> get moduleRules => const [
        ModuleRule(
          id: 'app_icon.step',
          description: 'A provider has a PostGenStep that makes the icon in '
              'every run of smf create: one that is neither external nor '
              'interactive, has no notice and no hosts, and continues no '
              'other step.',
          check: imageStepProblems,
        ),
      ];
}

const _agentNote = '''
- The sources of the icon of the app are `${AppIconRole.imageFile}` and `${AppIconRole.foregroundFile}`. Do not edit the images made from them in the Android and iOS projects. Change a source and run the command that the note of the provider below gives. Keep the first source opaque, since the App Store refuses an icon with alpha.
''';

const _readme = '''
The icon of the app is made from two images, which the app does not bundle:

- `${AppIconRole.imageFile}`, 1024 by 1024 and opaque, since the App Store refuses an icon with alpha. iOS and older versions of Android show it.
- `${AppIconRole.foregroundFile}`, 1024 by 1024, the logo on a transparent background, for the adaptive icon of Android.

All flavors share the icon. The section of the module that provides the icon says what the images show now, how much of the second one launchers cut, and which command to run after a change.
''';

/// The template of the [AppIconRole]: the section of the role in the README
/// of the app and its note for coding agents.
final class _AppIconTemplate extends RoleTemplate<NoDsl> {
  const _AppIconTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        AppEntryRole.readmeSections.entry(AppIconRole.readmeHeading, _readme),
        AppEntryRole.agentSections.entry(
          appIconRole.description,
          AgentNote.ofRole(_agentNote),
        ),
      ];
}
