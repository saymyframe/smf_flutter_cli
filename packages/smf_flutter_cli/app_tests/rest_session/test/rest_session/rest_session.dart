// What the tests of the requests of the users of the session share, in the apps
// with the REST role and the auth role, whichever modules provide them: a
// service of sign-in that counts the refreshes of the token and scripts how the
// next one ends, over the service of the provider, and what a call ended with.
//
// It knows only the roles, and uses the helpers of the test of the auth role,
// which every such app has.
import 'package:{{app_name}}/core/auth/auth_service.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

/// The service of the provider, whose forced reads of the token [TokenCounter]
/// counts, and of which [onRefresh] says how the next one ends.
final class TokenCounter implements AuthService {
  /// Creates the counter over [_service].
  TokenCounter(this._service);

  final AuthService _service;

  /// How many forced reads of the token reached this service.
  int refreshes = 0;

  /// What the next forced read does in place of the read of the service.
  Future<String?> Function()? onRefresh;

  @override
  Future<String?> userToken({bool forceRefresh = false}) {
    if (!forceRefresh) return _service.userToken();
    refreshes++;
    final scripted = onRefresh;
    onRefresh = null;
    return scripted?.call() ?? _service.userToken(forceRefresh: true);
  }

  @override
  AuthUser? get currentUser => _service.currentUser;

  @override
  Stream<AuthUser?> get userChanges => _service.userChanges;

  @override
  Future<void> signIn({required String email, required String password}) =>
      _service.signIn(email: email, password: password);

  @override
  Future<void> signUp({required String email, required String password}) =>
      _service.signUp(email: email, password: password);

  @override
  Future<void> linkPassword({
    required String email,
    required String password,
  }) =>
      _service.linkPassword(email: email, password: password);

  @override
  Future<void> signInWith(SignInCredential credential) =>
      _service.signInWith(credential);

  @override
  Future<void> linkWith(SignInCredential credential) =>
      _service.linkWith(credential);

  @override
  Future<void> signInAnonymously() => _service.signInAnonymously();

  @override
  Future<void> sendPasswordReset(String email) =>
      _service.sendPasswordReset(email);

  @override
  Future<void> signOut() => _service.signOut();

  @override
  Future<void> deleteAccount({SignInCredential? fresh}) =>
      _service.deleteAccount(fresh: fresh);
}

/// What [call] ended with: a [RestResponse], or what it threw.
Future<Object> outcomeOf(Future<RestResponse> call) async {
  try {
    return await call;
  } on Object catch (error) {
    return error;
  }
}
