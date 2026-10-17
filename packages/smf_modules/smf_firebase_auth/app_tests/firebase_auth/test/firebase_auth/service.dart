// What the tests of the firebase_auth module share: the start of Firebase,
// which the service of the module works on, the credentials of Google and
// Apple that the tests sign in with, and how a test compares a user and a
// failure of that service.
//
// The tests use the service of the module, which
// createFirebaseAuthService() creates, on the real Firebase packages, whose
// platform side is the backend in memory of firebase_auth_mocks.dart. They
// initialize Firebase as the start-up of the app does, and run none of the
// rest of the start-up: what the session of the app does with a service,
// and what every provider of the auth role keeps to, is for the test of
// the role. The options of Firebase come with the tests of firebase_core,
// which every app with the module has.
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/auth_service.dart';
import 'package:{{app_name}}/firebase_options.dart';

/// The password of the accounts of the tests.
const String password = 'Firebase-auth-tests-2468';

/// An email address that only the tests of the module use: the one of
/// [name], which each test gives another one.
String addressOf(String name) => '$name@firebase-auth-tests.example.com';

/// The issuer of the ID tokens of Google.
const String google = 'https://accounts.google.com';

/// The issuer of the ID tokens of Apple.
const String apple = 'https://appleid.apple.com';

/// How many credentials the tests built, which gives each a nonce of its
/// own.
int _credentials = 0;

/// A new credential of [issuer], Google or Apple, for the identity of the
/// tests [name], with the email address [email] if it has one, and with an
/// authorization code for Apple: a credential such as the way to sign in
/// of the identity provider gets, whose ID token is a test token, a JSON
/// Web Token without a signature (see firebase_auth_mocks.dart). Its token
/// has a nonce of its own, which is its raw nonce, so the backend takes it
/// once. A credential of Apple has the name of the user too.
IdTokenCredential credentialOf(
  String issuer,
  String name, {
  String? email,
}) {
  final nonce = 'firebase-auth-tests-nonce-${++_credentials}';
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final claims = <String, Object?>{
    'iss': issuer,
    'sub': 'firebase-auth-tests-$name',
  };
  if (email != null) claims['email'] = email;
  claims['nonce'] = nonce;
  return IdTokenCredential(
    issuer: issuer,
    idToken: '${part({'alg': 'none', 'typ': 'JWT'})}.${part(claims)}.',
    rawNonce: nonce,
    authorizationCode:
        issuer == apple ? 'firebase-auth-tests-code-$_credentials' : null,
    givenName: issuer == apple ? 'Ada' : null,
    familyName: issuer == apple ? 'Lovelace' : null,
  );
}

/// Initializes Firebase, as the start-up of the app does before it creates
/// the service.
Future<void> initializeFirebase() => Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

/// What [call] failed with, or `null` if it completed.
Future<Object?> errorOf(Future<void> Function() call) async {
  try {
    await call();
    return null;
  } on Object catch (error) {
    return error;
  }
}

/// A failure of a call of the service as a test compares it: its reason,
/// with its hint for the developer if it has one; what else a call failed
/// with, as it is; and `completed` for a call that did not fail.
String outcomeOf(Object? error) => switch (error) {
      null => 'completed',
      AuthFailure(:final reason, developerHint: null) => reason.name,
      AuthFailure(:final reason, :final developerHint?) =>
        '${reason.name} ($developerHint)',
      _ => 'threw $error',
    };

/// A user as a test compares it: nobody, an anonymous user, or the user of
/// an account, with its email address if it has one, each with its id.
/// [issuersOf] tells the identity providers of the user.
String userOf(AuthUser? user) => switch (user) {
      null => 'nobody',
      AuthUser(isAnonymous: true, :final uid, email: null) =>
        'the anonymous user $uid',
      AuthUser(isAnonymous: false, :final uid, :final email?) =>
        'the account $uid of $email',
      AuthUser(isAnonymous: false, :final uid, email: null) =>
        'the account $uid',
      AuthUser(:final uid, :final isAnonymous, :final email) =>
        'the user $uid, anonymous $isAnonymous, with the address $email',
    };

/// The identity providers of [user] as a test compares them: their
/// issuers, sorted.
List<String> issuersOf(AuthUser? user) => [...?user?.issuers]..sort();
