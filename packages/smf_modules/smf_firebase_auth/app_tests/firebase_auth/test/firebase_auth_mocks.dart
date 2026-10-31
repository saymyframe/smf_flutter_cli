// The platform side of Firebase Authentication for the tests that
// continuous integration runs in the apps with the firebase_auth module:
// a backend in memory, in place of the Firebase SDK of a device and of the
// server behind it. It starts empty, with no account and nobody signed in,
// as an app finds it on its first launch, and keeps the accounts that the
// app creates for as long as the tests of a test file last. The matrix
// sets it up before the tests of every module of such an app
// (MatrixAppTest.mocks), so that any of them may run the start-up of the
// app, which starts the session of the app on it, and sign in. The mocks
// of Firebase Core come with the tests of firebase_core, which every app
// with the module has.
//
// firebase_auth_platform_interface 9 has no mocks for tests, as those of
// Firebase Core and Crashlytics have, so this answers its messages to the
// platform: each method of FirebaseAuthHostApi and of
// FirebaseAuthUserHostApi on a channel of its own, in the codec of the
// package, with the user of an answer in the classes of its messages. The
// main library of the package does not export the codec and those
// classes, so this imports the file that declares them. A version of the
// package that changes them breaks these tests.
//
// It answers at once, without a timer, so a call completes in a widget
// test too. It keeps to what Firebase does where the app relies on it:
// signing in and signing up replace the user who is signed in, an
// anonymous sign-in while an anonymous user is signed in answers with that
// user, an anonymous user keeps the id with an account and with an
// identity, and a wrong password and an address without an account are
// answered alike.
//
// It takes the credentials of Google and Apple whose ID token is a test
// token: a JSON Web Token without a signature, whose payload has `iss`,
// the issuer of the identity provider, `sub`, the identity there, maybe
// `email`, and `nonce` (see the test of the ways to sign in of the auth
// role, auth_methods, which builds such tokens). It keeps each identity by
// its identity provider and its subject. A token with a nonce is taken
// once. When the credential has a raw nonce, as a credential of Apple
// always does, the nonce of the token must be that raw nonce or the
// SHA-256 hash of that raw nonce, whatever the issuer, since Sign in with
// Apple writes the hash into its token. As in a project with one account for
// each email address, Firebase's default, a credential of an identity of
// another user is refused with credential-already-in-use for a link, and
// one whose email address has an account of another user with
// email-already-in-use for a link and with
// account-exists-with-different-credential for a sign-in. Each refusal
// carries a credential of the identity that the platform keeps and names
// by a number, as Firebase gives one, which a later call takes once in
// place of the token, since the refused call has taken the token. Signing
// in again with a credential of another user is user-mismatch, and with
// one of an identity without a user user-not-found. A reload of a user
// that the server deleted is user-not-found too. A revocation takes an
// authorization code once, and like the Firebase SDK it never answers one
// while nobody is signed in. Each user has an ID token, which a read gives,
// and which a read that forces a refresh and each sign-in replace. A forced
// read tells the plugin of the new token through its stream, as the platform
// does, of the same user. A forced read of a user that the server deleted is
// answered as Android does, with an unknown error whose message says so, since
// the plugin there gives no code for this call.
//
// It differs from Firebase in this:
// - The platform tells the plugin of each change of the user through a
//   stream, a moment after it answered the call that made the change. Here
//   it tells only of a change that a test makes with
//   MockFirebaseAuth.signOutOnPlatform(), and of the token of a forced read.
//   So the plugin has a user who was
//   deleted as its current one until the app signs out, which on a device
//   lasts only that moment.
// - It takes any text for an email address and any password, an empty one
//   too. Firebase refuses a text that is no address and a password of
//   fewer than six characters, and Android and iOS each refuse an empty
//   text in a way of their own.
// - It tells two addresses apart by the case of their letters, where
//   Firebase keeps an address in lower case.
// - It deletes whoever is signed in. Firebase deletes an account only for
//   a user who signed in a short while ago.
// - The ID token of a user is no JSON Web Token: it names the user and how
//   many tokens that user got, and it never expires.
// - It checks no signature, audience or expiry of a token, takes the nonce
//   of a token of Google once too, though Firebase takes such a token again
//   while it is valid, and takes the raw nonce itself as the nonce of the
//   token too, as the test tokens of the auth role have it, where Firebase
//   takes only its hash for Apple.
// - It sends no message, takes any number of attempts, and has no network
//   that could fail.
// - A user whom a test puts on the device (restoreUser) is as Android has
//   one: an anonymous user has empty texts where iOS has none.
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    show InternalUserDetails, InternalUserInfo;
// The codec of the messages, and the classes of an answer with a user and
// of a credential that the platform keeps.
// ignore: implementation_imports
import 'package:firebase_auth_platform_interface/src/pigeon/messages.pigeon.dart'
    show
        FirebaseAuthHostApi,
        InternalAuthCredential,
        InternalIdTokenResult,
        InternalUserCredential;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_core_mocks.dart';

