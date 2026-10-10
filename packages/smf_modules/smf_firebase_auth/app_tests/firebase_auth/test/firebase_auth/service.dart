// What the tests of the firebase_auth module share: the start of Firebase,
// which the service of the module works on, and how a test compares a user
// and a failure of that service.
//
// The tests use the service of the module, which
// createFirebaseAuthService() creates, on the real Firebase packages, whose
// platform side is the backend in memory of firebase_auth_mocks.dart. They
// initialize Firebase as the start-up of the app does, and run none of the
// rest of the start-up: what the session of the app does with a service,
// and what every provider of the auth role keeps to, is for the test of
// the role. The options of Firebase come with the tests of firebase_core,
// which every app with the module has.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/auth_service.dart';
import 'package:{{app_name}}/firebase_options.dart';

/// The password of the accounts of the tests.
const String password = 'Firebase-auth-tests-2468';

/// An email address that only the tests of the module use: the one of
/// [name], which each test gives another one.
String addressOf(String name) => '$name@firebase-auth-tests.example.com';

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
/// the account of an email address, each with its id.
String userOf(AuthUser? user) => switch (user) {
      null => 'nobody',
      AuthUser(isAnonymous: true, :final uid, email: null) =>
        'the anonymous user $uid',
      AuthUser(isAnonymous: false, :final uid, :final email?) =>
        'the account $uid of $email',
      AuthUser(:final uid, :final isAnonymous, :final email) =>
        'the user $uid, anonymous $isAnonymous, with the address $email',
    };
