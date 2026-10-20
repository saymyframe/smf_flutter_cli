import 'dart:async';
import 'dart:convert';

import '../auth/auth_service.dart';

/// An account of the fixture: its email address and its password, if it has
/// them, and the identity providers that it signs in with, each by the
/// issuer of its tokens.
typedef _Account = ({String? email, String? password, Set<String> issuers});

/// The accounts of the fixture by the ids of their users. They stand for
/// the server of a provider of sign-in, which every start of the app finds
/// as the last one left it. An anonymous user has none.
final Map<String, _Account> _accounts = {};

/// The ids of the users of the identities of the fixture, by the issuer and
/// the subject of each identity, as its tokens name it.
final Map<(String, String), String> _identities = {};

/// The identity of a test token: its issuer, its subject and its email
/// address.
typedef _Identity = ({String issuer, String subject, String? email});

/// The nonces of the tokens that the fixture took. An identity provider that
/// checks a nonce takes a token with it once, and so does the fixture.
final Set<String> _spentNonces = {};

/// The user who is signed in on this device, or `null`. It stands for the
/// storage of a device, which a start of the app reads.
AuthUser? _onDevice;

/// How many users the fixture created, anonymous ones too.
int _users = 0;

/// The id of a new user.
String _newUid() => 'fixture-user-${++_users}';

/// Waits for the answer of the server or of the storage of the device,
/// which takes a moment, as with a provider that has them: a turn of the
/// event loop. So a test makes the calls of sign-in in real time, as it
/// runs the start-up of the app.
Future<void> _answer() => Future<void>.delayed(Duration.zero);

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
/// and any password, and sends no message to reset one. Each of its calls
/// takes a moment, as one that asks a server does.
///
/// It takes a credential of any identity provider whose token is a test
/// token: a JSON Web Token without a signature whose payload has `iss`, the
/// issuer of the credential, `sub`, the identity, maybe `email`, the email
/// address of the identity, and maybe `nonce`, which is then the rawNonce of
/// the credential. It keeps each identity by its issuer and its subject, and
/// refuses any other token with [AuthFailureReason.invalidCredentials], as
/// it refuses a token whose nonce it took already. An identity whose
/// address has an account of another user, such as one with a password,
/// signs in to nothing: [linkWith] and [signInWith] fail with
/// [AuthFailureReason.accountExistsWithOtherMethod]. A refused link takes
/// the token too, and keeps the identity for the credential object, which
/// [signInWith] of the identical object then signs in with. It has no
/// tokens of an identity provider to revoke when it deletes an account.
final class FixtureAuth implements AuthService {
  FixtureAuth._();

  /// The identity of each credential object that [linkWith] refused, until
  /// [signInWith] of the identical object takes it.
  final Expando<_Identity> _refused = Expando('refused links');

  final StreamController<AuthUser?> _changes = StreamController.broadcast();

  AuthUser? _user;

  /// Whether the user signed in through this service, and so since the app
  /// started: a short while ago.
  bool _signedInHere = false;