/// The channel of the plugin, under which Firebase Core gives it its
/// constants and from which the names of its streams start.
const _plugin = 'plugins.flutter.io/firebase_auth';

/// The prefix of the channels of the methods of the plugin.
const _channels = 'dev.flutter.pigeon.firebase_auth_platform_interface.';

/// The streams through which the platform tells the plugin of the user, by
/// the method with which the plugin asks for the name of each.
const _streams = {
  'registerIdTokenListener': '$_plugin/id-token/[DEFAULT]',
  'registerAuthStateListener': '$_plugin/auth-state/[DEFAULT]',
};

/// The issuers of the ID tokens of the identity providers whose
/// credentials the backend takes, by the id of each in Firebase.
const _issuers = {
  'google.com': {'https://accounts.google.com', 'accounts.google.com'},
  'apple.com': {'https://appleid.apple.com'},
};

/// An identity of a user at an identity provider: the id of the provider
/// in Firebase, such as `google.com`, and the subject of its tokens.
typedef _Identity = ({String provider, String subject});

/// What the token of a credential tells: the identity, and the email
/// address of the identity if it has one.
typedef _Token = ({_Identity identity, String? email});

/// A user of the backend: an anonymous one while it has neither an email
/// address nor an identity.
final class _User {
  _User(this.uid);

  final String uid;
  String? email;
  String? password;

  /// The identities of the user, each with the email address of its token.
  final Map<_Identity, String?> identities = {};

  /// Whether the server deleted the user, on this device or on another.
  bool deleted = false;

  /// How many ID tokens the user got.
  int tokens = 1;

  bool get isAnonymous => email == null && identities.isEmpty;

  /// Whether the user signs in with a password: a user with a password,
  /// and the user of an account of an email address without an identity,
  /// which a test may put on the device.
  bool get withPassword =>
      password != null || (email != null && identities.isEmpty);

  /// The user as the platform sends it to the plugin.
  InternalUserDetails get details => InternalUserDetails(
        userInfo: InternalUserInfo(
          uid: uid,
          email: email,
          isAnonymous: isAnonymous,
          isEmailVerified: false,
        ),
        providerData: [
          if (withPassword)
            {
              'providerId': 'password',
              'uid': email,
              'email': email,
              'isAnonymous': false,
              'isEmailVerified': false,
            },
          for (final MapEntry(key: (:provider, :subject), value: email)
              in identities.entries)
            {
              'providerId': provider,
              'uid': subject,
              'email': email,
              'isAnonymous': false,
              'isEmailVerified': email != null,
            },
        ],
      );

  /// The user as Android has it for the plugin when the app starts, in the
  /// constants of the plugin: for an anonymous user whom it kept on the
  /// device, the address, the name and the phone number are empty texts,
  /// not none as on iOS, until the user is reloaded.
  List<Object?> get restored => [
        InternalUserInfo(
          uid: uid,
          email: isAnonymous ? '' : email,
          displayName: isAnonymous ? '' : null,
          phoneNumber: isAnonymous ? '' : null,
          isAnonymous: isAnonymous,
          isEmailVerified: false,
        ).encode(),
        details.providerData,
      ];
}

/// An error as the platform answers a call with it, with the details that
/// Firebase gives with it, such as a credential.
final class _Failure implements Exception {
  const _Failure(this.code, [this.message, this.details]);

  final String code;
  final String? message;
  final Map<Object?, Object?>? details;
}

/// The answer of the platform to a call that it never answers.
const _noAnswer = Object();

/// The failure of a credential that the backend does not take.
const _invalidCredential = _Failure(
  'ERROR_INVALID_CREDENTIAL',
  'The supplied auth credential is incorrect, malformed or has expired.',
);

