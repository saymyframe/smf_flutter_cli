// What the tests of the ways to sign in of the auth role share, in the apps
// whose modules give the role a way to sign in with an identity provider,
// whichever modules provide the role and the ways to sign in: the issuers
// of the ways to sign in of the app, the test tokens, and what tells who
// uses the app with which identity providers.
//
// The tests read the ways to sign in from appSignInMethods of the app,
// which the template of the role generates, and take the start-up of the
// app and the helpers of the test of the role, auth_role, which every app
// with the role has.
//
// Test tokens. In the tests of an app, the token of a credential of an
// identity provider is a test token: a JSON Web Token without a signature,
// whose header has `alg` none and whose payload has `iss`, the issuer of
// the way to sign in, `sub`, the identity at the identity provider, maybe
// `email`, the email address of that identity, and `nonce`, a value of its
// own. The `nonce` is the rawNonce of the credential itself, not its hash.
// A credential of the issuer of a way to sign in that revokesOnDeletion
// also has an authorizationCode of its own, as an identity provider that
// revokes gives one with each token.
//
// A token with a nonce may be taken once, as an identity provider that
// checks a nonce takes it: a provider of the role refuses a token whose
// nonce it took already with invalidCredentials, and, where its backend
// checks the nonce, one whose rawNonce is not the nonce of its token. The
// one exception is the credential object that linkWith refused just
// before: signInWith takes the identical object, with what the provider
// kept for it, as the role says. So every call here gets a credential of
// its own, but for that one.
//
// The mocks of the module of a way to sign in issue such tokens, of one
// identity of their own and the same each time, each with a new nonce, so
// that the function of the way to sign in returns a credential under them.
// A provider of the role takes such a token in the tests of an app, its
// mocks or a fixture, as the token of its identity, whatever its issuer
// among those of the app. So the test of the service builds tokens of
// identities of its own for each issuer of the app, and the test of the
// session goes through the function of each way to sign in.
import 'dart:convert';
import 'dart:math';

import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/auth/auth_service.dart';
import 'package:{{app_name}}/core/auth/sign_in_methods.dart';

/// The issuers of the ways to sign in of the app, each once, in the order
/// of appSignInMethods.
List<String> get issuersOfApp => [
      ...{for (final method in appSignInMethods) method.issuer},
    ];

/// A source of the nonces and the authorization codes of the tests.
final Random _random = Random.secure();

/// A value that no other token of the tests has.
String _unique() => base64Url
    .encode([for (var byte = 0; byte < 16; byte++) _random.nextInt(256)]);

/// A test token of [issuer] for the identity [subject], with its email
/// address [email] if it has one, and the nonce [nonce]: a JSON Web Token
/// without a signature.
String testToken({
  required String issuer,
  required String subject,
  required String nonce,
  String? email,
}) {
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final claims = <String, Object?>{'iss': issuer, 'sub': subject};
  if (email != null) claims['email'] = email;
  claims['nonce'] = nonce;
  return '${part({'alg': 'none', 'typ': 'JWT'})}.${part(claims)}.';
}

/// A new credential of [issuer] for the identity of the tests [name], with
/// the email address [email] if it has one, as a way to sign in of [issuer]
/// gets it from its identity provider (see [testToken]): its token has a
/// nonce of its own, which is its rawNonce, and it has an authorization
/// code of its own when a way to sign in of [issuer] revokesOnDeletion.
IdTokenCredential credentialOf(
  String issuer,
  String name, {
  String? email,
}) {
  final nonce = _unique();
  final revokes = appSignInMethods.any(
    (method) => method.issuer == issuer && method.revokesOnDeletion,
  );
  return IdTokenCredential(
    issuer: issuer,
    idToken: testToken(
      issuer: issuer,
      subject: 'auth-methods-tests-$name',
      nonce: nonce,
      email: email,
    ),
    rawNonce: nonce,
    authorizationCode: revokes ? 'auth-methods-tests-${_unique()}' : null,
  );
}

/// How a call ended, as a test compares it: `completed`, the name of the
/// reason of the [AuthFailure] that it failed with, or the error.
String outcomeOf(Object? error) => switch (error) {
      null => 'completed',
      AuthFailure(:final reason) => reason.name,
      _ => '$error',
    };

/// The identity providers of [issuers], sorted, as a test compares them.
String _providersOf(Set<String> issuers) => ([...issuers]..sort()).join(', ');

/// A user of the service as a test compares it: nobody, an anonymous user,
/// or the user of an account with the identity providers that the user
/// signs in with.
String userWithIssuers(AuthUser? user) => switch (user) {
      null => 'nobody',
      AuthUser(isAnonymous: true) => 'an anonymous user',
      AuthUser(:final issuers) => 'an account with ${_providersOf(issuers)}',
    };

/// What [userWithIssuers] says of the user of an account that signs in
/// with [issuer] alone.
String accountWith(String issuer) => 'an account with $issuer';

/// Who the session of the app says uses it, with the identity providers of
/// an account, as [userWithIssuers] says it of a user of the service.
String sessionWithIssuers() => switch (appSession.value) {
      SignedOutSession() => 'nobody',
      AnonymousSession() => 'an anonymous user',
      AccountSession(:final issuers) =>
        'an account with ${_providersOf(issuers)}',
    };
