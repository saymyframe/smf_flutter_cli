import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';

/// A provider of the auth role for the tests, in plain Dart, which signs
/// nobody in: so the apps of the tests of the module have the files of the
/// role without the package of a provider, and the module is tested with a
/// provider that it does not know.
///
/// Its service fails every call that signs in, which the tests of the
/// module never make: the way to sign in of the module only returns a
/// credential.
final class TestAuthModule extends SmfModule {
  /// Creates the module.
  const TestAuthModule();

  /// The id of the module.
  static const id = ModuleId('test_auth');

  static const _path = 'core/auth/test_auth_service.dart';

  static const _file = ImportRef.app(_path);

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Sign-in that signs nobody in (test)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(authRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          MasonBundle(
            name: 'test_auth',
            description: 'test_auth',
            version: '0.1.0',
            files: [
              MasonBundledFile(
                'lib/$_path',
                base64.encode(utf8.encode(_code)),
                'text',
              ),
            ],
          ),
        ),
        authRole.data(
          const AuthImplementation(
            type: TypeRef('TestAuthService', import: _file),
            create: FactoryRef('createTestAuthService', import: _file),
          ),
        ),
      ];

  static const _code = '''
import 'auth_service.dart';

/// Opens the sign-in of the tests.
AuthService createTestAuthService() => TestAuthService();

/// Sign-in that signs nobody in: every call fails with notConfigured.
final class TestAuthService implements AuthService {
  Never _fail() => throw const AuthFailure(AuthFailureReason.notConfigured);

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> get userChanges => const Stream.empty();

  @override
  Future<void> signIn({required String email, required String password}) async =>
      _fail();

  @override
  Future<void> signUp({required String email, required String password}) async =>
      _fail();

  @override
  Future<void> linkPassword({
    required String email,
    required String password,
  }) async =>
      _fail();

  @override
  Future<void> signInAnonymously() async => _fail();

  @override
  Future<void> sendPasswordReset(String email) async => _fail();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount({SignInCredential? fresh}) async => _fail();

  @override
  Future<void> signInWith(SignInCredential credential) async => _fail();

  @override
  Future<void> linkWith(SignInCredential credential) async => _fail();
}
''';
}