  /// Takes the user who is signed in on the device, once its storage
  /// answered.
  Future<void> _restore() async {
    await _answer();
    _user = _onDevice;
    // No listener hears this: nothing has the service before
    // [openFixtureAuth] returns it, which waits for this. It is here so
    // that the fixture with a known bug that returns the service first
    // differs in one line, and tells of the user that it finds late.
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

  /// The id of the user whose account has [email], or `null`.
  String? _ownerOf(String email) => _accounts.entries
      .where((account) => account.value.email == email)
      .firstOrNull
      ?.key;

  /// Fails when [email] has an account already.
  void _checkFree(String email) {
    if (_ownerOf(email) != null) {
      throw const AuthFailure(AuthFailureReason.emailInUse);
    }
  }

  /// The user of the account of [uid], which has one.
  AuthUser _userOf(String uid) {
    final account = _accounts[uid]!;
    return AuthUser(
      uid: uid,
      isAnonymous: false,
      email: account.email,
      issuers: {...account.issuers},
    );
  }

  /// The identity of [credential], whose token the call takes: what the
  /// fixture kept for the identical object when [linkWith] refused it just
  /// before, or else the identity of its test token, whose nonce is then
  /// spent. Fails with [AuthFailureReason.invalidCredentials] for a token
  /// that is no test token of the issuer of the credential, one whose nonce
  /// is not the rawNonce of the credential, and one whose nonce the fixture
  /// took already.
  _Identity _take(SignInCredential credential) {
    if (_refused[credential] case final kept?) {
      _refused[credential] = null;
      return kept;
    }
    final (issuer, idToken, rawNonce) = switch (credential) {
      IdTokenCredential(:final issuer, :final idToken, :final rawNonce) => (
          issuer,
          idToken,
          rawNonce,
        ),
    };
    final parts = idToken.split('.');
    final payload = parts.length == 3 ? _payloadOf(parts[1]) : null;
    if (payload == null ||
        payload['iss'] != issuer ||
        payload['sub'] is! String ||
        payload['email'] is! String? ||
        payload['nonce'] is! String? ||
        payload['nonce'] != rawNonce) {
      throw AuthFailure(
        AuthFailureReason.invalidCredentials,
        developerHint: 'The fixture sign-in takes a test token, a JSON Web '
            'Token whose payload has iss, the issuer of the credential, sub, '
            'and maybe nonce, the rawNonce of the credential, which '
            '$credential does not have.',
      );
    }
    if (payload['nonce'] case final String nonce
        when !_spentNonces.add(nonce)) {
      throw AuthFailure(
        AuthFailureReason.invalidCredentials,
        developerHint: 'The fixture sign-in took the token of $credential '
            'already, and takes a token with a nonce once.',
      );
    }
    return (
      issuer: issuer,
      subject: payload['sub']! as String,
      email: payload['email'] as String?,
    );
  }

  /// The payload of a JSON Web Token as an object, from [part], the second
  /// part of the token, or `null` if it is none.
  static Map<String, Object?>? _payloadOf(String part) {
    try {
      final json = utf8.decode(base64Url.decode(base64Url.normalize(part)));
      return switch (jsonDecode(json)) {
        final Map<String, Object?> payload => payload,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _answer();
    final uid = _ownerOf(email);
    if (uid == null || _accounts[uid]!.password != password) {
      throw const AuthFailure(AuthFailureReason.invalidCredentials);
    }
    _set(_userOf(uid));
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await _answer();
    _checkFree(email);
    final uid = _newUid();
    _accounts[uid] = (email: email, password: password, issuers: {});
    _set(_userOf(uid));
  }

  @override
  Future<void> linkPassword({
    required String email,
    required String password,
  }) async {
    await _answer();
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
    _accounts[uid] = (email: email, password: password, issuers: {});
    _set(_userOf(uid));
  }

  /// Signs in to the user of the identity of [credential], and creates that
  /// user when the identity is new, unless the address of the identity has
  /// an account of another user.
  @override
  Future<void> signInWith(SignInCredential credential) async {
    await _answer();
    final identity = _take(credential);
    final key = (identity.issuer, identity.subject);
    if (_identities[key] case final uid?) {
      _set(_userOf(uid));
      return;
    }
    if (identity.email case final email? when _ownerOf(email) != null) {
      throw const AuthFailure(AuthFailureReason.accountExistsWithOtherMethod);
    }
    final uid = _newUid();
    _accounts[uid] = (
      email: identity.email,
      password: null,
      issuers: {identity.issuer},
    );
    _identities[key] = uid;
    _set(_userOf(uid));
  }

  @override
  Future<void> linkWith(SignInCredential credential) async {
    await _answer();
    final user = _signedIn();
    final identity = _take(credential);
    final key = (identity.issuer, identity.subject);
    if (_identities[key] case final owner?) {
      if (owner == user.uid) {
        throw const AuthFailure(
          AuthFailureReason.unknown,
          developerHint: 'The user who is signed in has the identity already.',
        );
      }
      // The token is spent, so the sign-in that follows takes what the
      // fixture keeps for the credential object.
      _refused[credential] = identity;
      throw const AuthFailure(AuthFailureReason.credentialInUse);
    }
    if (identity.email case final email?
        when (_ownerOf(email) ?? user.uid) != user.uid) {
      _refused[credential] = identity;
      throw const AuthFailure(AuthFailureReason.accountExistsWithOtherMethod);
    }
    final account = _accounts.remove(user.uid);
    // The user who is signed in keeps the id with the identity.
    final uid = user.uid;
    _accounts[uid] = (
      email: account?.email ?? identity.email,
      password: account?.password,
      issuers: {...?account?.issuers, identity.issuer},
    );
    _identities[key] = uid;
    _set(_userOf(uid));
  }

  @override
  Future<void> signInAnonymously() async {
    await _answer();
    _set(AuthUser(uid: _newUid(), isAnonymous: true));
  }

  @override
  Future<void> sendPasswordReset(String email) => _answer();

  @override
  Future<void> signOut() async {
    await _answer();
    _set(null);
  }

  /// An anonymous user has nothing to sign in with again, so the service
  /// deletes one whenever it is asked to. It deletes the user of an account
  /// only if that user signed in through this service, since the app
  /// started, or with [fresh], a credential of an identity of the user,
  /// which signs the user in again. A credential of another identity fails
  /// with [AuthFailureReason.invalidCredentials] and deletes nothing.
  @override
  Future<void> deleteAccount({SignInCredential? fresh}) async {
    await _answer();
    final user = _signedIn();
    if (fresh != null) {
      final identity = _take(fresh);
      if (_identities[(identity.issuer, identity.subject)] != user.uid) {
        throw const AuthFailure(
          AuthFailureReason.invalidCredentials,
          developerHint: 'The credential is not of the user who is signed '
              'in.',
        );
      }
      _signedInHere = true;
    }
    if (!user.isAnonymous && !_signedInHere) {
      throw const AuthFailure(AuthFailureReason.recentSignInRequired);
    }
    _accounts.remove(user.uid);
    _identities.removeWhere((identity, uid) => uid == user.uid);
    _set(null);
  }
}
