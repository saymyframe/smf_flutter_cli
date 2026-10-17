import 'package:smf_apple_sign_in/bundles/apple_sign_in_bundle.dart';
import 'package:smf_apple_sign_in/src/agents.dart';
import 'package:smf_apple_sign_in/src/readme.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// The module that gives the auth role a way to sign in with Sign in with
/// Apple on iOS, through the sign_in_with_apple package.
///
/// It generates `lib/core/apple_sign_in/apple_sign_in.dart` with
/// `appleCredential()`, the function of the way to sign in, and
/// `AppleSignInIcon`, the icon of its button, and gives the role a
/// [SignInMethod] with them, which the template of the role lists in
/// `appSignInMethods`, whichever module provides the role:
/// - it works on iOS only, so the function fails with `notConfigured` on
///   another platform without asking Apple, and a screen of sign-in shows
///   its button on iOS only;
/// - the App Store takes it as the equivalent of a login service of a third
///   party (App Store Review Guideline 4.8);
/// - the deletion of an account that signs in with Apple asks Apple for a
///   credential again first, so that the provider of the role can revoke
///   the tokens that Apple gave the app with its authorization code, as
///   App Store Review Guideline 5.1.1(v) asks.
///
/// The function asks Apple with the SHA-256 hash of a new random nonce,
/// with the crypto package, for the email address and the full name of the
/// user, and returns an ID token of the issuer [issuer] with the nonce
/// itself, the authorization code of the request and the name, which Apple
/// gives only at the first sign-in of a user in the app. A closed sheet
/// returns `null`, and the unknown error with which Apple answers an app
/// without the capability fails with `notConfigured`.
///
/// The module knows no provider of the role: it requires the role, and its
/// way to sign in needs nothing of the backend of the provider but what the
/// provider meets for the issuer. It uses the localization role for the
/// label of the button, in English and in Ukrainian. It signs the iOS app
/// with the entitlement of the capability, `com.apple.developer.applesignin`
/// with the value `Default`, through [AppEntryRole.iosEntitlements].
///
/// The README of the app tells what the capability needs of the team that
/// signs the app, what Apple gives only at the first sign-in, what a
/// deletion asks of Apple and of the backend, and that App Review checks the
/// logo of the button, and its guide for coding agents how the function asks
/// Apple and what a test of the app sets for it.
final class AppleSignInModule extends SmfModule {
  /// Creates the module.
  const AppleSignInModule();

  /// The id of the module.
  static const id = ModuleId('apple_sign_in');

  /// The issuer of the ID tokens of Apple, by which the provider of the role
  /// tells the identity provider of the way to sign in.
  static const issuer = 'https://appleid.apple.com';

  /// The label of the button of the way to sign in, one of the titles that
  /// Apple allows a custom button of Sign in with Apple.
  static const label = LocalizedText(
    'label',
    en: 'Continue with Apple',
    translations: {'uk': 'Продовжити з Apple'},
  );

  static const _file = ImportRef.app('core/apple_sign_in/apple_sign_in.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Sign in with Apple on iOS with sign_in_with_apple',
        kind: ModuleKinds.infrastructure,
        requires: {authRole},
        uses: {localizationRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          appleSignInBundle,
          vars: const {'issuer': issuer, 'readme': readmeHeading},
        ),
        const PubspecContribution.hosted('sign_in_with_apple', '^8.2.0'),
        const PubspecContribution.hosted('crypto', '^3.0.7'),
        authRole.data(
          const SignInMethod(
            label: label,
            icon: TypeRef('AppleSignInIcon', import: _file),
            platforms: {AppPlatform.ios},
            credential: FunctionRef('appleCredential', import: _file),
            issuer: issuer,
            appStore: AppStoreLogin.privacyFocused,
            revokesOnDeletion: true,
          ),
        ),
        localizationRole.data(const TextsData([label])),
        AppEntryRole.iosEntitlements.entry(
          appleSignInEntitlement,
          const PlistStringArray(['Default']),
        ),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(readmeHeading, AgentNote(agentNote)),
      ];
}
