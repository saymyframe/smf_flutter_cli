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

/// The codes of an answer of Firebase to a revocation that are no matter of
/// the setup of the Apple sign-in method of the project: a request that did
/// not reach Firebase, too many attempts, a disabled account, and a session
/// that has ended.
const _notOfSetup = {
  'network-request-failed',
  'too-many-requests',
  'user-disabled',
  ..._endedSession,
};

/// The issuer of the ID tokens of Google.
const _google = 'https://accounts.google.com';

/// The issuer of the ID tokens of Apple.
const _apple = 'https://appleid.apple.com';

/// The identity providers whose credentials the service takes, by the
/// issuer of their tokens: the id of each in Firebase Authentication, and
/// its name among the sign-in methods of the Firebase console.
const _providers = {
  _google: (id: 'google.com', name: 'Google'),
  _apple: (id: 'apple.com', name: 'Apple'),
};

/// The reasons of the codes with which Firebase refuses
/// [FirebaseAuthService.linkWith] because the identity of the credential,
/// or its email address, belongs to another user. For
/// [FirebaseAuthService.linkPassword], the same codes mean that the email
/// address has an account, `emailInUse`.
const _linkReasons = {
  'credential-already-in-use': AuthFailureReason.credentialInUse,
  'email-already-in-use': AuthFailureReason.accountExistsWithOtherMethod,
  'account-exists-with-different-credential':
      AuthFailureReason.accountExistsWithOtherMethod,
};

