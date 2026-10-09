import 'dart:async';

import '../auth/auth_service.dart';

/// The accounts of the fixture by their email addresses, each with the id
/// of its user and its password. They stand for the server of a provider of
/// sign-in, which every start of the app finds as the last one left it.
final Map<String, ({String uid, String password})> _accounts = {};

/// The user who is signed in on this device, or `null`. It stands for the
/// storage of a device, which a start of the app reads.
AuthUser? _onDevice;

/// How many users the fixture created, anonymous ones too.
int _users = 0;

/// The id of a new user.
String _newUid() => 'fixture-user-${++_users}';

/// Opens the sign-in of the fixture, as a start of the app does: it reads
/// from the storage of the device who is signed in, which takes a moment,
/// and returns the service with that user.
///
/// A start keeps the accounts, and the user who was signed in on the
/// device, an anonymous one too. It loses that the user signed in a short
/// while ago: the service deletes the account of a user whom it found on
/// the device only once that user has signed in again. Nothing outlives the
/// process of the app, so each run of the tests of a file starts without
/// an account and with nobody signed in.
Future<AuthService> openFixtureAuth() async {
  final service = FixtureAuth._();
  await service._restore();
  return service;
}

/// Sign-in with accounts in memory. It takes any text for an email address
/// and any password, and sends no message to reset one.
final class FixtureAuth implements AuthService {
  FixtureAuth._();

  final StreamController<AuthUser?> _changes = StreamController.broadcast();

  AuthUser? _user;

  /// Whether the user signed in through this service, and so since the app
  /// started: a short while ago.
  bool _signedInHere = false;

  /// Takes the user who is signed in on the device, once its storage
  /// answered.
  Future<void> _restore() async {
    await Future<void>.delayed(Duration.zero);
    _user = _onDevice;
    _changes.add(_user);
  }

  /// Signs [user] in on the device, or nobody, and tells of the change once
  /// [currentUser] has changed.
  void _set(AuthUser? user) {
    _signedInHere = user != null;
    _user = user;
    _onDevice = user;
    _changes.add(user);
  }

  /// The user who is signed in, for a call that is about that user; it
  /// fails when nobody is.
  AuthUser _signedIn() {
    final user = _user;
    if (user == null) {
      throw const AuthFailure(AuthFailureReason.recentSignInRequired);
    }
    return user;
  }

  /// Fails when [email] has an account already.
  void _checkFree(String email) {
    if (_accounts.containsKey(email)) {
      throw const AuthFailure(AuthFailureReason.emailInUse);
    }
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final account = _accounts[email];
    if (account == null || account.password != password) {
      throw const AuthFailure(AuthFailureReason.invalidCredentials);
    }
    _set(AuthUser(uid: account.uid, isAnonymous: false, email: email));
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    _checkFree(email);
    final uid = _newUid();
    _accounts[email] = (uid: uid, password: password);
    _set(AuthUser(uid: uid, isAnonymous: false, email: email));
  }

  @override
  Future<void> linkPassword({
    required String email,
    required String password,
  }) async {
    final user = _signedIn();
    if (!user.isAnonymous) {
      throw const AuthFailure(
        AuthFailureReason.unknown,
        developerHint: 'The user who is signed in has an account already.',
      );
    }
    _checkFree(email);
    // The anonymous user keeps the id.
    final uid = user.uid;
    _accounts[email] = (uid: uid, password: password);
    _set(AuthUser(uid: uid, isAnonymous: false, email: email));
  }

  @override
  Future<void> signInAnonymously() async =>
      _set(AuthUser(uid: _newUid(), isAnonymous: true));

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async => _set(null);

  /// An anonymous user has nothing to sign in with again, so the service
  /// deletes one whenever it is asked to. It deletes the user of an account
  /// only if that user signed in through this service, since the app
  /// started.
  @override
  Future<void> deleteAccount() async {
    final user = _signedIn();
    if (!user.isAnonymous && !_signedInHere) {
      throw const AuthFailure(AuthFailureReason.recentSignInRequired);
    }
    _accounts.removeWhere((email, account) => account.uid == user.uid);
    _set(null);
  }
}
