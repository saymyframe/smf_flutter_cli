import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';

/// The brick [name] with the text files [files], each by its path in the
/// app.
MasonBundle _bundle(String name, Map<String, String> files) => MasonBundle(
      name: name,
      description: name,
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
    );

/// A provider of the auth role for the tests, which keeps the accounts in
/// memory, in plain Dart: `memoryAccounts` stands for the server of a
/// provider, and `memoryUser` for the user whom the device remembers, whom
/// each start of the app reads anew.
///
/// So the apps of the tests of the module have sign-in without the package
/// of a provider of the role, and the module is tested with a provider that
/// it does not know.
final class MemoryAuthModule extends SmfModule {
  /// Creates the module.
  const MemoryAuthModule();

  /// The id of the module.
  static const id = ModuleId('memory_auth');

  /// The path below `lib/` of the file of the service.
  static const file = 'core/auth/memory_auth_service.dart';

  static const _file = ImportRef.app(file);

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Sign-in with accounts in memory (test)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(authRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(_bundle('memory_auth', {'lib/$file': _code})),
        authRole.data(
          const AuthImplementation(
            type: TypeRef('MemoryAuthService', import: _file),
            create: FactoryRef('createMemoryAuthService', import: _file),
          ),
        ),
      ];

  static const _code = r'''
import 'dart:async';

import 'auth_service.dart';

/// The accounts by their email addresses, each with the id of its user and
/// its password: what the server of a provider keeps.
final Map<String, ({String uid, String password})> memoryAccounts = {};

/// The user whom the device remembers, or `null`: each start of the app
/// reads it anew, and each call changes it.
AuthUser? memoryUser;

int _users = 0;

/// Opens the sign-in with the user whom the device remembers.
AuthService createMemoryAuthService() => MemoryAuthService();

/// Sign-in with the accounts of [memoryAccounts]. It takes any text for an
/// email address and any password, and sends no message.
final class MemoryAuthService implements AuthService {
  final StreamController<AuthUser?> _changes = StreamController.broadcast();

  AuthUser? _user = memoryUser;

  void _set(AuthUser? user) {
    _user = user;
    memoryUser = user;
    _changes.add(user);
  }

  /// A call takes a moment, as one that asks a server does.
  Future<void> _answer() => Future<void>.delayed(Duration.zero);

  AuthUser _signedIn() =>
      _user ??
      (throw const AuthFailure(AuthFailureReason.recentSignInRequired));

  void _checkFree(String email) {
    if (memoryAccounts.containsKey(email)) {
      throw const AuthFailure(AuthFailureReason.emailInUse);
    }
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _answer();
    final account = memoryAccounts[email];
    if (account == null || account.password != password) {
      throw const AuthFailure(AuthFailureReason.invalidCredentials);
    }
    _set(AuthUser(uid: account.uid, isAnonymous: false, email: email));
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await _answer();
    _checkFree(email);
    final uid = 'memory-user-${++_users}';
    memoryAccounts[email] = (uid: uid, password: password);
    _set(AuthUser(uid: uid, isAnonymous: false, email: email));
  }

  @override
  Future<void> linkPassword({
    required String email,
    required String password,
  }) async {
    await _answer();
    final user = _signedIn();
    _checkFree(email);
    memoryAccounts[email] = (uid: user.uid, password: password);
    _set(AuthUser(uid: user.uid, isAnonymous: false, email: email));
  }

  @override
  Future<void> signInAnonymously() async {
    await _answer();
    _set(AuthUser(uid: 'memory-user-${++_users}', isAnonymous: true));
  }

  @override
  Future<void> sendPasswordReset(String email) => _answer();

  @override
  Future<void> signOut() async {
    await _answer();
    _set(null);
  }

  @override
  Future<void> deleteAccount({SignInCredential? fresh}) async {
    await _answer();
    final user = _signedIn();
    memoryAccounts.removeWhere((email, account) => account.uid == user.uid);
    _set(null);
  }

  @override
  Future<String?> userToken({bool forceRefresh = false}) async {
    await _answer();
    return _user == null ? null : 'token-of-${_user!.uid}';
  }

  /// It takes no credential of an identity provider.
  @override
  Future<void> signInWith(SignInCredential credential) async =>
      throw const AuthFailure(AuthFailureReason.notConfigured);

  @override
  Future<void> linkWith(SignInCredential credential) async =>
      throw const AuthFailure(AuthFailureReason.notConfigured);
}
''';
}

