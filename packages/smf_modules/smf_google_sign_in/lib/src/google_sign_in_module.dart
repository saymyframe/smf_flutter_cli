import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_google_sign_in/bundles/google_sign_in_bundle.dart';
import 'package:smf_google_sign_in/src/agents.dart';
import 'package:smf_google_sign_in/src/readme.dart';

/// The module that gives the auth role a way to sign in with Google sign-in
/// on Android and iOS, through the google_sign_in package.
///
/// It generates `lib/core/google_sign_in/google_sign_in.dart` with
/// `googleCredential()`, the function of the way to sign in, and
/// `GoogleSignInIcon`, the icon of its button, and gives the role a
/// [SignInMethod] with them, which the template of the role lists in
/// `appSignInMethods`, whichever module provides the role. For the App
/// Store, Google sign-in is a login service of a third party, so an app on
/// iOS with it alone gets the warning of guideline 4.8 from the template of
/// the role.
///
/// The function starts google_sign_in once, without the ids of the clients
/// of Google, so the package reads them from the files of the app where the
/// provider of the role puts them, and returns the ID token of the Google
/// account of the user with the issuer [issuer]. A closed sheet returns
/// `null`, and an error with which Google refuses an app that is not set up
/// for it fails with `notConfigured`.
///
/// The module knows no provider of the role: it requires the role, and
/// states what its way to sign in needs of the backend of the provider, as
/// the [SignInNeed]s of its method, which the provider meets. It uses the
/// localization role for the label of the button, in English and in
/// Ukrainian. The icon shows the "G" of Google from [logoFile], with a file
/// for each screen with more pixels ([logoVariants]), which the module
/// declares among the assets of the app.
///
/// The README of the app tells what Google needs of the Google project and
/// of the app, where google_sign_in reads the ids of the clients, and that
/// the logo stays as it is, and its guide for coding agents how the
/// function asks Google and what a test of the app replaces for it.
final class GoogleSignInModule extends SmfModule {
  /// Creates the module.
  const GoogleSignInModule();

  /// The id of the module.
  static const id = ModuleId('google_sign_in');

  /// The issuer of the ID tokens of Google, by which the provider of the
  /// role tells the identity provider of the way to sign in.
  static const issuer = 'https://accounts.google.com';

  /// The label of the button of the way to sign in, the text that the
  /// branding guidelines of Google give a button of Google sign-in.
  static const label = LocalizedText(
    'label',
    en: 'Continue with Google',
    translations: {'uk': 'Продовжити з Google'},
  );

  /// The logo of Google in the app, an image for a screen with one pixel
  /// for each logical pixel, which `pubspec.yaml` of the app declares among
  /// its assets.
  static const String logoFile = googleLogoFile;

  /// The files of the logo for the screens with more pixels, each by the
  /// number of pixels for a logical pixel. Flutter finds them next to
  /// [logoFile], which alone is declared.
  static const logoVariants = {
    2: '$_logoDirectory/2.0x/google_logo.png',
    3: '$_logoDirectory/3.0x/google_logo.png',
  };

  /// The directory of the app with the files of the logo.
  static const _logoDirectory = 'lib/core/google_sign_in/assets';

  static const _file = ImportRef.app('core/google_sign_in/google_sign_in.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Google sign-in on Android and iOS with google_sign_in',
        kind: ModuleKinds.infrastructure,
        requires: {authRole},
        uses: {localizationRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          googleSignInBundle,
          vars: const {
            'issuer': issuer,
            'logo': logoFile,
            'readme': readmeHeading,
          },
        ),
        // 7.2 is the latest release; its Android plugin builds with the
        // Android Gradle plugin of the apps from the version that the
        // Flutter of the apps resolves.
        const PubspecContribution.hosted('google_sign_in', '^7.2.0'),
        const PubspecContribution.flutter(assets: [logoFile]),
        authRole.data(
          const SignInMethod(
            label: label,
            icon: TypeRef('GoogleSignInIcon', import: _file),
            platforms: {AppPlatform.android, AppPlatform.ios},
            credential: FunctionRef('googleCredential', import: _file),
            issuer: issuer,
            appStore: AppStoreLogin.thirdParty,
            needs: {
              SignInNeed.androidCertificate,
              SignInNeed.iosClient,
              SignInNeed.serverClient,
            },
          ),
        ),
        localizationRole.data(const TextsData([label])),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(readmeHeading, AgentNote(agentNote)),
      ];
}
