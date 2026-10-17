// The platform side of Google sign-in for the tests that continuous
// integration runs in the apps with the google_sign_in module: Google, in
// place of the sheet of Google sign-in of a device and of the servers
// behind it. The matrix sets it up before the tests of every module of
// such an app (MatrixAppTest.mocks), so that any of them may sign in with
// Google, as the test of the ways to sign in of the auth role does.
//
// google_sign_in has no mocks for tests, and its Android and iOS plugins
// talk to the platform in messages of their own. So this replaces the
// platform implementation of the package, GoogleSignInPlatform.instance of
// google_sign_in_platform_interface, with an implementation of its own,
// which the package asks on every platform the same way. A version of the
// platform interface that changes the class breaks these tests.
//
// It answers for one Google account, the same each time, as a user who
// picks that account on the sheet does: with its id, its email address
// and an ID token of it. The ID token is a test token, a JSON Web Token
// without a signature, whose payload has `iss`, the issuer of Google,
// `sub`, the account, `email`, its address, and `nonce` only when the
// package was started with a nonce, which Google writes into its token
// then, so that a provider of the auth role takes it in the tests of an
// app (see the test of the ways to sign in of the auth role,
// auth_methods). The app starts the package without one.
//
// It differs from Google in this: it shows no sheet, so a sign-in
// completes at once, it checks no client of the app, no key that signs it
// and no URL scheme, and it has no network that could fail. A test scripts
// such a failure with failNext(), as the plugin of a platform throws it.
import 'dart:convert';

import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

/// The issuer of the ID tokens of Google.
const googleTestIssuer = 'https://accounts.google.com';

/// The Google account of the tests: the subject of its tokens.
const googleTestUser = 'google-sign-in-tests-user';

/// The email address of that account.
const googleTestEmail = 'google-sign-in-tests@gmail.com';

/// Google in the tests of the app, which [mockGoogleSignIn] sets up.
final MockGoogleSignIn googleSignIn = MockGoogleSignIn._();

/// Google, as google_sign_in asks it through its platform implementation.
final class MockGoogleSignIn extends GoogleSignInPlatform {
  MockGoogleSignIn._();

  /// The parameters of each start of the package, in order.
  final List<InitParameters> starts = [];

  /// How many sign-ins reached Google.
  int signIns = 0;

  /// The errors that the next sign-ins fail with, in turn.
  final List<Object> _failures = [];

  /// The nonce that the package was started with, which Google writes into
  /// its tokens.
  String? _nonce;

  /// Fails the next sign-in with [error], as the plugin of a platform
  /// throws it: a [GoogleSignInException], such as one with the code
  /// [GoogleSignInExceptionCode.canceled] for a closed sheet, or another
  /// error, such as the PlatformException with which the plugin on iOS
  /// refuses an app without its client.
  void failNext(Object error) => _failures.add(error);

  @override
  Future<void> init(InitParameters params) async {
    starts.add(params);
    _nonce = params.nonce;
  }

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    signIns++;
    if (_failures.isNotEmpty) throw _failures.removeAt(0);
    return AuthenticationResults(
      user: const GoogleSignInUserData(
        email: googleTestEmail,
        id: googleTestUser,
        displayName: 'Google Tester',
      ),
      authenticationTokens: AuthenticationTokenData(
        idToken: _testToken(_nonce),
      ),
    );
  }

  /// Nobody is signed in to Google without a sheet in the tests.
  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async =>
      null;

  @override
  bool authorizationRequiresUserInteraction() => false;

  /// The tests ask for no scopes.
  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async =>
      null;

  /// The tests ask for no scopes.
  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async =>
      null;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

/// A test token of the account of the tests, with [nonce] if it has one: a
/// JSON Web Token without a signature.
String _testToken(String? nonce) {
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final claims = <String, Object?>{
    'iss': googleTestIssuer,
    'sub': googleTestUser,
    'email': googleTestEmail,
  };
  if (nonce != null) claims['nonce'] = nonce;
  return '${part({'alg': 'none', 'typ': 'JWT'})}.${part(claims)}.';
}

/// Answers google_sign_in as Google, with [googleSignIn] as its platform
/// implementation.
void mockGoogleSignIn() => GoogleSignInPlatform.instance = googleSignIn;