/// A way to sign in for the tests, which a script of the state of the
/// screens scripts: the function of the way to sign in answers what
/// `scriptedAnswer` returns, as the sheet of an identity provider does, and
/// counts its calls in `scriptedAsked`. It works on Android, the platform
/// of the stand-in of Flutter, and on iOS, and has its label in English
/// alone, since the module does not use the localization role.
///
/// So the state of the screens is tested with a way to sign in that the
/// module does not know.
final class ScriptedMethodModule extends SmfModule {
  /// Creates the module.
  const ScriptedMethodModule();

  /// The id of the module.
  static const id = ModuleId('scripted_method');

  /// The issuer of the tokens of the identity provider of the tests.
  static const issuer = 'https://accounts.script.example.com';

  /// The path below `lib/` of the file of the way to sign in.
  static const file = 'core/scripted_method/scripted_method.dart';

  static const _file = ImportRef.app(file);

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A way to sign in that a script scripts (test)',
        kind: ModuleKinds.infrastructure,
        requires: {authRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(_bundle('scripted_method', {'lib/$file': _code})),
        authRole.data(
          const SignInMethod(
            label: LocalizedText('label', en: 'Continue with the script'),
            icon: TypeRef('ScriptedSignInIcon', import: _file),
            platforms: {AppPlatform.android, AppPlatform.ios},
            credential: FunctionRef('scriptedCredential', import: _file),
            issuer: issuer,
            appStore: AppStoreLogin.privacyFocused,
          ),
        ),
      ];

  static const _code = '''
import 'package:flutter/widgets.dart';

import '../auth/app_session.dart';

/// What the next call of [scriptedCredential] answers, which a script sets:
/// no credential at first, as when the user closes the sheet.
Future<SignInCredential?> Function() scriptedAnswer = () async => null;

/// How many times the app asked the way to sign in for a credential.
int scriptedAsked = 0;

/// Asks the identity provider of the tests for a credential.
Future<SignInCredential?> scriptedCredential() {
  scriptedAsked++;
  return scriptedAnswer();
}

/// The icon of the way to sign in.
class ScriptedSignInIcon extends StatelessWidget {
  /// Creates the icon.
  const ScriptedSignInIcon({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';
}

/// A feature for the tests with one route, `/<name>`, which can start the
/// app, and whose screen is `<Name>Screen`.
final class StartFeature extends SmfModule {
  /// Creates the feature [name].
  const StartFeature(this.name);

  /// The id of the feature and the name of its route.
  final String name;

  /// The id of the module.
  ModuleId get id => ModuleId(name);

  String get _screen => '${name[0].toUpperCase()}${name.substring(1)}Screen';

  String get _screenFile => 'features/$name/${name}_screen.dart';

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'The feature $name (test)',
        kind: ModuleKinds.feature,
      );

  @override
  List<Contribution> contribute(ModuleContext context) {
    final tag = RouterRole.screenAnnotations((feature: id, screen: _screen));
    return [
      BrickContribution(
        _bundle(name, {
          'lib/$_screenFile': [
            "import 'package:flutter/widgets.dart';",
            '',
            '/// A screen of the tests.',
            '{{{${tag.tag}}}}',
            'class $_screen extends StatelessWidget {',
            '  /// Creates the screen.',
            '  const $_screen({super.key});',
            '',
            '  @override',
            '  Widget build(BuildContext context) => const SizedBox();',
            '}',
            '',
          ].join('\n'),
        }),
      ),
      routerRole.data(
        RoutesData([
          Route(
            '/',
            name: name,
            screen: ScreenRef(_screen, import: ImportRef.app(_screenFile)),
            startCandidate: true,
          ),
        ]),
      ),
    ];
  }
}
