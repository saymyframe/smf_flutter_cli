@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_auth/bundles/firebase_auth_bundle.dart';
import 'package:smf_firebase_auth/smf_firebase_auth.dart';
import 'package:smf_firebase_auth/src/agents.dart';
import 'package:smf_firebase_auth/src/enable_sign_in.dart';
import 'package:smf_firebase_auth/src/identity_providers.dart';
import 'package:smf_firebase_auth/src/readme.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/dart_app.dart';

/// The modules of the tests: flutter_core, which creates the app,
/// go_router, a provider of the router role, which the auth role uses,
/// firebase_core, which this module depends on, this module, and gen_l10n,
/// a provider of the localization role, which this module uses, with
/// shared_preferences, a provider of the preferences role, which that role
/// requires.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  FirebaseCoreModule(),
  FirebaseAuthModule(),
  SharedPreferencesModule(),
  GenL10nModule(),
];

/// A module of the tests that gives the auth role a way to sign in with the
/// identity provider [issuer].
final class _WayOfTest extends SmfModule {
  const _WayOfTest(this.id, this.issuer, this.appStore);

  /// The way to sign in of Google, which the module takes.
  static const google = _WayOfTest(
    ModuleId('google_of_test'),
    'https://accounts.google.com',
    AppStoreLogin.thirdParty,
  );

  /// The way to sign in of Apple, which the module takes.
  static const apple = _WayOfTest(
    ModuleId('apple_of_test'),
    'https://appleid.apple.com',
    AppStoreLogin.privacyFocused,
  );

  /// A way to sign in of another identity provider, which the module does
  /// not take.
  static const other = _WayOfTest(
    ModuleId('way_of_test'),
    'https://accounts.example.com',
    AppStoreLogin.privacyFocused,
  );

  /// The id of the module.
  final ModuleId id;

  /// The identity provider of the way to sign in.
  final String issuer;

  /// What the way to sign in is for the App Store.
  final AppStoreLogin appStore;

  String get _path => 'core/${id.value}/way_of_test.dart';

  /// The way to sign in that it gives the role.
  SignInMethod get method => SignInMethod(
        label: const LocalizedText('label', en: 'Continue with the test'),
        icon: TypeRef('WayOfTestIcon', import: ImportRef.app(_path)),
        platforms: const {AppPlatform.android, AppPlatform.ios},
        credential: FunctionRef(
          'wayOfTestCredential',
          import: ImportRef.app(_path),
        ),
        issuer: issuer,
        appStore: appStore,
      );

