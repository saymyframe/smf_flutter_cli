import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Returns the sign-in service of the app on Firebase Authentication, with
/// the user who is signed in on this device.
///
/// Firebase is initialized first, as `bootstrap()` does. Firebase keeps the
/// user on the device and hands that user over when it is initialized, so
/// the service has the user at once, without a request to the server.
AuthService createFirebaseAuthService() =>
    FirebaseAuthService(FirebaseAuth.instance);

/// The codes with which Firebase answers a call for the user who is signed
/// in when the session of that user has ended on the server, as when the
/// account was deleted, or its password changed, on another device.
const _endedSession = {
  'user-token-expired',
  'invalid-user-token',
  'user-not-found',
  'no-current-user',
};

/// Sign-in with [Firebase Authentication](https://firebase.google.com/docs/auth),
/// with an email address and a password, and as an anonymous user.
///
/// The code of the app does not use it: it signs in through `appSession` of
/// `app_session.dart`.
///
/// The ways to sign in are enabled in the Firebase project, not here:
/// Email/Password, and Anonymous for an app that signs in anonymous users.
/// Until they are, a call fails with [AuthFailureReason.notConfigured], and
/// its [AuthFailure.developerHint] tells where to enable them.
final class FirebaseAuthService implements AuthService {
  /// Creates the service on [_auth].
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  /// Tells that the user may have changed: after each call here, and when
  /// Firebase tells of a change that no call here made, such as the end of
  /// the session of the user on the server. It follows Firebase only while
  /// it has a listener.
  late final StreamController<void> _changes = StreamController.broadcast(
    onListen: () => _fromFirebase = _auth.userChanges().listen(
          (_) => _changes.add(null),
          onError: _changes.addError,
        ),
    onCancel: () => _fromFirebase?.cancel(),
  );

  StreamSubscription<User?>? _fromFirebase;

  @override
  AuthUser? get currentUser => switch (_auth.currentUser) {
        null => null,
        final user => AuthUser(
            uid: user.uid,
            isAnonymous: user.isAnonymous,
            email: user.email,
          ),
      };

  /// Each event has the user of the moment in which a listener gets it, so
  /// a listener never hears of a user who is not [currentUser] any more.
  @override
  Stream<AuthUser?> get userChanges => _changes.stream.map((_) => currentUser);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _run(
        () => _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
      );

  @override
  Future<void> signUp({required String email, required String password}) =>
      _run(
        () => _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      );

  @override
  Future<void> linkPassword({
    required String email,
    required String password,
  }) =>
      _runForUser(
        (user) => user.linkWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        ),
      );

  /// While an anonymous user is signed in, Firebase answers with that user
  /// and creates no other.
  @override
  Future<void> signInAnonymously() => _run(_auth.signInAnonymously);

  /// Firebase sends the message from the template of the project
  /// (Authentication > Templates in the Firebase console).
  @override
  Future<void> sendPasswordReset(String email) => _run(() async {
        {{{email_language}}}
        try {
          await _auth.sendPasswordResetEmail(email: email);
        } on FirebaseAuthException catch (error) {
          // A project without the protection against the enumeration of
          // email addresses tells that an address has no account.
          if (error.code != 'user-not-found') rethrow;
        }
      });

  @override
  Future<void> signOut() => _run(_auth.signOut);

  @override
  Future<void> deleteAccount() => _runForUser((user) async {
        await user.delete();
        // Firebase signs a deleted user out, but the plugin keeps that user
        // as the current one until the platform tells it of the sign-out,
        // which may come after this call is over.
        await _auth.signOut();
      });

  /// Runs [call] for the user who is signed in.
  ///
  /// It fails with [AuthFailureReason.recentSignInRequired] when nobody is
  /// signed in, and when Firebase answers that the session of the user has
  /// ended: the user is then signed out on this device first.
  Future<void> _runForUser(Future<void> Function(User user) call) =>
      _run(() async {
        final user = _auth.currentUser;
        if (user == null) {
          throw const AuthFailure(AuthFailureReason.recentSignInRequired);
        }
        try {
          await call(user);
        } on FirebaseAuthException catch (error) {
          if (!_endedSession.contains(error.code)) rethrow;
          await _auth.signOut();
          throw const AuthFailure(AuthFailureReason.recentSignInRequired);
        }
      });

  /// Runs [call], which then fails only with an [AuthFailure], and tells
  /// of the user that it leaves, also when it failed.
  Future<void> _run(Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_failureOf(error), stackTrace);
    } finally {
      _changes.add(null);
    }
  }

  /// The failure of a call that failed with [error]: the reason for the
  /// code of Firebase. A code that has no reason yet gets one here.
  AuthFailure _failureOf(Object error) {
    if (error is AuthFailure) return error;
    if (error is! FirebaseAuthException) {
      return AuthFailure(AuthFailureReason.unknown, developerHint: '$error');
    }
    final reason = switch (error.code) {
      // Firebase answers a wrong password and an address without an account
      // alike, unless the project is without the protection against the
      // enumeration of email addresses.
      'invalid-credential' ||
      'invalid-login-credentials' ||
      'wrong-password' ||
      'user-not-found' =>
        AuthFailureReason.invalidCredentials,
      'email-already-in-use' ||
      'credential-already-in-use' =>
        AuthFailureReason.emailInUse,
      'weak-password' ||
      'password-does-not-meet-requirements' =>
        AuthFailureReason.weakPassword,
      'invalid-email' || 'missing-email' => AuthFailureReason.invalidEmail,
      'user-disabled' => AuthFailureReason.userDisabled,
      'too-many-requests' => AuthFailureReason.tooManyAttempts,
      'network-request-failed' => AuthFailureReason.network,
      'requires-recent-login' => AuthFailureReason.recentSignInRequired,
      _ => null,
    };
    if (reason != null) return AuthFailure(reason);
    final answer = '${error.code}: ${error.message}';
    final project = _auth.app.options.projectId;
    final enable = 'enable Email/Password, and Anonymous for an app that '
        'signs in anonymous users, under Authentication > Sign-in method: '
        'https://console.firebase.google.com/project/$project/'
        'authentication/providers';
    // A way to sign in that is not enabled, and, on Android, a project in
    // which Authentication was never set up.
    if (error.code == 'operation-not-allowed' ||
        error.code == 'admin-restricted-operation' ||
        answer.contains('CONFIGURATION_NOT_FOUND')) {
      return AuthFailure(
        AuthFailureReason.notConfigured,
        developerHint: 'Sign-in is not enabled in the Firebase project '
            '$project ($answer). To fix it, $enable',
      );
    }
    // On iOS and macOS, Firebase answers for a project in which
    // Authentication was never set up with an internal error, which
    // nothing tells from another one.
    if (error.code == 'internal-error' &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AuthFailure(
        AuthFailureReason.notConfigured,
        developerHint: 'Firebase reported an internal error ($answer), which '
            'is also what it answers on iOS and macOS when sign-in is not '
            'enabled in the Firebase project $project. If that is the '
            'cause, $enable',
      );
    }
    return AuthFailure(AuthFailureReason.unknown, developerHint: answer);
  }
}