/// The platform side of Firebase Authentication in memory; see
/// [mockFirebaseAuth].
final class MockFirebaseAuth {
  MockFirebaseAuth._();

  /// The users with an email address, by the address.
  final Map<String, _User> _accounts = {};

  /// The users with an identity, by the identity.
  final Map<_Identity, _User> _identities = {};

  /// The nonces of the tokens that the backend took.
  final Set<String> _nonces = {};

  /// The authorization codes that revocations took.
  final Set<String> _codes = {};

  /// What the credentials that the backend gave with its refusals stand
  /// for, by their number, until a call takes them.
  final Map<int, _Token> _given = {};

  final Map<String, _Failure> _failures = {};

  /// What the next calls of each method wait for before they answer.
  final Map<String, List<Completer<void>>> _holds = {};

  _User? _current;
  int _created = 0;
  int _numbers = 0;

  /// The calls that reached the platform side, each as its method followed
  /// by its arguments, without the Firebase app that each has first.
  final List<List<Object?>> calls = [];

  /// The id of the user who is signed in on the platform side, or `null`.
  String? get signedInUid => _current?.uid;

  /// Answers the next call of [method], such as
  /// `signInWithEmailAndPassword`, with an error with [code] and
  /// [message], as a platform sends them: Android sends the code of
  /// Firebase as it is, such as `ERROR_WRONG_PASSWORD`, and iOS in the form
  /// of the plugin, `wrong-password`. The call changes nothing.
  void failNext(String method, {required String code, String? message}) =>
      _failures[method] = _Failure(code, message);

  /// Holds back the next call of [method] that no hold has yet: it answers
  /// once the completer that this returns completes, and takes what
  /// [failNext] says by then, as a slow server does.
  Completer<void> holdNext(String method) {
    final hold = Completer<void>();
    (_holds[method] ??= []).add(hold);
    return hold;
  }

  /// Puts the user [uid] on the device, with the account of [email] or as
  /// an anonymous user, and with an identity at each identity provider of
  /// [identities], the subject of the identity by the id of the provider in
  /// Firebase, such as `apple.com`, as a start of the app on Android finds
  /// a user who signed in when the app last ran: the plugin gets that user
  /// when Firebase is initialized, so call it before that.
  void restoreUser(
    String uid, {
    String? email,
    Map<String, String> identities = const {},
  }) {
    final user = _User(uid)..email = email;
    if (email != null) _accounts[email] = user;
    for (final MapEntry(key: provider, value: subject) in identities.entries) {
      final identity = (provider: provider, subject: subject);
      user.identities[identity] = email;
      _identities[identity] = user;
    }
    _current = user;
    firebasePluginConstants[_plugin] = {'APP_CURRENT_USER': user.restored};
  }

  /// Deletes the user who is signed in on the server, as a deletion of the
  /// account on another device does, and leaves that user signed in on this
  /// device, as the Firebase SDK does until it next asks the server about
  /// the user.
  void deleteUserOnServer() => _delete(_current!);