  static const _source = '''
import 'package:flutter/widgets.dart';

import '../auth/app_session.dart';

Future<SignInCredential?> wayOfTestCredential() async => null;

class WayOfTestIcon extends StatelessWidget {
  const WayOfTestIcon({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'A way to sign in of the tests',
        kind: ModuleKinds.infrastructure,
        requires: const {authRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          MasonBundle(
            name: id.value,
            description: 'The function and the icon of the way to sign in',
            version: '0.1.0',
            files: [
              MasonBundledFile(
                'lib/$_path',
                base64.encode(utf8.encode(_source)),
                'text',
              ),
            ],
          ),
        ),
        authRole.data(method),
      ];
}

/// The path of the file of the module.
const _implementation = 'lib/core/auth/firebase_auth_service.dart';

/// The statement of firebase_core that initializes Firebase in
/// `bootstrap()`.
const _initializeFirebase = 'await Firebase.initializeApp(options: '
    'DefaultFirebaseOptions.currentPlatform);';

/// The owners of the code of sign-in: this module and the template of its
/// role.
final Set<ContributionOrigin> _auth = {
  const ModuleOrigin(FirebaseAuthModule.id),
  const RoleTemplateOrigin(authRole),
};

/// What the contract harness finds for the app of [modules] with the
/// options [roleOptions] of its roles, which has no errors and is rendered.
Future<ContractResult> _resultOf(
  List<ModuleId> modules, {
  Map<String, String?> roleOptions = const {},
}) async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    ContractCase(
      modules.join(', '),
      requested: modules,
      roleOptions: roleOptions,
    ),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The pubspec [text] as plain maps and lists.
Map<String, Object?> _yamlOf(String text) {
  Object? plain(Object? node) => switch (node) {
        final YamlMap map => {
            for (final MapEntry(:key, :value) in map.entries)
              '$key': plain(value),
          },
        final YamlList list => [for (final item in list) plain(item)],
        _ => node,
      };
  return plain(loadYaml(text))! as Map<String, Object?>;
}

/// The code that the modules and the templates of the roles put into the
/// phases of start-up in the app of [result], phase after phase, each as
/// its contributor and its code: what `bootstrap()` runs, whichever module
/// provides the app entry.
List<String> _startUpOf(ContractResult result) => [
      for (final phase in const [
        AppEntryRole.bootstrapEarly,
        AppEntryRole.bootstrapPlatform,
        AppEntryRole.bootstrapDi,
        AppEntryRole.bootstrapLate,
      ])
        for (final collected
            in result.app!.socketOrders[phase]?.contributions ??
                const <Collected>[])
          [
            '${collected.origin}:',
            (collected.contribution as SocketContribution).fragment!.code,
          ].join(' '),
    ];

/// The parsed file at [path] of [app].
CompilationUnit _unitOf(RenderedApp app, String path) =>
    parseString(content: app.files[path]!.text).unit;

/// The methods of the class [name] in [unit], by name.
Map<String, MethodDeclaration> _methodsOf(CompilationUnit unit, String name) {
  final declaration =
      unit.declarations.whereType<ClassDeclaration>().singleWhere(
            (declaration) => declaration.namePart.typeName.lexeme == name,
          );
  return {
    for (final member in declaration.body.members)
      if (member is MethodDeclaration) member.name.lexeme: member,
  };
}

/// The imports of [unit], as written.
List<String> _importsOf(CompilationUnit unit) => [
      for (final directive in unit.directives.whereType<ImportDirective>())
        '$directive',
    ];

/// The statements of the function that `sendPasswordReset()` of the service
/// in [app] runs, as written.
List<String> _passwordResetOf(RenderedApp app) {
  final method = _methodsOf(
    _unitOf(app, _implementation),
    'FirebaseAuthService',
  )['sendPasswordReset']!;
  final run =
      (method.body as ExpressionFunctionBody).expression as MethodInvocation;
  final function = run.argumentList.arguments.single as FunctionExpression;
  return [
    for (final statement
        in (function.body as BlockFunctionBody).block.statements)
      '$statement',
  ];
}

/// The import of the function with which the root of an app resolves the
/// language of the device, as the file of the service has it in an app
/// with the localization role.
const _widgetsImport = "import 'package:flutter/widgets.dart' "
    'show WidgetsBinding, basicLocaleListResolution;';

/// The inline code of [markdown]: what stands between two backticks,
/// outside its blocks of code.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(
        markdown.replaceAll(RegExp(r'```[\s\S]*?```'), ''),
      ))
        match[1]!,
    };

/// The codes of Firebase Authentication that the service gives a reason,
/// as the plugin has them, each with its reason of the auth role.
const _reasons = {
  'invalid-credential': 'invalidCredentials',
  'invalid-login-credentials': 'invalidCredentials',
  'wrong-password': 'invalidCredentials',
  'user-not-found': 'invalidCredentials',
  'email-already-in-use': 'emailInUse',
  'credential-already-in-use': 'emailInUse',
  'weak-password': 'weakPassword',
  'password-does-not-meet-requirements': 'weakPassword',
  'invalid-email': 'invalidEmail',
  'missing-email': 'invalidEmail',
  'user-disabled': 'userDisabled',
  'too-many-requests': 'tooManyAttempts',
  'network-request-failed': 'network',
  'requires-recent-login': 'recentSignInRequired',
};

/// The codes with which Firebase answers a call for a user whose session
/// has ended on the server.
const _endedSession = [
  'user-token-expired',
  'invalid-user-token',
  'user-not-found',
  'no-current-user',
];

/// Runs the service of the module on the stand-in for firebase_auth, and
/// sends back what its calls ended with, the user that it had, what
/// reached Firebase and what its listeners heard.
///
/// It imports the file of the module and the file of the role with
/// `AuthService`, which need nothing but the stand-ins.
const _script = r'''
import 'dart:async';
import 'dart:isolate';

import 'package:contract_app/core/auth/auth_service.dart';
import 'package:contract_app/core/auth/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const password = 'secret';

String userOf(AuthUser? user) => user == null
    ? 'nobody'
    : [
        '${user.uid} <${user.email}>',
        if (user.isAnonymous) ', anonymous',
        if (user.issuers.isNotEmpty) ' with ${user.issuers.join(', ')}',
      ].join();

Future<String> outcomeOf(Future<void> Function() call) async {
  try {
    await call();
    return 'completed';
  } on AuthFailure catch (failure) {
    final hint = failure.developerHint;
    return hint == null ? failure.reason.name : '${failure.reason.name}: $hint';
  } on Object catch (error) {
    return 'threw $error';
  }
}

/// Lets the events of the streams reach their listeners.
Future<void> settle() => Future<void>.delayed(Duration.zero);

Future<void> main(List<String> arguments, SendPort port) async {
  final codes = arguments;
  final result = <String, Object?>{};
  // The anonymous user that a start of the app on Android finds.
  restoreAnonymousUserOfAndroid('kept');
  final kept = createFirebaseAuthService().currentUser;
  result['an anonymous user of Android'] = [
    FirebaseAuth.instance.currentUser?.email,
    userOf(kept),
    kept?.email,
  ];
  await FirebaseAuth.instance.signOut();
  firebaseCalls.clear();

  final service = createFirebaseAuthService();
  result['implementation'] = '${service.runtimeType}';
  result['user at first'] = userOf(service.currentUser);
  result['streams of Firebase'] = [userChangesListeners];

  final heard = <String>[];
  var subscription = service.userChanges.listen(
    (user) => heard.add(userOf(user)),
    onError: (Object error) => heard.add('error: $error'),
  );
  await settle();
  result['streams of Firebase'] = [
    ...result['streams of Firebase']! as List<Object?>,
    userChangesListeners,
  ];
  result['a broadcast stream'] = service.userChanges.isBroadcast;

  // How a call ended, the user of the service then, what reached Firebase,
  // and the users that the listener heard of.
  Future<List<Object?>> step(Future<void> Function() call) async {
    await settle();
    heard.clear();
    firebaseCalls.clear();
    final outcome = await outcomeOf(call);
    await settle();
    return [
      outcome,
      userOf(service.currentUser),
      [...firebaseCalls],
      heard.toSet().toList(),
    ];
  }

  Future<void> signIn() => service.signIn(email: 'a@x.dev', password: password);

  result['calls'] = {
    'signUp': await step(
      () => service.signUp(email: 'a@x.dev', password: password),
    ),
    'signOut': await step(service.signOut),
    'signIn': await step(signIn),
    'sendPasswordReset': await step(() => service.sendPasswordReset('a@x.dev')),
    'signInAnonymously': await step(service.signInAnonymously),
    'linkPassword': await step(
      () => service.linkPassword(email: 'b@x.dev', password: password),
    ),
    'deleteAccount': await step(service.deleteAccount),
    'deleteAccount without a user': await step(service.deleteAccount),
    'linkPassword without a user': await step(
      () => service.linkPassword(email: 'b@x.dev', password: password),
    ),
  };

  await signIn();
  final reasons = <String, Object?>{};
  for (final code in codes) {
    failNext['signInWithEmailAndPassword'] = FirebaseAuthException(code: code);
    reasons[code] = await outcomeOf(signIn);
  }
  result['reasons'] = reasons;
  result['user after the failures'] = userOf(service.currentUser);

  failNext['sendPasswordResetEmail'] =
      FirebaseAuthException(code: 'user-not-found');
  result['reset for an address without an account'] =
      await step(() => service.sendPasswordReset('nobody@x.dev'));
  failNext['sendPasswordResetEmail'] =
      FirebaseAuthException(code: 'invalid-email');
  result['reset for a text that is no address'] =
      await outcomeOf(() => service.sendPasswordReset('nobody'));

  // An empty address or password, which the service refuses itself.
  await service.signOut();
  await service.signInAnonymously();
  await settle();
  firebaseCalls.clear();
  result['empty'] = {
    'signIn without an address':
        await outcomeOf(() => service.signIn(email: '', password: password)),
    'signIn without a password':
        await outcomeOf(() => service.signIn(email: 'a@x.dev', password: '')),
    'signUp without an address':
        await outcomeOf(() => service.signUp(email: '', password: password)),
    'signUp without a password':
        await outcomeOf(() => service.signUp(email: 'c@x.dev', password: '')),
    'linkPassword without an address': await outcomeOf(
      () => service.linkPassword(email: '', password: password),
    ),
    'linkPassword without a password': await outcomeOf(
      () => service.linkPassword(email: 'c@x.dev', password: ''),
    ),
    'sendPasswordReset without an address':
        await outcomeOf(() => service.sendPasswordReset('')),
  };
  result['calls of Firebase for what is empty'] = [...firebaseCalls];
  result['user after what is empty'] = userOf(service.currentUser);
  await signIn();

  // Credentials of identity providers. The tokens and the codes are no
  // part of a hint.
  const google = 'https://accounts.google.com';
  const apple = 'https://appleid.apple.com';
  IdTokenCredential credentialOf(
    String issuer,
    String token, {
    String? nonce,
    String? code,
  }) =>
      IdTokenCredential(
        issuer: issuer,
        idToken: 'token-$token',
        rawNonce: nonce,
        authorizationCode: code,
        givenName: issuer == apple ? 'Ada' : null,
        familyName: issuer == apple ? 'Lovelace' : null,
      );
  IdTokenCredential appleOf(String token, {String? code}) =>
      credentialOf(apple, token, nonce: 'nonce-$token', code: code);

  await service.signOut();
  await service.signInAnonymously();
  result['credentials'] = {
    'signInWith of Google': await step(
      () => service.signInWith(credentialOf(google, 'g', nonce: 'nonce-g')),
    ),
    'signInWith of Apple': await step(() => service.signInWith(appleOf('a'))),
    'signInWith of Apple without a nonce': await step(
      () => service.signInWith(credentialOf(apple, 'a-without-nonce')),
    ),
    'signInWith of another identity provider': await step(
      () => service.signInWith(
        credentialOf('https://accounts.example.com', 'other'),
      ),
    ),
    'signInAnonymously': await step(service.signInAnonymously),
    'linkWith of Google': await step(
      () => service.linkWith(credentialOf(google, 'linked')),
    ),
    'linkWith of another identity provider': await step(
      () => service.linkWith(
        credentialOf('https://accounts.example.com', 'other'),
      ),
    ),
    'signOut': await step(service.signOut),
    'linkWith without a user': await step(
      () => service.linkWith(credentialOf(google, 'nobody')),
    ),
  };

  // A link that Firebase refuses because the identity or its email address
  // belongs to another user, and the sign-ins with the identical credential
  // object after it.
  const given = AuthCredential(
    providerId: 'apple.com',
    signInMethod: 'apple.com',
    token: 7,
  );
  final refused = <String, Object?>{};
  for (final (name, code, withCredential) in const [
    ('credential-already-in-use', 'credential-already-in-use', true),
    ('email-already-in-use', 'email-already-in-use', true),
    (
      'account-exists-with-different-credential',
      'account-exists-with-different-credential',
      true
    ),
    ('a refusal without a credential', 'credential-already-in-use', false),
    ('provider-already-linked', 'provider-already-linked', true),
  ]) {
    await service.signOut();
    await service.signInAnonymously();
    final credential = appleOf('refused');
    failNext['linkWithCredential'] = FirebaseAuthException(
      code: code,
      message: code == 'provider-already-linked'
          ? 'User has already been linked to the given provider.'
          : null,
      credential: withCredential ? given : null,
    );
    refused[name] = [
      await step(() => service.linkWith(credential)),
      await step(() => service.signInWith(credential)),
      await step(() => service.signInWith(credential)),
    ];
  }
  result['refused links'] = refused;

  // A sign-in with another credential object between a refused link and
  // the sign-in with the identical one, as after a sign-out when the
  // session failed to move the data of the guest.
  await service.signOut();
  await service.signInAnonymously();
  final refusedOne = appleOf('refused');
  failNext['linkWithCredential'] = FirebaseAuthException(
    code: 'credential-already-in-use',
    credential: given,
  );
  result['another credential after a refused link'] = [
    await step(() => service.linkWith(refusedOne)),
    await step(service.signOut),
    await step(() => service.signInWith(credentialOf(google, 'between'))),
    await step(() => service.signInWith(refusedOne)),
  ];

  // The same codes for a link of a password.
  final ofPassword = <String, Object?>{};
  for (final code in const [
    'email-already-in-use',
    'credential-already-in-use',
  ]) {
    await service.signOut();
    await service.signInAnonymously();
    failNext['linkWithCredential'] = FirebaseAuthException(code: code);
    ofPassword[code] = await outcomeOf(
      () => service.linkPassword(email: 'b@x.dev', password: password),
    );
  }
  result['refused links of a password'] = ofPassword;

  Future<String> signingInWith(
    IdTokenCredential credential,
    String code, [
    String? message,
  ]) {
    failNext['signInWithCredential'] =
        FirebaseAuthException(code: code, message: message);
    return outcomeOf(() => service.signInWith(credential));
  }

  await service.signOut();
  result['refused sign-ins'] = {
    'account-exists-with-different-credential': await signingInWith(
      credentialOf(google, 'g'),
      'account-exists-with-different-credential',
    ),
    'missing-or-invalid-nonce': await signingInWith(
      appleOf('spent'),
      'missing-or-invalid-nonce',
      'Duplicate credential received.',
    ),
    'invalid-credential': await signingInWith(
      credentialOf(google, 'expired'),
      'invalid-credential',
    ),
    'operation-not-allowed of Google': await signingInWith(
      credentialOf(google, 'g'),
      'operation-not-allowed',
    ),
    'operation-not-allowed of Apple': await signingInWith(
      appleOf('a'),
      'operation-not-allowed',
    ),
  };
  defaultTargetPlatform = TargetPlatform.iOS;
  final internalOfApple = await signingInWith(
    appleOf('a'),
    'internal-error',
    'Internal.',
  );
  defaultTargetPlatform = TargetPlatform.android;
  result['an internal error of a sign-in with Apple on iOS'] = internalOfApple;

  // Deletions with a fresh credential: the user signs in with the identity,
  // and the deletion runs on [platform], with what Firebase answers.
  Future<List<Object?>> deleting(
    IdTokenCredential fresh, {
    TargetPlatform platform = TargetPlatform.android,
    IdTokenCredential? signedIn,
    Map<String, Object> failing = const {},
    void Function()? onReauthentication,
  }) async {
    await service.signOut();
    await service.signInWith(signedIn ?? appleOf('deleted'));
    failNext.addAll(failing);
    if (onReauthentication != null) {
      onNext['reauthenticateWithCredential'] = onReauthentication;
    }
    defaultTargetPlatform = platform;
    try {
      return await step(() => service.deleteAccount(fresh: fresh));
    } finally {
      defaultTargetPlatform = TargetPlatform.android;
    }
  }

  const code = 'code-fresh';
  result['deletions'] = {
    'of Google': await deleting(
      credentialOf(google, 'deleted'),
      signedIn: credentialOf(google, 'deleted'),
    ),
    // A code of Google revokes nothing either.
    'of Google on iOS': await deleting(
      credentialOf(google, 'deleted', code: 'code-of-google'),
      signedIn: credentialOf(google, 'deleted'),
      platform: TargetPlatform.iOS,
    ),
    'of Apple on Android': await deleting(appleOf('fresh', code: code)),
    for (final platform in const [TargetPlatform.iOS, TargetPlatform.macOS])
      'of Apple on ${platform.name}':
          await deleting(appleOf('fresh', code: code), platform: platform),
    'of Apple on iOS without a code': await deleting(
      appleOf('fresh'),
      platform: TargetPlatform.iOS,
    ),
    for (final reauthenticationCode in const [
      'user-mismatch',
      'user-not-found',
      'invalid-credential',
      'user-token-expired',
    ])
      'when Firebase answers the sign-in again with $reauthenticationCode':
          await deleting(
        appleOf('fresh', code: code),
        platform: TargetPlatform.iOS,
        failing: {
          'reauthenticateWithCredential':
              FirebaseAuthException(code: reauthenticationCode),
        },
      ),
    // A credential of the user, whose account was deleted on the server.
    'when the account was deleted on the server': await deleting(
      appleOf('fresh', code: code),
      platform: TargetPlatform.iOS,
      failing: {
        'reauthenticateWithCredential':
            FirebaseAuthException(code: 'user-not-found'),
        'reload': FirebaseAuthException(code: 'user-not-found'),
      },
    ),
    'when the reload after user-not-found fails with network-request-failed':
        await deleting(
      appleOf('fresh', code: code),
      platform: TargetPlatform.iOS,
      failing: {
        'reauthenticateWithCredential':
            FirebaseAuthException(code: 'user-not-found'),
        'reload': FirebaseAuthException(code: 'network-request-failed'),
      },
    ),
    for (final (revocationCode, message) in const [
      ('invalid-credential', 'Code flow is not enabled for Apple.'),
      ('internal-error', 'An internal error has occurred.'),
      ('network-request-failed', 'Network error.'),
      ('too-many-requests', 'Too many requests.'),
      ('user-disabled', 'The user account has been disabled.'),
      ('user-token-expired', 'The user token has expired.'),
    ])
      'when Firebase answers the revocation with $revocationCode':
          await deleting(
        appleOf('fresh', code: code),
        platform: TargetPlatform.iOS,
        failing: {
          'revokeTokenWithAuthorizationCode':
              FirebaseAuthException(code: revocationCode, message: message),
        },
      ),
    'when the revocation fails with no error of Firebase': await deleting(
      appleOf('fresh', code: code),
      platform: TargetPlatform.iOS,
      failing: {'revokeTokenWithAuthorizationCode': StateError('broken')},
    ),
    'when the platform signs out during the sign-in again': await deleting(
      appleOf('fresh', code: code),
      platform: TargetPlatform.iOS,
      onReauthentication: platformSignsOut,
    ),
  };
  await signIn();

  final ended = <String, Object?>{};
  for (final code in const [
    'user-token-expired',
    'invalid-user-token',
    'user-not-found',
    'no-current-user',
  ]) {
    await service.signInAnonymously();
    failNext['delete'] = FirebaseAuthException(code: code);
    ended['delete: $code'] = await step(service.deleteAccount);
    await service.signInAnonymously();
    failNext['linkWithCredential'] = FirebaseAuthException(code: code);
    ended['linkWithCredential: $code'] = await step(
      () => service.linkPassword(email: 'b@x.dev', password: password),
    );
  }
  result['ended session'] = ended;

  await signIn();
  failNext['delete'] = FirebaseAuthException(code: 'requires-recent-login');
  result['deletion that needs a recent sign-in'] =
      await step(service.deleteAccount);

  Future<String> failing(String code, [String? message]) {
    failNext['signInWithEmailAndPassword'] =
        FirebaseAuthException(code: code, message: message);
    return outcomeOf(signIn);
  }

  result['not configured'] = [
    await failing('operation-not-allowed', 'The provider is disabled.'),
    await failing('admin-restricted-operation'),
    await failing(
      'unknown',
      'An internal error has occurred. [ CONFIGURATION_NOT_FOUND',
    ),
    // As iOS tells of it: in the description of an internal error, over
    // several lines.
    await failing(
      'internal-error',
      'Error Domain=FIRAuthErrorDomain Code=17999 UserInfo={\n'
          '    NSUnderlyingError=0x600000c5e910;\n'
          '    message = "CONFIGURATION_NOT_FOUND";\n'
          '}',
    ),
  ];
  final internal = <String, Object?>{};
  for (final platform in TargetPlatform.values) {
    defaultTargetPlatform = platform;
    internal[platform.name] = await failing('internal-error', 'Internal.');
  }
  defaultTargetPlatform = TargetPlatform.android;
  result['internal error'] = internal;
  result['unknown'] = [
    await failing('app-not-authorized', 'Not authorized.'),
    await failing('unknown', 'Something else.'),
    await failing('keychain-error', 'Error Domain=X {\n    reason = 1;\n}'),
    await failing('quota-exceeded'),
  ];
  failNext['signInWithEmailAndPassword'] = StateError('broken');
  result['no error of Firebase'] = await outcomeOf(signIn);

  await settle();
  heard.clear();
  platformSignsOut();
  await settle();
  result['a sign-out of Firebase'] = [userOf(service.currentUser), [...heard]];
  heard.clear();
  platformFails(StateError('stream'));
  await settle();
  result['an error of the stream of Firebase'] = [...heard];

  await subscription.cancel();
  await settle();
  final withoutListener = userChangesListeners;
  subscription = service.userChanges.listen((_) {});
  await settle();
  result['streams of Firebase'] = [
    ...result['streams of Firebase']! as List<Object?>,
    withoutListener,
    userChangesListeners,
  ];
  await subscription.cancel();

  await signIn();
  result['a service created again'] =
      userOf(createFirebaseAuthService().currentUser);
  port.send(result);
}
''';

void main() {
  const module = FirebaseAuthModule();

  group('FirebaseAuthModule', () {
    test(
        'is infrastructure that provides the auth role, depends on '
        'firebase_core and uses the localization role', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('firebase_auth'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {authRole});
      expect(descriptor.dependsOn, {FirebaseCoreModule.id});
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, {localizationRole});
      expect(descriptor.effectiveUses, {...authRole.uses, localizationRole});
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, firebase_auth, its implementation of the '
        'service, created without waiting, the check and the step that '
        'enable the ways to sign in, its section of the README and its note '
        'for coding agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(7));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(firebaseAuthBundle));
      expect(brick.bundle.name, 'firebase_auth');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [_implementation, enableSignInScript],
      );
      expect(brick.when, isEmpty);
      final dependency = contributions[1] as PubspecDependency;
      expect(dependency.package, 'firebase_auth');
      expect(dependency.constraint, '^6.7.0');
      expect(dependency.dev, isFalse);
      final data = contributions[2] as RoleData<Object>;
      expect(data.role, authRole);
      final implementation = (data.value as AuthImplementation).implementation;
      expect(implementation.isAsync, isFalse);
      expect(implementation.type.name, 'FirebaseAuthService');
      expect(implementation.create!.name, 'createFirebaseAuthService');
      expect(implementation.create!.deps, isEmpty);
      expect(
        implementation.type.import,
        const ImportRef.app('core/auth/firebase_auth_service.dart'),
      );
      expect(implementation.create!.import, implementation.type.import);
      expect('lib/${implementation.type.import!.uri}', serviceFile);
      expect(serviceFile, _implementation);
      final preflight = contributions[3] as Preflight;
      expect(preflight.checks, [same(firebaseCliWithSignIn)]);
      expect(preflight.when, isEmpty);
      expect(contributions[4], same(enableSignIn));
      final readme = contributions[5] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, readmeHeading);
      expect(readme.entryValue, readmeSection);
      expect(readme.when, isEmpty);
      final note = contributions[6] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, authRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
    });

    test(
        'gives its brick the code that asks Firebase for its messages in '
        'the language of the app, for an app with the localization role, '
        'and no code for an app without it', () {
      final brick = module.contribute(ContractHarness.defaultContext).first
          as BrickContribution;

      expect(brick.vars.keys, [
        'email_language',
        'session_file',
        'mode_declaration',
        'anonymous_mode',
        'minimum_firebase_cli',
      ]);
      final language = brick.vars['email_language']! as RoleVar;
      expect(language.role, localizationRole);
      expect(language.absent, '');
      final present = language.present as Fragment;
      expect(
        present.code,
        allOf(
          startsWith('// The message is in the language that the app is in.'),
          contains('await _auth.setLanguageCode('),
          endsWith(');'),
        ),
      );
      // The file of the role with the languages of the app, and the
      // function with which the root of the app resolves the language of
      // the device.
      expect(present.imports, const [
        ImportRef(
          'package:flutter/widgets.dart',
          show: ['WidgetsBinding', 'basicLocaleListResolution'],
        ),
        ImportRef.app('core/l10n/app_locale.dart'),
      ]);
      expect(
        'lib/${present.imports.last.uri}',
        LocalizationRole.appLocaleFile,
      );
    });

    test(
        'gives its brick, for the script that enables the ways to sign in, '
        'what the auth role says of the mode of the app, its file, how a '
        'tool reads the mode there and the mode with anonymous users, and '
        'the first Firebase CLI whose command adds no web app to a project '
        'with Android and iOS apps', () {
      final brick = module.contribute(ContractHarness.defaultContext).first
          as BrickContribution;

      expect(brick.vars['session_file'], AuthRole.sessionFile);
      expect(brick.vars['mode_declaration'], modeDeclarationCode);
      expect(modeDeclarationCode, rawStringsOf(AuthRole.modeDeclaration));
      expect(brick.vars['anonymous_mode'], 'anonymous');
      expect(AuthMode.anonymous.name, 'anonymous');
      expect(brick.vars['minimum_firebase_cli'], '15.34.0');
      expect(firstFirebaseCliWithSignIn, '15.34.0');
    });

    test(
        'writes a regular expression as raw strings of Dart, each on a line '
        'that fits, which end before an alternative where they can and '
        'never with a backslash', () {
      /// The pattern that the strings of [code] make together, and the
      /// widths of its lines.
      (String, List<int>) read(String code) => (
            [
              for (final string in RegExp("r'([^']*)'").allMatches(code))
                string[1],
            ].join(),
            [for (final line in code.split('\n')) line.length],
          );

      // One that fits is one string.
      expect(rawStringsOf(r'^a\s+b$'), r"r'^a\s+b$'");
      // The expression of the auth role ends its strings before
      // alternatives.
      final ofRole = rawStringsOf(AuthRole.modeDeclaration);
      expect(read(ofRole).$1, AuthRole.modeDeclaration);
      expect(ofRole.split('\n'), hasLength(3));
      expect(
        ofRole.split('\n').skip(1),
        everyElement(startsWith("  r'|")),
      );
      expect(read(ofRole).$2, everyElement(lessThanOrEqualTo(78)));
      // One without an alternative is cut where a line is full, but not
      // after a backslash.
      final digits = '${'a' * 71}${r'\d' * 40}';
      final cut = rawStringsOf(digits);
      expect(read(cut).$1, digits);
      expect(cut.split('\n').first, "r'${'a' * 71}'");
      expect(read(cut).$2, everyElement(lessThanOrEqualTo(78)));
      expect(cut, isNot(contains(r"\'")));
    });

    test(
        'checks the machine for a Firebase CLI whose command enables the '
        'ways to sign in without a web app, with the check of firebase_core',
        () {
      expect(firebaseCliWithSignIn, isA<FirebaseCliVersionCheck>());
      expect(firebaseCliWithSignIn.minimum, '15.34.0');
      expect(
        firebaseCliWithSignIn.description,
        'Firebase CLI 15.34.0 or later',
      );
    });

    test(
        'continues the step of firebase_core that runs flutterfire '
        'configure with the script of the app that enables the ways to sign '
        'in, which is part of that step', () {
      final step = module
          .contribute(ContractHarness.defaultContext)
          .whereType<PostGenStep>()
          .single;

      expect(step.followUpOf, FirebaseCoreModule.configureStep);
      // The Dart of the Flutter SDK of the run, which needs none of the
      // packages of the app for the script.
      expect(step.tool.executable, 'dart');
      expect(step.tool.prefixArgs, isEmpty);
      expect(step.tool.environment, isEmpty);
      expect(step.arguments, ['tool/enable_firebase_sign_in.dart']);
      expect(enableSignInScript, step.arguments.single);
      expect(enableSignInCommand, 'dart ${step.arguments.single}');
      expect(
        step.description,
        'Enabling the sign-in methods of the app in its Firebase project',
      );
      // The Firebase CLI that the step needs adds no app to a project with
      // the apps that flutterfire registered, so a run asks only about
      // flutterfire configure.
      expect(step.notice, isNull);
      expect(step.skippable, isTrue);
      expect(step.external, isTrue);
      // The script passes --non-interactive to the Firebase CLI, so the
      // step needs no terminal.
      expect(step.interactive, isFalse);
      expect(step.needs, [firebaseCliWithSignIn.id]);
      expect(step.hosts, isEmpty);
      expect(step.when, isEmpty);
      expect(step.id, isNull);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test(
        'builds the apps of the module with the localization role, which it '
        'uses, and the router role, which the auth role uses, and without '
        'each, and an app for each other mode of the auth role', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router, localization',
        'flutter_core with router',
        'flutter_core with localization',
        'flutter_core',
        'firebase_core',
        'firebase_auth with localization, router',
        'firebase_auth with localization',
        'firebase_auth with router',
        'firebase_auth',
        'shared_preferences',
        for (final mode in ['guest', 'anonymous'])
          'auth by firebase_auth with router, localization --auth-mode=$mode',
      ]);
    });

    test('finds no errors in any app, rendered code included', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });

    test(
        'takes an app with the ways to sign in of Google and Apple, and '
        'refuses one with a way to sign in of another identity provider, '
        'whose credential the service does not take, in the validate hook of '
        'its provider', () async {
      final harness = ContractHarness(
        ModuleRegistry([
          ..._modules,
          _WayOfTest.google,
          _WayOfTest.apple,
          _WayOfTest.other,
        ]),
      );
      final taken = await harness.check(
        ContractCase(
          'firebase_auth with the ways to sign in of Google and Apple',
          requested: [
            FirebaseAuthModule.id,
            _WayOfTest.google.id,
            _WayOfTest.apple.id,
          ],
        ),
      );
      final refused = await harness.check(
        ContractCase(
          'firebase_auth with a way to sign in of another identity provider',
          requested: [
            FirebaseAuthModule.id,
            _WayOfTest.apple.id,
            _WayOfTest.other.id,
          ],
        ),
      );

      expect(taken.errors.map((issue) => '$issue'), isEmpty);
      expect(
        [
          for (final AppSignInMethod(:method)
              in authRole.methodsIn(authRole.hookInput(taken.hook!)))
            method.issuer,
        ],
        identityProviders.keys,
      );
      expect(
        [
          for (final issue in refused.errors)
            (issue.origin, issue.message, issue.hint),
        ],
        [
          (
            ModuleOrigin(_WayOfTest.other.id),
            'The module way_of_test gives the app a way to sign in with '
                'https://accounts.example.com, whose credential firebase_auth '
                'does not take: it signs in to Firebase Authentication with '
                'the credentials of Google (https://accounts.google.com) and '
                'Apple (https://appleid.apple.com), besides an email address '
                'and a password, and as an anonymous user. A sign-in with it '
                'would fail with notConfigured.',
            'Leave way_of_test out of an app with firebase_auth.',
          ),
        ],
      );
      // The apps of the module alone have no way to sign in, and no error.
      expect(
        [
          for (final result in results)
            for (final issue in result.errors) '${result.contractCase}: $issue',
        ],
        isEmpty,
      );
    });

    test(
        'renders a service that takes the credentials of the identity '
        'providers that its provider takes, and only those', () {
      final app = results
          .firstWhere(
            (result) => result.app!.files.containsKey(_implementation),
          )
          .app!;
      final constants = {
        for (final declaration in _unitOf(app, _implementation)
            .declarations
            .whereType<TopLevelVariableDeclaration>())
          for (final variable in declaration.variables.variables)
            variable.name.lexeme: variable.initializer,
      };
      String valueOf(Expression? expression) =>
          (expression! as SimpleStringLiteral).value;
      final providers = constants['_providers']! as SetOrMapLiteral;

      expect(
        {
          for (final entry in providers.elements.cast<MapLiteralEntry>())
            valueOf(constants[(entry.key as SimpleIdentifier).name]):
                '${entry.value}',
        },
        {
          'https://accounts.google.com': "(id: 'google.com', name: 'Google')",
          'https://appleid.apple.com': "(id: 'apple.com', name: 'Apple')",
        },
      );
      expect(identityProviders, {
        'https://accounts.google.com': 'Google',
        'https://appleid.apple.com': 'Apple',
      });
    });

    test(
        'renders code of the service that type-checks with firebase_auth, '
        'and a script that type-checks with the Dart SDK alone, in the apps '
        'with the localization role and in the apps without it', () async {
      final withService = [
        for (final result in results)
          if (result.app!.files.containsKey(_implementation)) result,
      ];
      expect(withService, hasLength(6));
      for (final result in withService) {
        // The files of the module that the analyzer checks.
        expect(
          [
            for (final file in result.app!.files.values)
              if (file.owner == const ModuleOrigin(FirebaseAuthModule.id))
                file.path,
          ],
          [_implementation, enableSignInScript],
          reason: '${result.contractCase}',
        );
        final app = DartApp.write(result.app!);
        try {
          expect(
            await app.analysisProblems(
              {const ModuleOrigin(FirebaseAuthModule.id)},
            ),
            isEmpty,
            reason: '${result.contractCase}',
          );
        } finally {
          app.delete();
        }
      }
    });

    test(
        'renders the same service and the same script in every mode of the '
        'auth role, in an app with a router and in one without', () {
      final services = [
        for (final result in results)
          if (result.app!.files[_implementation] case final file?)
            (
              mode: authRole.modeIn(authRole.hookInput(result.hook!)),
              router: result.hook!.presentRoles.contains(routerRole),
              texts: result.hook!.presentRoles.contains(localizationRole),
              service: file.text,
              script: result.app!.files[enableSignInScript]!.text,
            ),
      ];

      expect(
        [for (final app in services) (app.mode, app.router, app.texts)],
        [
          (AuthMode.required, true, true),
          (AuthMode.required, false, true),
          (AuthMode.required, true, false),
          (AuthMode.required, false, false),
          (AuthMode.guest, true, true),
          (AuthMode.anonymous, true, true),
        ],
      );
      // The service asks Firebase for the language of the app only in an
      // app with the texts of the app.
      for (final texts in [true, false]) {
        expect(
          {
            for (final app in services)
              if (app.texts == texts) app.service,
          },
          hasLength(1),
        );
      }
      // The script reads the mode from the file of the auth role when it
      // runs, so it follows a mode that the developer of the app changed.
      expect({for (final app in services) app.script}, hasLength(1));
    });

    test(
        'enables the ways to sign in right after flutterfire configure of '
        'firebase_core, which the step continues, and checks the machine '
        'for the Firebase CLI of the step after the checks of '
        'firebase_core', () {
      final apps = [
        for (final result in results)
          if (result.resolution!.modules
              .any((module) => module.id == FirebaseAuthModule.id))
            result,
      ];

      expect(apps, hasLength(6));
      for (final result in apps) {
        final steps = [
          for (final collected in result.validation!.postGenOrder.contributions)
            (
              '${collected.origin}',
              collected.contribution as PostGenStep,
            ),
        ];
        expect(
          [for (final (origin, step) in steps) (origin, step.id)],
          [
            ('firebase_core', FirebaseCoreModule.configureStep),
            ('firebase_auth', null),
          ],
          reason: '${result.contractCase}',
        );
        expect(steps.last.$2, same(enableSignIn));
      }
    });
  });

  group('an app with the module', () {
    late ContractResult result;
    late RenderedApp app;
    late ContractResult resultWithout;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [FirebaseAuthModule.id]);
      app = result.app!;
      resultWithout = await _resultOf(const [FirebaseCoreModule.id]);
      without = resultWithout.app!;
    });

    test(
        'is the app of Firebase but for the files of the auth role, the '
        'service, the script that enables the ways to sign in, '
        'firebase_auth, the start of the session, and the sections of '
        'sign-in in the README and in the guide for coding agents', () {
      expect(app.files.keys.toSet(), {
        ...without.files.keys,
        AuthRole.serviceFile,
        AuthRole.sessionFile,
        AuthRole.guestDataFile,
        AuthRole.methodsFile,
        _implementation,
        enableSignInScript,
      });
      for (final path in [_implementation, enableSignInScript]) {
        expect(
          app.files[path]!.owner,
          const ModuleOrigin(FirebaseAuthModule.id),
          reason: path,
        );
      }
      // Its native files, the manifest of Android, the Gradle files, the
      // Info.plist and the Xcode project among them, are those of the app
      // of Firebase: the module sets up nothing of the platforms.
      final changed = <String>[];
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        expect(app.files[path]!.owner, file.owner, reason: path);
        if (app.files[path]!.text != file.text) changed.add(path);
      }
      // The provider of the app entry renders the start-up, which now
      // starts the session, into a file of its own, whichever module it is.
      final startUp = [
        for (final path in changed)
          if (app.files[path]!.addedImports.any(
            (added) => added.contributor == const RoleTemplateOrigin(authRole),
          ))
            path,
      ];
      expect(startUp, hasLength(1));
      expect(
        {
          for (final module in result.resolution!.providersOf(appEntryRole))
            ModuleOrigin(module.id),
        },
        contains(app.files[startUp.single]!.owner),
      );
      expect(
        changed.toSet().difference(startUp.toSet()),
        {'pubspec.yaml', AppEntryRole.readmeFile, AppEntryRole.agentsFile},
      );
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['dependencies'],
        {
          'firebase_auth': '^6.7.0',
          'firebase_core': '^4.15.0',
          'flutter': {'sdk': 'flutter'},
        },
      );
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['environment'],
        _yamlOf(without.files['pubspec.yaml']!.text)['environment'],
      );
    });

    test(
        'starts the session of the app in bootstrap() once Firebase is '
        'initialized', () {
      // The template of the role comes after its provider and the module
      // that it depends on: firebase_core, whose Firebase app the service
      // works on.
      expect(_startUpOf(result), [
        'firebase_core: $_initializeFirebase',
        'role:auth: await initAuth();',
      ]);
    });

    test(
        'creates the service of the module in initAuth(), without waiting '
        'for it', () {
      final file = app.files[AuthRole.sessionFile]!;
      final init = _unitOf(app, AuthRole.sessionFile)
          .declarations
          .whereType<FunctionDeclaration>()
          .singleWhere((function) => function.name.lexeme == 'initAuth');
      final body = init.functionExpression.body as BlockFunctionBody;

      expect(
        [for (final statement in body.block.statements) '$statement'],
        [
          '_authService = impl0.createFirebaseAuthService();',
          'await appSession.start(_authService);',
        ],
      );
      expect(
        [
          for (final added in file.addedImports)
            (added.import.uri, added.import.prefix, '${added.contributor}'),
        ],
        [
          (
            'package:contract_app/core/auth/firebase_auth_service.dart',
            'impl0',
            'role:auth',
          ),
        ],
      );
    });

    group('the implementation', () {
      late CompilationUnit unit;

      setUpAll(() => unit = _unitOf(app, _implementation));

      test('is the service of the role on the FirebaseAuth of the app', () {
        final declaration =
            unit.declarations.whereType<ClassDeclaration>().single;
        expect(
          '${declaration.implementsClause!.interfaces.single}',
          'AuthService',
        );
        final factory =
            unit.declarations.whereType<FunctionDeclaration>().single;
        expect(factory.name.lexeme, 'createFirebaseAuthService');
        expect('${factory.returnType}', 'AuthService');
        expect(factory.functionExpression.parameters!.parameters, isEmpty);
        final body = factory.functionExpression.body as ExpressionFunctionBody;
        expect(
          '${body.expression}',
          'FirebaseAuthService(FirebaseAuth.instance)',
        );
        expect(_importsOf(unit), [
          "import 'dart:async';",
          "import 'package:firebase_auth/firebase_auth.dart';",
          "import 'package:flutter/foundation.dart';",
          "import 'auth_service.dart';",
        ]);
      });

      test(
          'implements every member of the service with the signature of the '
          'interface', () {
        String signatureOf(MethodDeclaration method) =>
            '${method.returnType} ${method.propertyKeyword ?? ''} '
            '${method.parameters ?? ''}';
        final interface = _methodsOf(
          _unitOf(app, AuthRole.serviceFile),
          'AuthService',
        );

        expect(
          {
            for (final MapEntry(key: name, value: method)
                in _methodsOf(unit, 'FirebaseAuthService').entries)
              if (!name.startsWith('_')) name: signatureOf(method),
          },
          {
            for (final MapEntry(key: name, value: method) in interface.entries)
              name: signatureOf(method),
          },
        );
        expect(interface.keys, hasLength(11));
      });

      test('asks Firebase for no language before a password reset', () {
        expect(
          _passwordResetOf(app),
          ['_checkGiven(email);', startsWith('try {')],
        );
      });
    });

    group('the service', () {
      late Map<Object?, Object?> sent;

      setUpAll(() async {
        final dartApp = DartApp.write(app);
        try {
          sent = (await dartApp.run(_script, arguments: [..._reasons.keys]))!
              as Map<Object?, Object?>;
        } finally {
          dartApp.delete();
        }
      });

      test('is created with nobody on a device without a user', () {
        expect(sent['implementation'], 'FirebaseAuthService');
        expect(sent['user at first'], 'nobody');
      });

      test(
          'has no address for an anonymous user whom Android kept on the '
          'device, though Firebase has an empty one', () {
        expect(
          sent['an anonymous user of Android'],
          ['', 'kept <null>, anonymous', null],
        );
      });

      test(
          'makes the call of Firebase for each of its calls, has the user '
          'of that call when it completes, and tells its listener of that '
          'user', () {
        const account = 'uid of a@x.dev <a@x.dev>';
        const guest = 'guest 1 <null>, anonymous';
        const linked = 'guest 1 <b@x.dev>';
        expect(sent['calls'], {
          'signUp': [
            'completed',
            account,
            ['createUserWithEmailAndPassword(a@x.dev, secret)'],
            [account],
          ],
          'signOut': [
            'completed',
            'nobody',
            ['signOut()'],
            ['nobody'],
          ],
          'signIn': [
            'completed',
            account,
            ['signInWithEmailAndPassword(a@x.dev, secret)'],
            [account],
          ],
          // The user stays, and the app without the localization role sets
          // no language.
          'sendPasswordReset': [
            'completed',
            account,
            ['sendPasswordResetEmail(a@x.dev)'],
            [account],
          ],
          'signInAnonymously': [
            'completed',
            guest,
            ['signInAnonymously()'],
            [guest],
          ],
          // The anonymous user keeps the id.
          'linkPassword': [
            'completed',
            linked,
            ['linkWithCredential(password of b@x.dev: secret)'],
            [linked],
          ],
          // The plugin keeps a deleted user as its current one, so the
          // service signs out.
          'deleteAccount': [
            'completed',
            'nobody',
            ['delete()', 'signOut()'],
            ['nobody'],
          ],
          // Without a user, a call for the user who is signed in fails
          // before it reaches Firebase.
          'deleteAccount without a user': [
            'recentSignInRequired',
            'nobody',
            <Object?>[],
            ['nobody'],
          ],
          'linkPassword without a user': [
            'recentSignInRequired',
            'nobody',
            <Object?>[],
            ['nobody'],
          ],
        });
        expect(sent['a broadcast stream'], isTrue);
      });

      group('with the credentials of identity providers', () {
        const google = 'https://accounts.google.com';
        const apple = 'https://appleid.apple.com';
        const link = 'https://console.firebase.google.com/project/'
            'stand-in-project/authentication/providers';
        const ofApple = 'apple.com of token-refused, nonce nonce-refused, '
            'name Ada Lovelace';
        const deleted = 'uid of token-deleted <null> with $apple';
        const reauthentication = 'reauthenticateWithCredential(apple.com of '
            'token-fresh, nonce nonce-fresh, name Ada Lovelace)';
        const revocation = 'revokeTokenWithAuthorizationCode(code-fresh)';
        const notOfFirebase = 'notConfigured: The app signs in to Firebase '
            'Authentication with the credentials of Google ($google) and '
            'Apple ($apple), and takes no credential of '
            'https://accounts.example.com.';

        /// A step that failed with [outcome] and left [user] signed in,
        /// with the calls [calls] of Firebase.
        List<Object?> leaving(
          String outcome,
          String user, [
          List<String> calls = const [],
        ]) =>
            [
              outcome,
              user,
              calls,
              [user],
            ];

        test(
            'signs in and links with the credential of Google, with its ID '
            'token, and of Apple, with its ID token, its raw nonce and the '
            'name of the user, and lists the issuers of the identities of '
            'the user', () {
          final credentials = sent['credentials']! as Map<Object?, Object?>;
          const ofGoogle = 'uid of token-g <null> with $google';
          const ofAppleUser = 'uid of token-a <null> with $apple';
          const linked = 'guest 4 <null> with $google';
          const signInOfApple = 'signInWithCredential(apple.com of token-a, '
              'nonce nonce-a, name Ada Lovelace)';
          expect(credentials, {
            // GoogleAuthProvider takes no nonce, and Firebase does not check
            // the nonce of a token of Google.
            'signInWith of Google': [
              'completed',
              ofGoogle,
              ['signInWithCredential(google.com of token-g)'],
              [ofGoogle],
            ],
            'signInWith of Apple': [
              'completed',
              ofAppleUser,
              [signInOfApple],
              [ofAppleUser],
            ],
            'signInWith of Apple without a nonce': leaving(
              'notConfigured: The credential of Apple has no raw nonce, which '
              'Firebase checks the token of Apple against. The way to '
              'sign in with Apple gives the nonce of its request with each '
              'credential.',
              ofAppleUser,
            ),
            'signInWith of another identity provider':
                leaving(notOfFirebase, ofAppleUser),
            'signInAnonymously': [
              'completed',
              'guest 4 <null>, anonymous',
              ['signInAnonymously()'],
              ['guest 4 <null>, anonymous'],
            ],
            // The anonymous user keeps the id.
            'linkWith of Google': [
              'completed',
              linked,
              ['linkWithCredential(google.com of token-linked)'],
              [linked],
            ],
            'linkWith of another identity provider':
                leaving(notOfFirebase, linked),
            'signOut': [
              'completed',
              'nobody',
              ['signOut()'],
              ['nobody'],
            ],
            'linkWith without a user':
                leaving('recentSignInRequired', 'nobody'),
          });
        });

        test(
            'fails a link that Firebase refuses for an identity or an email '
            'address of another user with the reason of the auth role, and '
            'signs in with the credential that Firebase gave with its answer '
            'when the identical credential object comes next, once', () {
          /// The steps of a link of the anonymous user [guest] that
          /// failed with [outcome], and of the two sign-ins with the
          /// identical credential after it, the first of which signs in
          /// with [first], what Firebase gave or the credential itself.
          List<Object?> refusedLink(
            String outcome,
            String guest, {
            required String first,
          }) {
            final user = 'uid of $first <null> with $apple';
            const again = 'uid of token-refused <null> with $apple';
            return [
              leaving(outcome, '$guest <null>, anonymous', [
                'linkWithCredential($ofApple)',
              ]),
              [
                'completed',
                user,
                [
                  if (first == '7')
                    'signInWithCredential(apple.com credential 7)'
                  else
                    'signInWithCredential($ofApple)',
                ],
                [user],
              ],
              [
                'completed',
                again,
                ['signInWithCredential($ofApple)'],
                [again],
              ],
            ];
          }

          expect(sent['refused links'], {
            'credential-already-in-use':
                refusedLink('credentialInUse', 'guest 5', first: '7'),
            'email-already-in-use': refusedLink(
              'accountExistsWithOtherMethod',
              'guest 6',
              first: '7',
            ),
            'account-exists-with-different-credential': refusedLink(
              'accountExistsWithOtherMethod',
              'guest 7',
              first: '7',
            ),
            // Without what Firebase gives, the credential itself.
            'a refusal without a credential': refusedLink(
              'credentialInUse',
              'guest 8',
              first: 'token-refused',
            ),
            // The session links an identity only to an anonymous user.
            'provider-already-linked': refusedLink(
              'unknown: provider-already-linked: User has already been '
                  'linked to the given provider.',
              'guest 9',
              first: 'token-refused',
            ),
          });
          // A sign-in with another credential object between the two
          // signs in with its own token, and leaves what Firebase gave to
          // the identical object.
          const between = 'uid of token-between <null> with $google';
          const owner = 'uid of 7 <null> with $apple';
          expect(sent['another credential after a refused link'], [
            leaving('credentialInUse', 'guest 10 <null>, anonymous', [
              'linkWithCredential($ofApple)',
            ]),
            [
              'completed',
              'nobody',
              ['signOut()'],
              ['nobody'],
            ],
            [
              'completed',
              between,
              ['signInWithCredential(google.com of token-between)'],
              [between],
            ],
            [
              'completed',
              owner,
              ['signInWithCredential(apple.com credential 7)'],
              [owner],
            ],
          ]);
          // The same codes for a link of a password are an email address
          // with an account.
          expect(sent['refused links of a password'], {
            'email-already-in-use': 'emailInUse',
            'credential-already-in-use': 'emailInUse',
          });
        });

        test(
            'gives a sign-in with a credential the reason of the auth role '
            'for each code of Firebase, and names its way to sign in in the '
            'hint of one that is not enabled', () {
          String notEnabled(String method) =>
              'notConfigured: Sign-in with $method is not enabled in the '
              'Firebase project stand-in-project (Firebase answered '
              'operation-not-allowed). To fix it, enable $method in the '
              'Firebase console under Authentication > Sign-in method: $link';
          expect(sent['refused sign-ins'], {
            'account-exists-with-different-credential':
                'accountExistsWithOtherMethod',
            'missing-or-invalid-nonce': 'invalidCredentials',
            'invalid-credential': 'invalidCredentials',
            'operation-not-allowed of Google': notEnabled('Google'),
            'operation-not-allowed of Apple': notEnabled('Apple'),
          });
          expect(
            sent['an internal error of a sign-in with Apple on iOS'],
            'notConfigured: Firebase reported an internal error '
            '(internal-error: Internal.), which is also what it answers on '
            'iOS and macOS when sign-in with Apple is not enabled in the '
            'Firebase project stand-in-project. If that is the cause, enable '
            'Apple in the Firebase console under Authentication > Sign-in '
            'method: $link',
          );
        });

        test(
            'deletes an account with a fresh credential once it signed the '
            'user in again with it, and revokes the tokens of Apple with the '
            'authorization code of the credential first, on iOS and macOS', () {
          final deletions = sent['deletions']! as Map<Object?, Object?>;
          const ofGoogle = 'reauthenticateWithCredential(google.com of '
              'token-deleted)';
          expect(
            {
              for (final name in [
                'of Google',
                'of Google on iOS',
                'of Apple on Android',
                'of Apple on iOS',
                'of Apple on macOS',
              ])
                name: deletions[name],
            },
            {
              for (final name in ['of Google', 'of Google on iOS'])
                name: [
                  'completed',
                  'nobody',
                  [ofGoogle, 'delete()', 'signOut()'],
                  ['nobody'],
                ],
              // Firebase revokes nothing on Android.
              'of Apple on Android': [
                'completed',
                'nobody',
                [reauthentication, 'delete()', 'signOut()'],
                ['nobody'],
              ],
              for (final platform in ['iOS', 'macOS'])
                'of Apple on $platform': [
                  'completed',
                  'nobody',
                  [reauthentication, revocation, 'delete()', 'signOut()'],
                  ['nobody'],
                ],
            },
          );
        });

        test(
            'deletes nothing when the sign-in again or the revocation fails, '
            'and fails with invalidCredentials for a credential of another '
            'identity and with notConfigured for a revocation, with a hint '
            'that tells how to set the revocation up', () {
          final deletions = sent['deletions']! as Map<Object?, Object?>;
          const byRevocation = 'when Firebase answers the revocation with';
          String notRevoked(String answer) =>
              'notConfigured: Firebase did not revoke the tokens that Apple '
              'gave the app ($answer), so the account was not deleted. The '
              'revocation needs the Services ID and the OAuth code flow '
              'configuration, with the Apple team ID, the Key ID and the '
              'private key, of the Apple sign-in method of the Firebase '
              'project stand-in-project, in the Firebase console under '
              'Authentication > Sign-in method: $link. When they are set, the '
              'authorization code of Apple was older than five minutes or '
              'used before, and the next deletion asks Apple for a new one.';
          expect(
            {
              for (final MapEntry(:key, :value) in deletions.entries)
                if (!'$key'.startsWith('of ')) key: value,
              'of Apple on iOS without a code':
                  deletions['of Apple on iOS without a code'],
            },
            {
              'of Apple on iOS without a code': leaving(
                'notConfigured: The credential of Apple has no authorization '
                'code, with which Firebase revokes the tokens that Apple '
                'gave the app before the account is deleted, so the '
                'account was not deleted. The way to sign in with Apple '
                'gives one with each credential.',
                deleted,
              ),
              // A credential of another user.
              for (final code in ['user-mismatch', 'invalid-credential'])
                'when Firebase answers the sign-in again with $code': leaving(
                  'invalidCredentials',
                  deleted,
                  [reauthentication],
                ),
              // A credential of an identity without a user, which Firebase
              // answers as for a user whose session has ended: the reload
              // of the user tells it from an account deleted on the server.
              'when Firebase answers the sign-in again with user-not-found':
                  leaving(
                'invalidCredentials',
                deleted,
                [reauthentication, 'reload()'],
              ),
              'when the account was deleted on the server': [
                'recentSignInRequired',
                'nobody',
                [reauthentication, 'reload()', 'signOut()'],
                ['nobody'],
              ],
              'when the reload after user-not-found fails with '
                  'network-request-failed': leaving(
                'network',
                deleted,
                [reauthentication, 'reload()'],
              ),
              'when Firebase answers the sign-in again with user-token-expired':
                  [
                'recentSignInRequired',
                'nobody',
                [reauthentication, 'signOut()'],
                ['nobody'],
              ],
              '$byRevocation invalid-credential': leaving(
                notRevoked(
                  'invalid-credential: Code flow is not enabled for Apple.',
                ),
                deleted,
                [reauthentication, revocation],
              ),
              '$byRevocation internal-error': leaving(
                notRevoked('internal-error: An internal error has occurred.'),
                deleted,
                [reauthentication, revocation],
              ),
              // An answer that is no matter of the setup.
              for (final (code, reason) in [
                ('network-request-failed', 'network'),
                ('too-many-requests', 'tooManyAttempts'),
                ('user-disabled', 'userDisabled'),
              ])
                '$byRevocation $code': leaving(
                  reason,
                  deleted,
                  [reauthentication, revocation],
                ),
              '$byRevocation user-token-expired': [
                'recentSignInRequired',
                'nobody',
                [reauthentication, revocation, 'signOut()'],
                ['nobody'],
              ],
              'when the revocation fails with no error of Firebase': leaving(
                notRevoked('Bad state: broken'),
                deleted,
                [reauthentication, revocation],
              ),
              // The future of the revocation would never complete.
              'when the platform signs out during the sign-in again': [
                'recentSignInRequired',
                'nobody',
                [reauthentication],
                ['nobody'],
              ],
            },
          );
        });

        test('names no token and no authorization code in a hint', () {
          final outcomes = [
            for (final section in [
              sent['credentials'],
              sent['deletions'],
            ])
              for (final step in (section! as Map<Object?, Object?>).values)
                (step! as List<Object?>).first,
            for (final steps
                in (sent['refused links']! as Map<Object?, Object?>).values)
              for (final step in steps! as List<Object?>)
                (step! as List<Object?>).first,
            for (final step in sent['another credential after a refused link']!
                as List<Object?>)
              (step! as List<Object?>).first,
            ...(sent['refused sign-ins']! as Map<Object?, Object?>).values,
          ];
          expect(outcomes, hasLength(53));
          expect(outcomes, everyElement(isNot(contains('token-'))));
          expect(outcomes, everyElement(isNot(contains('code-'))));
        });
      });

      test(
          'gives each code of Firebase its reason of the auth role, and '
          'leaves the user', () {
        expect(sent['reasons'], _reasons);
        expect(sent['user after the failures'], 'uid of a@x.dev <a@x.dev>');
        expect(
          sent['deletion that needs a recent sign-in'],
          [
            'recentSignInRequired',
            'uid of a@x.dev <a@x.dev>',
            ['delete()'],
            ['uid of a@x.dev <a@x.dev>'],
          ],
        );
      });

      test(
          'completes a password reset for an address that Firebase has no '
          'account of', () {
        expect(sent['reset for an address without an account'], [
          'completed',
          'uid of a@x.dev <a@x.dev>',
          ['sendPasswordResetEmail(nobody@x.dev)'],
          ['uid of a@x.dev <a@x.dev>'],
        ]);
        expect(sent['reset for a text that is no address'], 'invalidEmail');
      });

      test(
          'fails for an empty address or password before it asks Firebase, '
          'with a reason of its own for each call', () {
        // What Android and iOS answer differs, so the service decides.
        expect(sent['empty'], {
          'signIn without an address': 'invalidEmail',
          'signIn without a password': 'invalidCredentials',
          'signUp without an address': 'invalidEmail',
          'signUp without a password': 'weakPassword',
          'linkPassword without an address': 'invalidEmail',
          'linkPassword without a password': 'weakPassword',
          'sendPasswordReset without an address': 'invalidEmail',
        });
        expect(sent['calls of Firebase for what is empty'], isEmpty);
        expect(sent['user after what is empty'], 'guest 2 <null>, anonymous');
      });

      test(
          'signs out a user whose session has ended on the server, and '
          'fails the call for that user with recentSignInRequired', () {
        expect(sent['ended session'], {
          for (final code in _endedSession) ...{
            'delete: $code': [
              'recentSignInRequired',
              'nobody',
              ['delete()', 'signOut()'],
              ['nobody'],
            ],
            'linkWithCredential: $code': [
              'recentSignInRequired',
              'nobody',
              ['linkWithCredential(password of b@x.dev: secret)', 'signOut()'],
              ['nobody'],
            ],
          },
        });
      });

      test(
          'takes a way to sign in that is not enabled in the Firebase '
          'project for notConfigured, with a hint that has the command of '
          'the script that enables it and the link to the project', () {
        const link = 'https://console.firebase.google.com/project/'
            'stand-in-project/authentication/providers';
        const enable = 'run `$enableSignInCommand` in the directory of the '
            'app, or enable Email/Password, and Anonymous for an app that '
            'signs in anonymous users, in the Firebase console under '
            'Authentication > Sign-in method: $link';
        String notEnabled(String answered) =>
            'notConfigured: Sign-in is not enabled in the Firebase project '
            'stand-in-project (Firebase answered $answered). To fix it, '
            '$enable';
        expect(sent['not configured'], [
          notEnabled('operation-not-allowed'),
          notEnabled('admin-restricted-operation'),
          // As Android tells of a project in which Authentication was
          // never set up, and as iOS does: the hint names the code and
          // what the service found in the message, not the message, which
          // on iOS is the description of an error over many lines.
          notEnabled('unknown, CONFIGURATION_NOT_FOUND'),
          notEnabled('internal-error, CONFIGURATION_NOT_FOUND'),
        ]);
        // An internal error is what Firebase answers for such a project on
        // iOS and macOS, where the hint says that it may be another error.
        const hedged = 'notConfigured: Firebase reported an internal error '
            '(internal-error: Internal.), which is also what it answers on '
            'iOS and macOS when sign-in is not enabled in the Firebase '
            'project stand-in-project. If that is the cause, $enable';
        const unknown = 'unknown: internal-error: Internal.';
        expect(sent['internal error'], {
          'android': unknown,
          'fuchsia': unknown,
          'iOS': hedged,
          'linux': unknown,
          'macOS': hedged,
          'windows': unknown,
        });
      });

      test('takes any other error for unknown, with the error as the hint', () {
        expect(sent['unknown'], [
          'unknown: app-not-authorized: Not authorized.',
          'unknown: unknown: Something else.',
          // The whole message, on one line, and the code alone without one.
          'unknown: keychain-error: Error Domain=X { reason = 1; }',
          'unknown: quota-exceeded',
        ]);
        expect(sent['no error of Firebase'], 'unknown: Bad state: broken');
      });

      test(
          'follows the user of Firebase while it has a listener, and tells '
          'of a sign-out and of an error of that stream', () {
        expect(sent['a sign-out of Firebase'], [
          'nobody',
          ['nobody'],
        ]);
        expect(
          sent['an error of the stream of Firebase'],
          ['error: Bad state: stream'],
        );
        // No stream before the service has a listener, one while it has,
        // none once the listener is gone, and one again with the next.
        expect(sent['streams of Firebase'], [0, 1, 0, 1]);
      });

      test('has the user who is signed in when it is created again', () {
        expect(sent['a service created again'], 'uid of a@x.dev <a@x.dev>');
      });
    });

    group('the section of the module in the README of the app', () {
      test(
          'comes after the section of Firebase, and refers to the section '
          'of the auth role, which the app has too', () {
        final readme = app.files[AppEntryRole.readmeFile]!.text;
        int at(String heading) => readme.indexOf('\n## $heading\n');

        expect(
          readme,
          contains('\n## $readmeHeading\n\n$readmeSection'),
        );
        // The section of firebase_core, which tells how the app gets its
        // Firebase project, comes first.
        expect(at('Firebase'), inExclusiveRange(0, at(readmeHeading)));
        expect(at(AuthRole.readmeHeading), isNonNegative);
        expect(
          readmeSection,
          contains('(see the section ${AuthRole.readmeHeading})'),
        );
      });

      test(
          'tells which ways to sign in the modes of the app need, and what '
          'the app does until they are enabled', () {
        expect(
          readmeSection,
          allOf(
            contains(
              'Email/Password in every mode of the app, and Anonymous when '
              'the mode of the app is `anonymous`',
            ),
            contains('fail with the reason `notConfigured`'),
          ),
        );
        expect(_codeOf(readmeSection), contains(_implementation));
      });

      test(
          'gives the command of the script that enables them, also for '
          'another account, and tells what the script reads, what it needs '
          'and what it leaves as it is', () {
        expect(
          readmeSection,
          allOf(
            contains('```bash\n$enableSignInCommand\n```\n'),
            contains('```bash\n$enableSignInCommand --account <email>\n```\n'),
            contains(
              '[Firebase CLI](https://firebase.google.com/docs/cli) '
              '$firstFirebaseCliWithSignIn or later',
            ),
            contains('It never disables a method, and it changes no file of '
                'the app.'),
          ),
        );
        // What the script reads, each a file of the app or a name in it.
        final code = _codeOf(readmeSection);
        expect(
          code,
          containsAll([
            'firebase.json',
            'authMode',
            AuthRole.sessionFile,
            '--project <id>',
            'firebase deploy --only auth',
          ]),
        );
        expect(
          app.files[AuthRole.sessionFile]!.text,
          contains('const AuthMode authMode = '),
        );
        expect(
          app.files[enableSignInScript]!.text,
          allOf(
            contains("const _sessionFile = '${AuthRole.sessionFile}';"),
            contains(r"File('${app.path}/firebase.json')"),
            contains("'deploy',\n      '--only',\n      'auth',"),
          ),
        );
      });

      test(
          'tells of the Firebase console as the other way, and of no web '
          'app, which the Firebase CLI that the script needs does not add', () {
        const page = 'https://console.firebase.google.com/project/_/'
            'authentication/providers';
        const console = '[Authentication > Sign-in method]($page)';
        expect(
          readmeSection,
          allOf(
            contains('enable the methods in the Firebase console, under '
                '$console'),
            isNot(contains('web app')),
          ),
        );
        // As the service names the script and the page of the console in
        // its hint.
        expect(
          app.files[_implementation]!.text,
          allOf(
            contains('run `$enableSignInCommand` in the '),
            contains('enable Email/Password, and Anonymous'),
            contains('Authentication > Sign-in method'),
          ),
        );
      });
    });

    group('the note of the module for coding agents', () {
      test(
          'is in the section of the authentication of the guide, after what '
          'the role says', () {
        final notes = app.entriesOf(AppEntryRole.agentSections);
        final ofRole = [
          for (final (origin, _, note) in notes)
            if (origin == const RoleTemplateOrigin(authRole)) note.text,
        ].single;

        expect(
          [
            for (final (origin, heading, note) in notes)
              if (_auth.contains(origin)) (origin, heading, note.isOfRole),
          ],
          unorderedEquals([
            (
              const ModuleOrigin(FirebaseAuthModule.id),
              authRole.description,
              false,
            ),
            (const RoleTemplateOrigin(authRole), authRole.description, true),
          ]),
        );
        expect(agentNote, startsWith('With `firebase_auth`:\n'));
        expect(
          app.files[AppEntryRole.agentsFile]!.text,
          contains(
            '\n## ${authRole.description}\n'
            '\n'
            '$ofRole\n'
            '\n'
            '${agentNote.trim()}\n',
          ),
        );
      });

      test(
          'names the file of the module, the only one of the app that '
          'imports the package, what that file and the role declare, and '
          'the script that enables the ways to sign in', () {
        final code = _codeOf(agentNote);
        final service = DartFileIndexer.index(
          _implementation,
          app.files[_implementation]!.text,
        );
        final role = DartFileIndexer.index(
          AuthRole.serviceFile,
          app.files[AuthRole.serviceFile]!.text,
        );

        expect(
          code,
          containsAll([
            _implementation,
            'FirebaseAuthService',
            'AuthService',
            'FirebaseAuth.instance',
            'appSession',
            'AuthFailureReason',
            '_failureOf()',
            'unknown',
            'notConfigured',
            'developerHint',
            AppEntryRole.readmeFile,
            enableSignInScript,
          ]),
        );
        expect(app.files.keys, contains(enableSignInScript));
        expect(
          agentNote,
          contains(
            'It changes the Firebase project and needs a Firebase account: '
            'run it only when asked.',
          ),
        );
        expect(
          [
            for (final file in app.files.values)
              if (file.path.endsWith('.dart') &&
                  file.text.contains('package:firebase_auth/'))
                file.path,
          ],
          [_implementation],
        );
        expect(
          service.declaration('FirebaseAuthService')?.kind,
          DeclarationKind.classType,
        );
        expect(
          [
            for (final access in service.memberAccesses)
              '${access.target}.${access.name}',
          ],
          contains('FirebaseAuth.instance'),
        );
        expect(
          _methodsOf(_unitOf(app, _implementation), 'FirebaseAuthService').keys,
          contains('_failureOf'),
        );
        expect(
          role.declaration('AuthService')?.kind,
          DeclarationKind.classType,
        );
        expect(
          role.declaration('AuthFailureReason')?.kind,
          DeclarationKind.enumType,
        );
        expect(
          app.files[AuthRole.serviceFile]!.text,
          allOf(
            contains('  unknown,'),
            contains('  notConfigured,'),
            contains('final String? developerHint;'),
          ),
        );
        expect(
          app.files[AuthRole.sessionFile]!.text,
          contains('final appSession = AppSessionController('),
        );
        expect(agentNote, contains('the section $readmeHeading of'));
      });
    });

    test('has a README that leads to the page of the module', () {
      final readme = File('README.md').readAsStringSync();

      expect(
        readme,
        contains('(https://doc.saymyframe.com/modules/firebase-auth)'),
      );
    });
  });

  group('an app with the localization role', () {
    late RenderedApp app;

    setUpAll(() async {
      app = (await _resultOf(
        const [FirebaseAuthModule.id, GenL10nModule.id],
      ))
          .app!;
    });

    test(
        'asks Firebase for the message of a password reset in the language '
        'that the app is in, before it asks for the message', () {
      final statements = _passwordResetOf(app);

      // An empty address fails before the service asks Firebase for
      // anything.
      expect(statements, hasLength(3));
      expect(statements.first, '_checkGiven(email);');
      // The language that the user chose, or the one that the device
      // prefers among those of the app.
      expect(
        statements[1].replaceAll(RegExp(r'\s+'), ''),
        'await_auth.setLanguageCode((appLocale.value??'
        'basicLocaleListResolution('
        'WidgetsBinding.instance.platformDispatcher.locales,appLocales))'
        '.languageCode);',
      );
      expect(statements.last, startsWith('try {'));
      expect(statements.last, contains('_auth.sendPasswordResetEmail('));
    });

    test(
        'imports the languages of the app, from the file of the '
        'localization role, into the file of the service', () {
      expect(_importsOf(_unitOf(app, _implementation)), [
        "import 'dart:async';",
        "import 'package:contract_app/core/l10n/app_locale.dart';",
        "import 'package:firebase_auth/firebase_auth.dart';",
        "import 'package:flutter/foundation.dart';",
        _widgetsImport,
        "import 'auth_service.dart';",
      ]);
      // What the code of the module reads there.
      final locale = DartFileIndexer.index(
        LocalizationRole.appLocaleFile,
        app.files[LocalizationRole.appLocaleFile]!.text,
      );
      expect(locale.declaration('appLocale'), isNotNull);
      expect(locale.declaration('appLocales'), isNotNull);
    });
  });
}
