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
// anonymous user keeps the id with an account, and a wrong password and an
// address without an account are answered alike. It differs in one thing:
// the platform tells the plugin of each change of the user through a
// stream, a moment after it answered the call that made the change, and
// here it tells only of a change that a test makes with
// [MockFirebaseAuth.signOutOnPlatform]. So the plugin has a user who was
// deleted as its current one until the app signs out, which on a device
// lasts only that moment.
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    show InternalUserDetails, InternalUserInfo;
// The codec of the messages and the class of an answer with a user.
// ignore: implementation_imports
import 'package:firebase_auth_platform_interface/src/pigeon/messages.pigeon.dart'
    show FirebaseAuthHostApi, InternalUserCredential;
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

/// A user of the backend: an anonymous one while it has no email address.
final class _User {
  _User(this.uid);

  final String uid;
  String? email;
  String? password;

  /// The user as the platform sends it to the plugin.
  InternalUserDetails get details => InternalUserDetails(
        userInfo: InternalUserInfo(
          uid: uid,
          email: email,
          isAnonymous: email == null,
          isEmailVerified: false,
        ),
        providerData: [
          if (email != null)
            {
              'providerId': 'password',
              'uid': email,
              'email': email,
              'isAnonymous': false,
              'isEmailVerified': false,
            },
        ],
      );

  /// The user as the platform sends it outside the answer to a call: in
  /// the constants of the plugin and in the events of its streams.
  List<Object?> get encoded =>
      [details.userInfo.encode(), details.providerData];
}

/// An error as the platform answers a call with it.
final class _Failure implements Exception {
  const _Failure(this.code, [this.message]);

  final String code;
  final String? message;
}

/// The platform side of Firebase Authentication in memory; see
/// [mockFirebaseAuth].
final class MockFirebaseAuth {
  MockFirebaseAuth._();

  final Map<String, _User> _accounts = {};
  final Map<String, _Failure> _failures = {};
  _User? _current;
  int _created = 0;

  /// Whether the user signed in since the app started, which Firebase asks
  /// for before it deletes a user.
  bool _signedInRecently = false;

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

  /// Puts the user [uid] on the device, with the account of [email] or as
  /// an anonymous user, as a start of the app finds a user who signed in
  /// when the app last ran: the plugin gets that user when Firebase is
  /// initialized, so call it before that. The user did not sign in since
  /// the app started.
  void restoreUser(String uid, {String? email, String? password}) {
    final user = _User(uid)
      ..email = email
      ..password = password;
    if (email != null) _accounts[email] = user;
    _current = user;
    _signedInRecently = false;
    firebasePluginConstants[_plugin] = {'APP_CURRENT_USER': user.encoded};
  }

  /// Signs the user out on the platform side and tells the plugin, as the
  /// Firebase SDK does by itself, such as when it finds that the session of
  /// the user has ended on the server.
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
        try {
          if (_failures.remove(method) case final failure?) throw failure;
          return codec.encodeMessage(<Object?>[handle(arguments)]);
        } on _Failure catch (failure) {
          return codec.encodeMessage(
            <Object?>[failure.code, failure.message, null],
          );
        }
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
      if (current == null || current.email != null) _signIn(_newUser());
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
    // It sends no message, whether the address has an account or not.
    answer('FirebaseAuthHostApi', 'sendPasswordResetEmail', (_) => null);
    answer(
      'FirebaseAuthHostApi',
      'setLanguageCode',
      (arguments) => arguments[0] ?? '',
    );
    answer('FirebaseAuthHostApi', 'signOut', (_) => _current = null);
    answer('FirebaseAuthUserHostApi', 'linkWithCredential', (arguments) {
      final user = _signedIn();
      final {'email': email as String, 'secret': password as String} =
          arguments[0]! as Map<Object?, Object?>;
      if (user.email != null) {
        throw const _Failure(
          'PROVIDER_ALREADY_LINKED',
          'User has already been linked to the given provider.',
        );
      }
      _checkFree(email);
      // The user keeps the id.
      _account(user, email, password);
      return _credential;
    });
    answer('FirebaseAuthUserHostApi', 'delete', (_) {
      final user = _signedIn();
      if (user.email != null && !_signedInRecently) {
        throw const _Failure(
          'ERROR_REQUIRES_RECENT_LOGIN',
          'This operation is sensitive and requires recent authentication. '
              'Log in again before retrying this request.',
        );
      }
      _accounts.remove(user.email);
      // It tells the plugin nothing: see the top of the file.
      _current = null;
      return null;
    });
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

  void _signIn(_User user) {
    _current = user;
    _signedInRecently = true;
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