/// Sign-in with
/// [Firebase Authentication](https://firebase.google.com/docs/auth), with
/// an email address and a password, as an anonymous user, and with the
/// credentials that the ways to sign in of Google and Apple get.
///
/// The code of the app does not use it: it signs in through `appSession` of
/// `app_session.dart`.
///
/// The ways to sign in are enabled in the Firebase project, not here:
/// Email/Password, Anonymous for an app that signs in anonymous users, and
/// Google and Apple for an app with their ways to sign in.
/// `tool/enable_firebase_sign_in.dart` enables all but Apple. Until they
/// are, a call fails with [AuthFailureReason.notConfigured], and its
/// [AuthFailure.developerHint] tells how to enable them.
///
/// An empty address or password fails here, before Firebase is asked, since
/// Android and iOS answer it with different codes: an empty address with
/// [AuthFailureReason.invalidEmail], and an empty password with
/// [AuthFailureReason.invalidCredentials] in [signIn] and with
/// [AuthFailureReason.weakPassword] in [signUp] and [linkPassword].
///
/// A credential of Google goes to Firebase with its ID token, and one of
/// Apple with its ID token, its raw nonce and the name of the user:
/// `GoogleAuthProvider` takes no nonce, and Firebase does not check the
/// nonce of a token of Google. A credential of another identity
/// provider fails with [AuthFailureReason.notConfigured] before Firebase is
/// asked. Apple takes a credential once, so when Firebase refuses
/// [linkWith] because the identity or its email address belongs to another
/// user, the service keeps the credential that Firebase gives with its
/// answer, and [signInWith] of the identical credential object signs in
/// with that one.
///
/// [deleteAccount] with a fresh credential signs the user in again with it,
/// and, for a credential of Apple, revokes the tokens that Apple gave the
/// app with its authorization code before it deletes the account, as the
/// App Store asks of an app with Sign in with Apple. Firebase revokes them
/// on iOS and macOS, and has no call for it elsewhere. A revocation needs
/// the Services ID and the OAuth code flow configuration of the Apple
/// sign-in method in the Firebase console: without them it fails with
/// [AuthFailureReason.notConfigured], and the account stays.
///
/// [userToken] is the Firebase ID token of the user, which the Firebase SDK
/// keeps on the device and renews when it is about to expire. A
/// server verifies it with the Firebase Admin SDK, as a token of the Firebase
/// project that the app is configured with.
final class FirebaseAuthService implements AuthService {
  /// Creates the service on [_auth].
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  /// What Firebase gave with its answer to a link that it refused, for the
  /// credential object of the link: a credential of the same identity,
  /// which the plugin keeps on the platform and names by a number. It may
  /// carry the token that the platform gave, and is dropped once used. No
  /// hint names it.
  final Expando<AuthCredential> _givenForRefusedLink = Expando();

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
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    final email = user.email;
    return AuthUser(
      uid: user.uid,
      isAnonymous: user.isAnonymous,
      // Android has an empty address, not none, for an anonymous user whom
      // it kept on the device.
      email: email == null || email.isEmpty ? null : email,
      issuers: {
        for (final MapEntry(key: issuer, value: (:id, name: _))
            in _providers.entries)
          if (user.providerData.any((info) => info.providerId == id)) issuer,
      },
    );
  }

  /// Each event has the user of the moment in which a listener gets it, so
  /// a listener never hears of a user who is not [currentUser] any more.
  @override
  Stream<AuthUser?> get userChanges => _changes.stream.map((_) => currentUser);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _run(() {
        _checkGiven(email, password, AuthFailureReason.invalidCredentials);
        return _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      });

  @override
  Future<void> signUp({required String email, required String password}) =>
      _run(() {
        _checkGiven(email, password, AuthFailureReason.weakPassword);
        return _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      });

  @override
  Future<void> linkPassword({
    required String email,
    required String password,
  }) =>
      _runForUser((user) {
        _checkGiven(email, password, AuthFailureReason.weakPassword);
        return user.linkWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
      });

  /// After a link of the identical [credential] that Firebase refused, it
  /// signs in with the credential that Firebase gave with that answer, once.
  @override
  Future<void> signInWith(SignInCredential credential) => _run(
        () {
          final given = _givenForRefusedLink[credential];
          _givenForRefusedLink[credential] = null;
          return _auth.signInWithCredential(given ?? _firebaseOf(credential));
        },
        credential: credential,
      );

  @override
  Future<void> linkWith(SignInCredential credential) => _runForUser(
        (user) async {
          final ofFirebase = _firebaseOf(credential);
          try {
            await user.linkWithCredential(ofFirebase);
          } on FirebaseAuthException catch (error) {
            // The sign-in that follows takes the credential that Firebase
            // gave: Apple takes the token of a credential once, and the
            // refused link has taken it.
            if (_linkReasons.containsKey(error.code)) {
              _givenForRefusedLink[credential] = error.credential;
            }
            rethrow;
          }
        },
        credential: credential,
        reasons: _linkReasons,
      );

  /// While an anonymous user is signed in, Firebase answers with that user
  /// and creates no other.
  @override
  Future<void> signInAnonymously() => _run(_auth.signInAnonymously);

  /// Firebase sends the message from the template of the project
  /// (Authentication > Templates in the Firebase console).
  @override
  Future<void> sendPasswordReset(String email) => _run(() async {
        _checkGiven(email);
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
  Future<void> deleteAccount({SignInCredential? fresh}) => _runForUser(
        (user) async {
          if (fresh != null) await _signInAgain(user, fresh);
          await user.delete();
          // Firebase signs a deleted user out, but the plugin keeps that
          // user as the current one until the platform tells it of the
          // sign-out, which may come after this call is over.
          await _auth.signOut();
        },
        credential: fresh,
      );

  /// It reads past [_run], which tells of the user after each call, since an
  /// app may read the token for each of its requests. A forced read still
  /// gives [userChanges] an event of the same user, since Firebase tells that
  /// the token changed, and so does a reload.
  ///
  /// When the platform has nobody, as while a sign-out is on its way, the
  /// plugin may not have heard of it yet: nobody is signed in, so there is no
  /// token.
  @override
  Future<String?> userToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken(forceRefresh);
    } on Object catch (error, stackTrace) {
      if (error is FirebaseAuthException && error.code == 'no-current-user') {
        return null;
      }
      Error.throwWithStackTrace(await _failureOfRead(user, error), stackTrace);
    }
  }

  /// The failure of a read of the token of [user] that failed with [error].
  ///
  /// On Android the plugin answers the read with the code `unknown` for each
  /// answer of the server but a network failure, also for a user whom the
  /// server deleted or disabled, with the code only in a text. A reload of the
  /// user answers with the code, so the service asks that.
  ///
  /// When the server no longer takes [user], the service signs that user out,
  /// as the Firebase SDK does a moment later, and tells of it. A read runs
  /// next to the calls of the app, so it does so only while [user] is still
  /// signed in: by now another user may be.
  Future<AuthFailure> _failureOfRead(User user, Object error) async {
    final answer = error is FirebaseAuthException && error.code == 'unknown'
        ? await _answerToReload(user) ?? error
        : error;
    final code = answer is FirebaseAuthException ? answer.code : null;
    final disabled = code == 'user-disabled';
    if (!disabled && !_endedSession.contains(code)) return _readFailure(answer);
    if (_auth.currentUser?.uid == user.uid) {
      try {
        await _auth.signOut();
      } on Object catch (signOutError) {
        return _readFailure(signOutError);
      }
      _changes.add(null);
    }
    return AuthFailure(
      disabled
          ? AuthFailureReason.userDisabled
          : AuthFailureReason.recentSignInRequired,
    );
  }

  /// The failure of a read for [error], as that of any other call, but that
  /// a read of a user who is signed in never says that sign-in is not enabled
  /// in the project, as an internal error of iOS would.
  AuthFailure _readFailure(Object error) {
    final failure = _failureOf(error, null, const {});
    return failure.reason == AuthFailureReason.notConfigured
        ? AuthFailure(AuthFailureReason.unknown, developerHint: _answerOf(error))
        : failure;
  }

  /// What a reload of [user] fails with, or `null` if it completes.
  Future<Object?> _answerToReload(User user) async {
    try {
      await user.reload();
      return null;
    } on Object catch (error) {
      return error;
    }
  }

  /// Signs [user] in again with [fresh], so that Firebase deletes the
  /// account without asking for a recent sign-in, and revokes the tokens of
  /// Apple with the authorization code of [fresh] where it does.
  Future<void> _signInAgain(User user, SignInCredential fresh) async {
    final ofFirebase = _firebaseOf(fresh);
    final code = _codeToRevoke(fresh);
    try {
      await user.reauthenticateWithCredential(ofFirebase);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found') rethrow;
      // Firebase answers so for a credential of an identity that has no
      // user, and for a credential of the user when the account was
      // deleted on the server, such as on another device. A reload of the
      // user fails for the second with a code of a session that has ended,
      // which signs the user out.
      await user.reload();
      throw const AuthFailure(AuthFailureReason.invalidCredentials);
    }
    if (code != null) await _revoke(code);
  }

  /// The authorization code with which the service revokes the tokens that
  /// Apple gave the app before it deletes the account, for a [fresh]
  /// credential of Apple on iOS and macOS, or `null`: Firebase has no call
  /// for the revocation on the other platforms. Apple takes a code once, so
  /// it is the code of the fresh credential, never that of a sign-in
  /// before.
  String? _codeToRevoke(SignInCredential fresh) {
    if (fresh case IdTokenCredential(issuer: _apple, :final authorizationCode)
        when defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS) {
      return authorizationCode ??
          (throw const AuthFailure(
            AuthFailureReason.notConfigured,
            developerHint: 'The credential of Apple has no authorization '
                'code, with which Firebase revokes the tokens that Apple '
                'gave the app before the account is deleted, so the account '
                'was not deleted. The way to sign in with Apple gives one '
                'with each credential.',
          ));
    }
    return null;
  }

  /// Revokes the tokens that Apple gave the app with the authorization
  /// [code]. A failure keeps the account: it is
  /// [AuthFailureReason.notConfigured], but for an answer of Firebase that
  /// is no matter of the setup ([_notOfSetup]), which gets its reason as
  /// that of any other call.
  Future<void> _revoke(String code) async {
    // Firebase never completes the call while nobody is signed in.
    if (_auth.currentUser == null) {
      throw const AuthFailure(AuthFailureReason.recentSignInRequired);
    }
    try {
      await _auth.revokeTokenWithAuthorizationCode(code);
    } on Object catch (error) {
      if (error is FirebaseAuthException &&
          _notOfSetup.contains(error.code)) {
        rethrow;
      }
      final project = _auth.app.options.projectId;
      throw AuthFailure(
        AuthFailureReason.notConfigured,
        developerHint: 'Firebase did not revoke the tokens that Apple gave '
            'the app (${_answerOf(error)}), so the account was not deleted. '
            'The revocation needs the Services ID and the OAuth code flow '
            'configuration, with the Apple team ID, the Key ID and the '
            'private key, of the Apple sign-in method of the Firebase '
            'project $project, in the Firebase console under '
            'Authentication > Sign-in method: ${_consoleOf(project)}. When '
            'they are set, the authorization code of Apple was older than '
            'five minutes or used before, and the next deletion asks Apple '
            'for a new one.',
      );
    }
  }

  /// The credential of Firebase Authentication for [credential]. One of
  /// Google has the ID token alone: `GoogleAuthProvider` takes no nonce, and
  /// Firebase does not check the nonce of a token of Google.
  ///
  /// It fails with [AuthFailureReason.notConfigured] for a credential of an
  /// identity provider that the service does not take, and for a credential
  /// of Apple without the raw nonce, which Firebase checks the token of
  /// Apple against.
  AuthCredential _firebaseOf(SignInCredential credential) =>
      switch (credential) {
        IdTokenCredential(issuer: _google, :final idToken) =>
          GoogleAuthProvider.credential(idToken: idToken),
        IdTokenCredential(
          issuer: _apple,
          :final idToken,
          :final rawNonce?,
          :final givenName,
          :final familyName,
        ) =>
          AppleAuthProvider.credentialWithIDToken(
            idToken,
            rawNonce,
            AppleFullPersonName(givenName: givenName, familyName: familyName),
          ),
        IdTokenCredential(issuer: _apple) => throw const AuthFailure(
            AuthFailureReason.notConfigured,
            developerHint: 'The credential of Apple has no raw nonce, which '
                'Firebase checks the token of Apple against. The way to sign '
                'in with Apple gives the nonce of its request with each '
                'credential.',
          ),
        IdTokenCredential(:final issuer) => throw AuthFailure(
            AuthFailureReason.notConfigured,
            developerHint: 'The app signs in to Firebase Authentication with '
                'the credentials of Google ($_google) and Apple ($_apple), '
                'and takes no credential of $issuer.',
          ),
      };

  /// Runs [call] for the user who is signed in, as [_run] runs a call.
  ///
  /// It fails with [AuthFailureReason.recentSignInRequired] when nobody is
  /// signed in, and when Firebase answers that the session of the user has
  /// ended: the user is then signed out on this device first.
  Future<void> _runForUser(
    Future<void> Function(User user) call, {
    SignInCredential? credential,
    Map<String, AuthFailureReason> reasons = const {},
  }) =>
      _run(
        () async {
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
        },
        credential: credential,
        reasons: reasons,
      );

  /// Fails for an [email] that is empty with
  /// [AuthFailureReason.invalidEmail], and for a [password] that is empty
  /// with [withoutPassword], before Firebase is asked. Android refuses an
  /// empty text with a code that has no reason, and iOS answers an empty
  /// password as a wrong one, so the service decides for both.
  void _checkGiven(
    String email, [
    String? password,
    AuthFailureReason withoutPassword = AuthFailureReason.weakPassword,
  ]) {
    if (email.isEmpty) {
      throw const AuthFailure(AuthFailureReason.invalidEmail);
    }
    if (password != null && password.isEmpty) {
      throw AuthFailure(withoutPassword);
    }
  }

  /// Runs [call], which then fails only with an [AuthFailure], and tells
  /// of the user that it leaves, also when it failed.
  ///
  /// A code of Firebase gets its reason of [reasons], the reasons of the
  /// codes for this call, and otherwise that of [_failureOf]. [credential]
  /// is the credential that the call signs in with, whose way to sign in
  /// the hint of a failure names.
  Future<void> _run(
    Future<void> Function() call, {
    SignInCredential? credential,
    Map<String, AuthFailureReason> reasons = const {},
  }) async {
    try {
      await call();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _failureOf(error, credential, reasons),
        stackTrace,
      );
    } finally {
      _changes.add(null);
    }
  }

  /// The failure of a call that failed with [error]: the reason for the
  /// code of Firebase, from [reasons] first. A code that has no reason yet
  /// gets one here. The hint of a way to sign in that is not enabled names
  /// the way to sign in of [credential], or Email/Password and Anonymous.
  AuthFailure _failureOf(
    Object error,
    SignInCredential? credential,
    Map<String, AuthFailureReason> reasons,
  ) {
    if (error is AuthFailure) return error;
    if (error is! FirebaseAuthException) {
      return AuthFailure(AuthFailureReason.unknown, developerHint: '$error');
    }
    final reason = reasons[error.code] ??
        switch (error.code) {
          // Firebase answers a wrong password and an address without an
          // account alike, unless the project is without the protection
          // against the enumeration of email addresses. It also answers so
          // for a credential that it refuses, such as one that expired, and
          // for one whose nonce it took before.
          'invalid-credential' ||
          'invalid-login-credentials' ||
          'wrong-password' ||
          'user-not-found' ||
          'missing-or-invalid-nonce' ||
          // A fresh credential of another user than the one whose account
          // is deleted.
          'user-mismatch' =>
            AuthFailureReason.invalidCredentials,
          'email-already-in-use' ||
          'credential-already-in-use' =>
            AuthFailureReason.emailInUse,
          'account-exists-with-different-credential' =>
            AuthFailureReason.accountExistsWithOtherMethod,
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
    final answer = _answerOf(error);
    final project = _auth.app.options.projectId;
    final console = 'the Firebase console under Authentication > Sign-in '
        'method: ${_consoleOf(project)}';
    final method = switch (credential) {
      IdTokenCredential(:final issuer) => _providers[issuer]?.name,
      null => null,
    };
    final script = 'run `dart tool/enable_firebase_sign_in.dart --project '
        '$project` in the directory of the app';
    // The way to sign in, after "sign-in", and what enables it: the script
    // of the app enables Email/Password, Anonymous and Google, in the project
    // of this flavor of the app, and the Firebase console every way to sign
    // in.
    final (withMethod, enable) = switch (method) {
      null => (
          '',
          '$script, or enable Email/Password, and Anonymous for an app that '
              'signs in anonymous users, in $console',
        ),
      'Google' => (' with Google', '$script, or enable Google in $console'),
      _ => (' with $method', 'enable $method in $console'),
    };
    // A way to sign in that is not enabled, which Firebase tells by its
    // code, and a project in which Authentication was never set up, which
    // it tells only in its message.
    const noConfiguration = 'CONFIGURATION_NOT_FOUND';
    final notEnabled = switch (error.code) {
      'operation-not-allowed' || 'admin-restricted-operation' => error.code,
      _ when answer.contains(noConfiguration) =>
        '${error.code}, $noConfiguration',
      _ => null,
    };
    if (notEnabled != null) {
      return AuthFailure(
        AuthFailureReason.notConfigured,
        developerHint: 'Sign-in$withMethod is not enabled in the Firebase '
            'project $project (Firebase answered $notEnabled). To fix it, '
            '$enable',
      );
    }
    // On iOS and macOS, Firebase may answer for such a project with an
    // internal error whose message says no more, which nothing tells from
    // another internal error.
    if (error.code == 'internal-error' &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AuthFailure(
        AuthFailureReason.notConfigured,
        developerHint: 'Firebase reported an internal error ($answer), which '
            'is also what it answers on iOS and macOS when sign-in$withMethod '
            'is not enabled in the Firebase project $project. If that is the '
            'cause, $enable',
      );
    }
    return AuthFailure(AuthFailureReason.unknown, developerHint: answer);
  }

  /// What Firebase answered with [error]: its code and its message on one
  /// line, since the message of iOS may be the description of an error over
  /// many lines, or the error itself when it is no error of Firebase.
  String _answerOf(Object error) {
    if (error is! FirebaseAuthException) return '$error';
    final message =
        (error.message ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return message.isEmpty ? error.code : '${error.code}: $message';
  }

  /// The page of the Firebase console with the sign-in methods of
  /// [project].
  String _consoleOf(String project) =>
      'https://console.firebase.google.com/project/$project/'
      'authentication/providers';
}