  /// Signs the user out on the platform side and tells the plugin, as the
  /// Firebase SDK does without a call of the app, such as when it finds
  /// that the session of the user has ended on the server.
  void signOutOnPlatform() {
    _current = null;
    for (final stream in _streams.values) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        stream,
        const StandardMethodCodec().encodeSuccessEnvelope(
          <String, Object?>{'appName': '[DEFAULT]', 'user': null},
        ),
        null,
      );
    }
  }

  /// Answers the messages of the plugin to the platform.
  void _install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = FirebaseAuthHostApi.pigeonChannelCodec;
    void answer(
      String api,
      String method,
      Object? Function(List<Object?> arguments) handle,
    ) {
      messenger.setMockMessageHandler('$_channels$api.$method',
          (message) async {
        final arguments =
            (codec.decodeMessage(message)! as List<Object?>).sublist(1);
        // The plugin asks for its streams when it starts, not the app.
        if (!_streams.containsKey(method)) calls.add([method, ...arguments]);
        final holds = _holds[method];
        if (holds != null && holds.isNotEmpty) await holds.removeAt(0).future;
        final Object? answer;
        try {
          if (_failures.remove(method) case final failure?) throw failure;
          answer = handle(arguments);
        } on _Failure catch (failure) {
          return codec.encodeMessage(
            <Object?>[failure.code, failure.message, failure.details],
          );
        }
        if (identical(answer, _noAnswer)) {
          return Completer<ByteData?>().future;
        }
        return codec.encodeMessage(<Object?>[answer]);
      });
    }

    for (final MapEntry(key: method, value: stream) in _streams.entries) {
      answer('FirebaseAuthHostApi', method, (_) => stream);
      // The plugin listens to the stream and cancels it.
      messenger.setMockMethodCallHandler(
        MethodChannel(stream),
        (call) async => null,
      );
    }
    answer('FirebaseAuthHostApi', 'signInAnonymously', (_) {
      // Firebase answers with the anonymous user who is signed in.
      final current = _current;
      if (current == null || !current.isAnonymous) _signIn(_newUser());
      return _credential;
    });
    answer('FirebaseAuthHostApi', 'createUserWithEmailAndPassword',
        (arguments) {
      final [email as String, password as String] = arguments;
      _checkFree(email);
      _signIn(_account(_newUser(), email, password));
      return _credential;
    });
    answer('FirebaseAuthHostApi', 'signInWithEmailAndPassword', (arguments) {
      final [email as String, password as String] = arguments;
      final account = _accounts[email];
      if (account == null || account.password != password) {
        throw const _Failure(
          'ERROR_INVALID_CREDENTIAL',
          'The supplied auth credential is incorrect, malformed or has '
              'expired.',
        );
      }
      _signIn(account);
      return _credential;
    });
    answer('FirebaseAuthHostApi', 'signInWithCredential', (arguments) {
      final token = _tokenOf(arguments[0]! as Map<Object?, Object?>);
      var user = _identities[token.identity];
      if (user == null) {
        if (_accounts.containsKey(token.email)) {
          throw _Failure(
            'ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL',
            'An account already exists with the same email address but '
                'different sign-in credentials. Sign in using a provider '
                'associated with this email address.',
            _give(token),
          );
        }
        user = _withIdentity(_newUser(), token);
      }
      _signIn(user);
      return _credential;
    });
    // It sends no message, whether the address has an account or not.
    answer('FirebaseAuthHostApi', 'sendPasswordResetEmail', (_) => null);
    answer(
      'FirebaseAuthHostApi',
      'setLanguageCode',
      (arguments) => arguments[0] ?? '',
    );
    answer('FirebaseAuthHostApi', 'signOut', (_) => _current = null);
    answer('FirebaseAuthHostApi', 'revokeTokenWithAuthorizationCode',
        (arguments) {
      if (_current == null) return _noAnswer;
      if (!_codes.add(arguments[0]! as String)) {
        throw const _Failure(
          'invalid-credential',
          'Error getting access token from Apple: invalid_grant',
        );
      }
      return null;
    });
    answer('FirebaseAuthUserHostApi', 'linkWithCredential', (arguments) {
      final user = _signedIn();
      final input = arguments[0]! as Map<Object?, Object?>;
      if (input['signInMethod'] == 'password') {
        final {'email': email as String, 'secret': password as String} = input;
        if (user.withPassword) throw _alreadyLinked;
        _checkFree(email);
        // The user keeps the id.
        _account(user, email, password);
        return _credential;
      }
      final token = _tokenOf(input);
      if (user.identities.keys.any(
        (identity) => identity.provider == token.identity.provider,
      )) {
        throw _alreadyLinked;
      }
      if (_identities.containsKey(token.identity)) {
        throw _Failure(
          'ERROR_CREDENTIAL_ALREADY_IN_USE',
          'This credential is already associated with a different user '
              'account.',
          _give(token),
        );
      }
      if (_accounts[token.email] case final other? when other != user) {
        throw _Failure(
          'ERROR_EMAIL_ALREADY_IN_USE',
          'The email address is already in use by another account.',
          _give(token),
        );
      }
      // The user keeps the id.
      _withIdentity(user, token);
      return _credential;
    });
    answer('FirebaseAuthUserHostApi', 'reauthenticateWithCredential',
        (arguments) {
      final user = _signedIn();
      final token = _tokenOf(arguments[0]! as Map<Object?, Object?>);
      final owner = _identities[token.identity];
      if (owner == null) {
        throw const _Failure(
          'ERROR_USER_NOT_FOUND',
          'There is no user record corresponding to this identifier. The '
              'user may have been deleted.',
        );
      }
      if (owner != user) {
        throw const _Failure(
          'ERROR_USER_MISMATCH',
          'The supplied credentials do not correspond to the previously '
              'signed in user.',
        );
      }
      return _credential;
    });
    answer('FirebaseAuthUserHostApi', 'reload', (_) {
      final user = _signedIn();
      if (user.deleted) {
        throw const _Failure(
          'ERROR_USER_NOT_FOUND',
          'There is no user record corresponding to this identifier. The '
              'user may have been deleted.',
        );
      }
      return user.details;
    });
    answer('FirebaseAuthUserHostApi', 'getIdToken', (arguments) {
      final user = _signedIn();
      final [forceRefresh as bool] = arguments;
      if (forceRefresh) {
        if (user.deleted) {
          throw const _Failure(
            'UNKNOWN',
            'There is no user record corresponding to this identifier. The '
                'user may have been deleted.',
          );
        }
        user.tokens++;
        // A moment after the answer, as the platform tells it.
        scheduleMicrotask(() => _tellOfNewToken(user));
      }
      return InternalIdTokenResult(
        token: 'firebase-token-${user.uid}-${user.tokens}',
      );
    });
    answer('FirebaseAuthUserHostApi', 'delete', (_) {
      _delete(_signedIn());
      // It tells the plugin nothing: see the top of the file.
      _current = null;
      return null;
    });
  }

  /// Tells the plugin that the token of [user] changed: an event of the same
  /// user on the stream of the ID token, which the plugin takes for its user.
  void _tellOfNewToken(_User user) {
    final details = user.details;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      _streams['registerIdTokenListener']!,
      const StandardMethodCodec().encodeSuccessEnvelope(<String, Object?>{
        'appName': '[DEFAULT]',
        'user': [details.userInfo.encode(), details.providerData],
      }),
      null,
    );
  }

  /// The answer to a call that signed a user in: that user.
  InternalUserCredential get _credential =>
      InternalUserCredential(user: _current!.details);

  _User _newUser() => _User('firebase-user-${++_created}');

  /// Gives [user] the account of [email] with [password].
  _User _account(_User user, String email, String password) {
    user
      ..email = email
      ..password = password;
    return _accounts[email] = user;
  }

  /// Gives [user] the identity of [token], and its email address when the
  /// user has none.
  _User _withIdentity(_User user, _Token token) {
    user.identities[token.identity] = token.email;
    _identities[token.identity] = user;
    if (token.email case final email? when user.email == null) {
      user.email = email;
      _accounts[email] = user;
    }
    return user;
  }

  /// Signs [user] in, with a new ID token as a sign-in gives one.
  void _signIn(_User user) {
    _current = user;
    user.tokens++;
  }

  /// Deletes [user] on the server, with its email address and identities.
  void _delete(_User user) {
    user.deleted = true;
    _accounts.remove(user.email);
    _identities.removeWhere((_, owner) => owner == user);
  }

  /// The user who is signed in, for a call that is for that user.
  _User _signedIn() =>
      _current ??
      (throw const _Failure('NO_CURRENT_USER', 'No user currently signed in.'));

  /// Fails when [email] has an account already.
  void _checkFree(String email) {
    if (_accounts.containsKey(email)) {
      throw const _Failure(
        'ERROR_EMAIL_ALREADY_IN_USE',
        'The email address is already in use by another account.',
      );
    }
  }

  /// What the token of [input], a credential that the plugin sends, tells,
  /// which the backend takes: a test token of Google or Apple, whose nonce
  /// it takes once, or a credential that it gave with a refusal, by its
  /// number, which it takes once too.
  _Token _tokenOf(Map<Object?, Object?> input) {
    if (input['token'] case final int number) {
      return _given.remove(number) ?? (throw _invalidCredential);
    }
    final provider = input['providerId'];
    final claims = _claimsOf(input['idToken']);
    final subject = claims?['sub'];
    if (provider is! String ||
        claims == null ||
        subject is! String ||
        !(_issuers[provider]?.contains(claims['iss']) ?? false)) {
      throw _invalidCredential;
    }
    if (claims['nonce'] case final String nonce) {
      final rawNonce = input['rawNonce'];
      if ((rawNonce != null || provider == 'apple.com') &&
          rawNonce != nonce &&
          (rawNonce is! String || _sha256Of(rawNonce) != nonce)) {
        throw const _Failure(
          'ERROR_MISSING_OR_INVALID_NONCE',
          'The nonce of the request does not match the nonce of the token.',
        );
      }
      if (!_nonces.add(nonce)) {
        throw const _Failure(
          'ERROR_MISSING_OR_INVALID_NONCE',
          'Duplicate credential received. Please try again with a new '
              'credential.',
        );
      }
    }
    final email = claims['email'];
    return (
      identity: (provider: provider, subject: subject),
      email: email is String ? email : null,
    );
  }

  /// The details of a refusal with a credential of the identity of
  /// [token], which a later call takes in place of the token: the number by
  /// which the platform keeps it, and the email address of the identity.
  Map<Object?, Object?> _give(_Token token) {
    final number = ++_numbers;
    _given[number] = token;
    final details = <Object?, Object?>{
      'authCredential': InternalAuthCredential(
        providerId: token.identity.provider,
        signInMethod: token.identity.provider,
        nativeId: number,
      ),
    };
    if (token.email case final email?) details['email'] = email;
    return details;
  }
}

