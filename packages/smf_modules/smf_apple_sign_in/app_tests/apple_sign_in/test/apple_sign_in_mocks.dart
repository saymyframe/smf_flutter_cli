// The platform side of Sign in with Apple for the tests that continuous
// integration runs in the apps with the apple_sign_in module: Apple, in
// place of the sheet of Sign in with Apple of a device and of the servers
// behind it. The matrix sets it up before the tests of every module of
// such an app (MatrixAppTest.mocks), so that any of them may sign in with
// Apple, as the test of the ways to sign in of the auth role does.
//
// sign_in_with_apple has no mocks for tests, so this answers its method
// channel, com.aboutyou.dart_packages.sign_in_with_apple, as its plugin
// does on iOS: performAuthorizationRequest with the map of a credential of
// an Apple ID, or with the error of an authorization, whose code it reads
// as the code of the error of Apple, such as authorization-error/canceled.
// A version of the package that changes the messages breaks these tests.
//
// It answers for one user of Apple, the same each time, as a user who
// signs in on a device with an Apple Account does: with an ID token of
// that user and a new authorization code each time, and with the name and
// the email address of the user only the first time, as Apple gives them
// only at the first sign-in of a user in an app. The ID token is a test
// token, a JSON Web Token without a signature, whose payload has `iss`,
// the issuer of Apple, `sub`, the user, `email`, the address of the
// private relay of Apple, and `nonce`, the nonce of the request, as Apple
// writes it into its token: the SHA-256 hash of the raw nonce of the
// credential, which a provider of the auth role takes in the tests of an
// app (see the test of the ways to sign in of the auth role, auth_methods).
//
// It differs from Apple in this: it shows no sheet, so a request completes
// at once, it checks no capability of the app, and it gives the name again
// only in a test file of its own, where the first request is again the
// first one.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The channel of the plugin of Sign in with Apple.
const _channel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');

/// The issuer of the ID tokens of Apple.
const appleTestIssuer = 'https://appleid.apple.com';

/// The user of Apple of the tests: the subject of its tokens.
const appleTestUser = 'apple-sign-in-tests-user';

/// The address of the private relay of Apple of that user.
const appleTestEmail = 'apple-sign-in-tests@privaterelay.appleid.com';

/// The given name of that user.
const appleTestGivenName = 'Apple';

/// The family name of that user.
const appleTestFamilyName = 'Tester';

/// Apple in the tests of the app, which [mockSignInWithApple] sets up.
final MockSignInWithApple signInWithApple = MockSignInWithApple._();

/// Apple, as the plugin of Sign in with Apple asks it on iOS.
final class MockSignInWithApple {
  MockSignInWithApple._();

  /// The requests that reached Apple, each as the plugin sends it: its
  /// `type`, its `scopes` and its `nonce`.
  final List<Map<Object?, Object?>> requests = [];

  /// The authorization codes that Apple gave, in order.
  final List<String> codes = [];

  /// The codes of the errors that the next requests fail with, in turn.
  final List<String> _failures = [];

  /// Whether Apple gave the name of the user already.
  bool _gaveName = false;

  /// Fails the next request with the error [code] of Apple, as the plugin
  /// sends it, such as `authorization-error/canceled` for a closed sheet.
  void failNext(String code) => _failures.add(code);

  /// What Apple answers [request] with: the map of a credential of the user
  /// of the tests, with the nonce of the request in its ID token.
  Map<String, Object?> _answer(Map<Object?, Object?> request) {
    requests.add(request);
    if (_failures.isNotEmpty) {
      throw PlatformException(
        code: _failures.removeAt(0),
        message: 'The operation couldn’t be completed.',
      );
    }
    final first = !_gaveName;
    _gaveName = true;
    final code = 'apple-sign-in-tests-code-${codes.length + 1}';
    codes.add(code);
    return {
      'type': 'appleid',
      'userIdentifier': appleTestUser,
      'givenName': first ? appleTestGivenName : null,
      'familyName': first ? appleTestFamilyName : null,
      'email': first ? appleTestEmail : null,
      'identityToken': _testToken(request['nonce'] as String?),
      'authorizationCode': code,
      'state': request['state'],
    };
  }
}

/// A test token of the user of the tests with [nonce]: a JSON Web Token
/// without a signature.
String _testToken(String? nonce) {
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final claims = <String, Object?>{
    'iss': appleTestIssuer,
    'sub': appleTestUser,
    'email': appleTestEmail,
  };
  if (nonce != null) claims['nonce'] = nonce;
  return '${part({'alg': 'none', 'typ': 'JWT'})}.${part(claims)}.';
}

/// Answers the method channel of Sign in with Apple as Apple on iOS, with
/// [signInWithApple].
///
/// The binding of the tests must be initialized first.
void mockSignInWithApple() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    switch (call.method) {
      case 'isAvailable':
        return true;
      case 'performAuthorizationRequest':
        final requests = call.arguments as List<Object?>;
        return signInWithApple
            ._answer(requests.single! as Map<Object?, Object?>);
    }
    throw MissingPluginException('No answer for ${call.method}.');
  });
}
