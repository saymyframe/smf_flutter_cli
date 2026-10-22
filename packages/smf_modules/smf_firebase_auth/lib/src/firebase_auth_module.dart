import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_auth/bundles/firebase_auth_bundle.dart';
import 'package:smf_firebase_auth/src/agents.dart';
import 'package:smf_firebase_auth/src/enable_sign_in.dart';
import 'package:smf_firebase_auth/src/identity_providers.dart';
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
/// email address and a password, for anonymous users, and with the
/// credentials of Google and Apple. The service is the same in every mode
/// of the role.
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
///   project is `notConfigured`, with a hint that names the script of the
///   app which enables it, and has the link to the page of the project
///   where it is enabled. Firebase tells of a project in
///   which Authentication was never set up only in the message of an
///   error, an unknown one on Android and an internal one on iOS, whose
///   message ends with what the server answered in brackets on both: the
///   hint names the code and what the service found there, not the rest of
///   the message. An internal error of iOS and macOS whose message says no
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
/// The ways to sign in are enabled in the Firebase project, not in the
/// code. The module generates `tool/enable_firebase_sign_in.dart`, a script
/// of the app that enables those that the mode of the app needs with the
/// Firebase CLI, and the ways to sign in of the app with an identity
/// provider, which its provider renders into the script. For a way to sign
/// in of Google, the script also sets up what it needs: the SHA of the
/// debug key of the machine in the project, the Firebase files of the app
/// with the clients of Google, and the URL scheme of the iOS app in
/// `ios/Runner/Info.plist`. After generation, once `flutterfire configure`
/// of [FirebaseCoreModule] configured the app, the module runs the script:
/// its step continues [FirebaseCoreModule.configureStep], and a run in a
/// terminal asks about it, with what it does for Google sign-in. Any other
/// run prints the command to run later, and so does a run on a machine
/// whose Firebase CLI is older than the version that the script needs,
/// which the module checks before generation.
///
/// The service also signs in, links an anonymous user and confirms a
/// deletion with the credentials of the ways to sign in of Google and
/// Apple, which other modules give the auth role:
/// - Apple takes a credential once, so when Firebase refuses a link because
///   the identity or its email address belongs to another user, the service
///   keeps the credential that Firebase gives with its answer for the
///   credential object, and the sign-in with that object that the session
///   makes next uses it. The reasons of such a refusal are
///   `credentialInUse` and `accountExistsWithOtherMethod` for a link of a
///   credential, and `emailInUse` for a link of a password;
/// - a deletion with a fresh credential signs the user in again with it,
///   and, for a credential of Apple, revokes the tokens of Apple with its
///   authorization code before the account is deleted, on iOS and macOS,
///   where Firebase does. A revocation that fails keeps the account and is
///   `notConfigured`, with a hint that names what the Apple sign-in method
///   of the Firebase project needs for it, but for an answer that has
///   nothing to do with the setup, such as a request that did not reach
///   Firebase. The service maps its failures itself, and asks Firebase only
///   while a user is signed in, since the future of the call never
///   completes without one. Firebase answers a sign-in again with
///   `user-not-found` for an identity without a user and for an account
///   that the server deleted, which a reload of the user tells apart.
///
/// The provider of the module refuses an app with a way to sign in of
/// another identity provider in its `validate` hook, as the role asks of a
/// provider whose backend does not take the identity provider of a way to
/// sign in, and one that needs of the project what the script does not set
/// up for its identity provider.
///
/// What no command can do for a way to sign in of the app, the provider
/// lists among the steps by hand of the app in its `manualSteps` hook: for
/// one of Apple, [FirebaseAuthModule.appleProviderStep] and
/// [FirebaseAuthModule.appleRevocationStep], since the Firebase CLI cannot
/// enable Apple; and for one that needs the certificate of the Android app,
/// such as one of Google, [FirebaseAuthModule.googleReleaseShaStep], since
/// the script registers only the debug key of the machine that runs it.
///
/// The README of the app tells how to enable the ways to sign in, with the
/// script and in the Firebase console, and what the script does to the
/// project, and in an app with ways to sign in of Google and Apple what it
/// does for them and what is left to the developer, such as the SHA of the
/// key of a release and the key of Apple. Its guide for coding agents tells
/// which file is on Firebase Authentication, where a code of Firebase gets
/// its reason, and that the script is run only when asked.
final class FirebaseAuthModule extends SmfModule {
  /// Creates the module.
  const FirebaseAuthModule();

  /// The id of the module.
  static const id = ModuleId('firebase_auth');

  /// The step by hand of an app with a way to sign in of Apple, in which the
  /// developer adds Apple to the sign-in methods of the Firebase project in
  /// the Firebase console: the Firebase CLI, with which the script of the
  /// app enables the other methods, cannot enable it.
  static const appleProviderStep = ManualStep(
    ManualStepId(id, 'apple_provider'),
    'Turn on Sign in with Apple in Firebase Authentication',
  );

  /// The step by hand of an app with a way to sign in of Apple, in which the
  /// developer enters the key for Sign in with Apple of the team in the
  /// settings of the Apple provider of the Firebase project. Firebase
  /// revokes the tokens of Apple with it when an account is deleted, and
  /// the deletion fails without it.
  static const appleRevocationStep = ManualStep(
    ManualStepId(id, 'apple_revocation'),
    'Give Firebase your Sign in with Apple key, so that deleting an account '
    'works',
  );