/// The failure of a link of a way to sign in that the user has already.
const _alreadyLinked = _Failure(
  'PROVIDER_ALREADY_LINKED',
  'User has already been linked to the given provider.',
);

/// The claims of [idToken], a JSON Web Token, or `null` for anything else.
Map<String, Object?>? _claimsOf(Object? idToken) {
  if (idToken is! String) return null;
  final parts = idToken.split('.');
  if (parts.length != 3) return null;
  try {
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return claims is Map<String, Object?> ? claims : null;
  } on FormatException {
    return null;
  }
}

/// The SHA-256 hash of [text] in hexadecimal (FIPS 180-4), which Sign in with
/// Apple writes into its token as the nonce of a raw nonce. The app of a
/// provider may have no package for it, so the mocks hash it themselves.
String _sha256Of(String text) {
  const k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];
  int rotate(int word, int bits) =>
      (word >> bits | word << (32 - bits)) & 0xffffffff;
  final message = utf8.encode(text);
  final bytes = [...message, 0x80];
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  for (var shift = 56; shift >= 0; shift -= 8) {
    bytes.add(message.length * 8 >> shift & 0xff);
  }
  final hash = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, //
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];
  for (var chunk = 0; chunk < bytes.length; chunk += 64) {
    final w = List.filled(64, 0);
    for (var i = 0; i < 64; i++) {
      if (i < 16) {
        for (var byte = 0; byte < 4; byte++) {
          w[i] = w[i] << 8 | bytes[chunk + i * 4 + byte];
        }
      } else {
        final s0 =
            rotate(w[i - 15], 7) ^ rotate(w[i - 15], 18) ^ w[i - 15] >> 3;
        final s1 = rotate(w[i - 2], 17) ^ rotate(w[i - 2], 19) ^ w[i - 2] >> 10;
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
      }
    }
    var [a, b, c, d, e, f, g, h] = hash;
    for (var i = 0; i < 64; i++) {
      final s1 = rotate(e, 6) ^ rotate(e, 11) ^ rotate(e, 25);
      final t1 = (h + s1 + (e & f ^ ~e & g) + k[i] + w[i]) & 0xffffffff;
      final s0 = rotate(a, 2) ^ rotate(a, 13) ^ rotate(a, 22);
      final t2 = (s0 + (a & b ^ a & c ^ b & c)) & 0xffffffff;
      (h, g, f, e, d, c, b, a) =
          (g, f, e, (d + t1) & 0xffffffff, c, b, a, (t1 + t2) & 0xffffffff);
    }
    for (final (i, word) in [a, b, c, d, e, f, g, h].indexed) {
      hash[i] = (hash[i] + word) & 0xffffffff;
    }
  }
  return [for (final word in hash) word.toRadixString(16).padLeft(8, '0')]
      .join();
}

/// Answers the platform side of Firebase Authentication with a backend in
/// memory that has no account and nobody signed in, and returns it: a test
/// reads there what reached the platform side, and scripts what it
/// answers. The plugin starts without a user, as on a first launch of the
/// app.
///
/// The binding of the tests must be initialized first. A test file that
/// calls it for a backend of its own does so before the app starts or
/// Firebase is initialized, since the plugin keeps the user of the backend
/// that it started on.
MockFirebaseAuth mockFirebaseAuth() {
  firebasePluginConstants.remove(_plugin);
  return MockFirebaseAuth._().._install();
}
