import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_auth/bundles/firebase_auth_bundle.dart';
import 'package:smf_firebase_auth/src/agents.dart';
import 'package:smf_firebase_auth/src/readme.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';

/// The module that signs the users of the app in with Firebase
/// Authentication, through the firebase_auth package, and so provides the
/// auth role.
///
/// The template of the role generates `AuthService`, the interface of the
/// service of a provider, `appSession`, through which the code of the app
/// signs in, up and out, and `initAuth()`, which `bootstrap()` awaits
/// before the first frame. This module adds `firebase_auth` to the
/// dependencies of the app and implements the service in
/// `lib/core/auth/firebase_auth_service.dart` on `FirebaseAuth`, with an
/// email address and a password, and for anonymous users. The service is
/// the same in every mode of the role.
///
/// Firebase Authentication works on the Firebase app, so the module depends
/// on [FirebaseCoreModule], which initializes Firebase in `bootstrap()`, and
/// the session of the app starts after that. Firebase keeps the user on
/// the device and hands that user over when it is initialized, so the
/// service is created without waiting and has the user at once.
///
/// The service keeps what the role promises and the package does not:
/// - it gives each code of Firebase the reason of the role, and the reason
///   `unknown`, with the code and the message on one line, to a code that
///   it does not know. A way to sign in that is not enabled in the Firebase
///   project is `notConfigured`, with a hint that has the link to the page
///   of the project where it is enabled. Firebase tells of a project in
///   which Authentication was never set up only in the message of an
///   error, an unknown one on Android and an internal one on iOS, where the
///   message is the description of the error over many lines: the hint
///   names the code and what the service found there, not that
///   description. An internal error of iOS and macOS whose message says no
///   more is `notConfigured` there too, with a hint that says that it may
///   be another error;
/// - an empty address or password fails before Firebase is asked, with the
///   same reason on every platform: Android refuses an empty text with a
///   code that has no reason, and iOS answers an empty password as a wrong
///   one;
/// - the user has no address when Firebase has an empty one, as Android
///   has for an anonymous user whom it kept on the device;
/// - it tells of the user after each of its calls, and when Firebase tells
///   of a change that no call made, with the user of the moment in which a
///   listener hears of it;
/// - a call for a user whose session has ended on the server signs that
///   user out on the device before it fails;
/// - it signs out after it deleted the user: the package keeps a deleted
///   user as its current one until the platform tells it of the sign-out;
/// - a password reset completes for an address without an account also in
///   a project that tells so.
///
/// The module uses the localization role: in an app with it, Firebase sends
/// the message of a password reset in the language that the app is in.
///
/// The README of the app tells where the ways to sign in are enabled in
/// the Firebase project, and its guide for coding agents which file is on
/// Firebase Authentication and where a code of Firebase gets its reason.
final class FirebaseAuthModule extends SmfModule {
  /// Creates the module.
  const FirebaseAuthModule();

  /// The id of the module.
  static const id = ModuleId('firebase_auth');

  static const _file = ImportRef.app('core/auth/firebase_auth_service.dart');

  /// The code of the service that asks Firebase for its messages in the
  /// language that the app is in, in an app with the localization role: the
  /// language that the user chose, or the one that the device prefers among
  /// those of the app, as the root of the app resolves it.
  static const _emailLanguage = Fragment(
    '// The message is in the language that the app is in.\n'
    'await _auth.setLanguageCode(\n'
    '  (appLocale.value ??\n'
    '          basicLocaleListResolution(\n'
    '            WidgetsBinding.instance.platformDispatcher.locales,\n'
    '            appLocales,\n'
    '          ))\n'
    '      .languageCode,\n'
    ');',
    imports: [
      ImportRef(
        'package:flutter/widgets.dart',
        show: ['WidgetsBinding', 'basicLocaleListResolution'],
      ),
      ImportRef.app('core/l10n/app_locale.dart'),
    ],
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Firebase Authentication with firebase_auth',
        kind: ModuleKinds.infrastructure,
        dependsOn: {FirebaseCoreModule.id},
        uses: {localizationRole},
        providers: [RoleProvider.plain(authRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          firebaseAuthBundle,
          vars: const {
            'email_language': RoleVar(
              localizationRole,
              present: _emailLanguage,
              absent: '',
            ),
          },
        ),
        const PubspecContribution.hosted('firebase_auth', '^6.7.0'),
        authRole.data(
          const RoleImplementation(
            type: TypeRef('FirebaseAuthService', import: _file),
            create: FactoryRef('createFirebaseAuthService', import: _file),
          ),
        ),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(
          authRole.description,
          AgentNote(agentNote),
        ),
      ];
}