  /// The step by hand of an app with a way to sign in that needs the
  /// certificate of the Android app, such as one of Google, in which the
  /// developer gives the Android app in the Firebase project the SHA of the
  /// keys that sign a release before the first release on Google Play: the
  /// upload key and the app signing key of Google Play. The script of the
  /// app registers only the debug key of the machine that runs it.
  static const googleReleaseShaStep = ManualStep(
    ManualStepId(id, 'google_release_sha'),
    'Before releasing on Google Play, give Firebase the SHA of your release '
    'keys',
  );

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
        providers: [_FirebaseAuthProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          firebaseAuthBundle,
          vars: {
            'email_language': const RoleVar(
              localizationRole,
              present: _emailLanguage,
              absent: '',
            ),
            // For the script that enables the ways to sign in: the file
            // that it reads the mode of the app from, how the auth role
            // says to read it, the mode with anonymous users, and the
            // Firebase CLI that it asks for.
            'session_file': AuthRole.sessionFile,
            'mode_declaration': modeDeclarationCode,
            'anonymous_mode': AuthMode.anonymous.name,
            'minimum_firebase_cli': firstFirebaseCliWithSignIn,
          },
        ),
        const PubspecContribution.hosted('firebase_auth', '^7.0.0'),
        authRole.data(
          const AuthImplementation(
            type: TypeRef('FirebaseAuthService', import: _file),
            create: FactoryRef('createFirebaseAuthService', import: _file),
          ),
        ),
        const Preflight([firebaseCliWithSignIn]),
        enableSignIn,
        AppEntryRole.agentSections.entry(
          authRole.description,
          AgentNote(agentNote),
        ),
      ];
}

/// The provider of the auth role of [FirebaseAuthModule]: its bricks
/// implement the role, its `validate` hook reports each way to sign in with
/// an identity provider that a module gives the role whose credential the
/// service of the module does not take, or that needs of the Firebase
/// project what the script does not set up, its `manualSteps` hook lists
/// what the developer of the app sets up by hand for the ways to sign in,
/// and its `render` hook gives the script the ways to sign in of the app
/// and writes the section of the module in the README of the app.
final class _FirebaseAuthProvider extends RoleProvider<AuthData> {
  const _FirebaseAuthProvider();

  @override
  Role<AuthData> get role => authRole;

  @override
  List<SmfIssue> validate(RoleHookInput<AuthData> input) => [
        for (final AppSignInMethod(:owner, :method)
            in authRole.methodsIn(input))
          if (_problemOf(owner, method) case final problem?) problem,
      ];

  /// Why the module cannot meet [method], the way to sign in that [owner]
  /// gives the app, or `null` if it can: its identity provider is none of
  /// [identityProviders], or it needs of the Firebase project what the
  /// script does not set up for its identity provider.
  static SmfIssue? _problemOf(ContributionOrigin owner, SignInMethod method) {
    final hint = 'Leave $owner out of an app with ${FirebaseAuthModule.id}.';
    final provider = identityProviders[method.issuer];
    if (provider == null) {
      final taken = [
        for (final MapEntry(key: issuer, value: provider)
            in identityProviders.entries)
          '${provider.name} ($issuer)',
      ];
      return SmfIssue(
        'The module $owner gives the app a way to sign in with '
        '${method.issuer}, whose credential ${FirebaseAuthModule.id} does '
        'not take: it signs in to Firebase Authentication with the '
        'credentials of ${taken.join(' and ')}, besides an email address and '
        'a password, and as an anonymous user. A sign-in with it would fail '
        'with notConfigured.',
        hint: hint,
        origin: owner,
      );
    }
    final unmet = method.needs.difference(provider.needs);
    if (unmet.isEmpty) return null;
    // In the order of the needs of the role.
    final names = [
      for (final need in SignInNeed.values)
        if (unmet.contains(need)) need.name,
    ];
    return SmfIssue(
      'The module $owner gives the app a way to sign in with '
      '${provider.name} (${method.issuer}) that needs ${names.join(' and ')} '
      'of the backend, which ${FirebaseAuthModule.id} does not set up for '
      '${provider.name}. A sign-in with it would fail.',
      hint: hint,
      origin: owner,
    );
  }

  /// The steps by hand of the ways to sign in of the app, in this order:
  /// [FirebaseAuthModule.appleProviderStep] and
  /// [FirebaseAuthModule.appleRevocationStep] for a way to sign in of
  /// Apple, which the Firebase CLI cannot enable, and
  /// [FirebaseAuthModule.googleReleaseShaStep] for one that needs the
  /// certificate of the Android app, of which the script registers only the
  /// debug key. An app without such ways to sign in has none.
  @override
  List<ManualStep> manualSteps(RoleHookInput<AuthData> input) {
    final methods = firebaseMethodsOf(authRole.methodsIn(input));
    return [
      if (methods.containsKey('apple.com')) ...const [
        FirebaseAuthModule.appleProviderStep,
        FirebaseAuthModule.appleRevocationStep,
      ],
      if (methods.values
          .any((needs) => needs.contains(SignInNeed.androidCertificate)))
        FirebaseAuthModule.googleReleaseShaStep,
    ];
  }

  /// The ways to sign in of the app for the script, the section of the
  /// module in the README of the app, which tells what the script does for
  /// them, and a second note for coding agents in an app with them.
  @override
  RoleOutput render(RoleHookInput<AuthData> input) {
    final methods = firebaseMethodsOf(authRole.methodsIn(input));
    final note = methodsAgentNote(methods);
    return RoleOutput(
      fragments: [
        AppEntryRole.readmeSections.entry(
          readmeHeading,
          readmeSectionOf(methods),
        ),
        if (note != null)
          AppEntryRole.agentSections.entry(
            authRole.description,
            AgentNote(note),
          ),
      ],
      vars: scriptVarsOf(methods),
    );
  }
}
