import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:yaml/yaml.dart';

/// A stand-in for the part of Flutter's foundation library that the file of
/// the module and the files of the roles that it imports use, with the
/// signatures of Flutter 3.44. The app runs in debug mode and prints
/// nothing, and a test sets the platform that it runs on, which Flutter
/// has as a getter.
const _foundation = '''
const bool kDebugMode = true;

void debugPrint(String? message, {int? wrapWidth}) {}

typedef VoidCallback = void Function();

enum TargetPlatform { android, fuchsia, iOS, linux, macOS, windows }

TargetPlatform defaultTargetPlatform = TargetPlatform.android;

abstract class Listenable {
  const Listenable();

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);
}

class ChangeNotifier implements Listenable {
  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  void dispose() => _listeners.clear();
}
''';

/// A stand-in for the part of Flutter's widgets library that the file of
/// the module uses in an app with the localization role, and that the file
/// of that role with the languages of the app uses, with the signatures of
/// Flutter 3.44. `basicLocaleListResolution` returns the first locale of
/// the app with the language of a locale that the device prefers, and the
/// first locale of the app when the device prefers none of its languages,
/// as that of Flutter does for locales that are a language alone. A test
/// sets the locales of the device.
const _widgets = '''
import 'foundation.dart';

export 'foundation.dart' show ChangeNotifier, Listenable, VoidCallback;

class Locale {
  const Locale(this.languageCode, [this.countryCode]);

  final String languageCode;
  final String? countryCode;

  @override
  bool operator ==(Object other) =>
      other is Locale &&
      other.languageCode == languageCode &&
      other.countryCode == countryCode;

  @override
  int get hashCode => Object.hash(languageCode, countryCode);
}

class Key {
  const Key();
}

abstract class Widget {
  const Widget({this.key});

  final Key? key;
}

abstract class InheritedWidget extends Widget {
  const InheritedWidget({required this.child, super.key});

  final Widget child;
}

abstract class InheritedNotifier<T extends Listenable>
    extends InheritedWidget {
  const InheritedNotifier({required super.child, this.notifier, super.key});

  final T? notifier;
}

abstract class BuildContext {
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>({
    Object? aspect,
  });
}

class PlatformDispatcher {
  List<Locale> locales = const [Locale('en', 'US')];
}

class WidgetsBinding {
  WidgetsBinding._();

  static final WidgetsBinding instance = WidgetsBinding._();

  final PlatformDispatcher platformDispatcher = PlatformDispatcher();
}

Locale basicLocaleListResolution(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  for (final preferred in preferredLocales ?? const <Locale>[]) {
    for (final supported in supportedLocales) {
      if (supported.languageCode == preferred.languageCode) return supported;
    }
  }
  return supportedLocales.first;
}
''';

/// A stand-in for the part of firebase_auth that the module uses, with the
/// signatures of firebase_auth 6.7 and what its plugin does where the
/// service relies on it or works around it:
/// - a call that signs in sets the current user before it completes, and a
///   sign-out clears it;
/// - `User.delete()` leaves the user as the current one, which the plugin
///   clears only when the platform tells it of the sign-out;
/// - `userChanges()` returns a new stream each time, which first has the
///   current user and then what the platform tells of;
/// - an anonymous user whom Android kept on the device has an empty text
///   for its address, not none;
/// - `revokeTokenWithAuthorizationCode()` throws an `UnimplementedError`
///   on a platform other than iOS and macOS, and its future never completes
///   while nobody is signed in, as that of the Firebase SDK.
///
/// A credential of Google or Apple signs in to the user `uid of <the ID
/// token>`, whom a link gives the identity too, with the id of the
/// provider of the credential in `providerData`. A credential that the
/// plugin keeps on the platform, which a failure of Firebase may carry,
/// has its number as its `token`.
///
/// A test scripts and reads it through the top-level names: `failNext`,
/// the error that the next call of a method fails with; `onNext`, what the
/// platform does when the next call of a method reaches it, before it
/// answers; `firebaseCalls`, each call that reached it, with its
/// arguments; `userChangesListeners`, how many of its streams of the user
/// have a listener; `platformSignsOut()` and `platformFails()`, what the
/// platform tells of without a call; and `restoreAnonymousUserOfAndroid()`,
/// the user that a start of the app on Android finds.
const _firebaseAuth = r'''
import 'dart:async';

import 'package:flutter/foundation.dart';

/// The error that the next call of a method fails with, by the method.
final Map<String, Object> failNext = {};

/// What the platform does when the next call of a method reaches it, by the
/// method.
final Map<String, void Function()> onNext = {};

/// The calls that reached Firebase, each with its arguments.
final List<String> firebaseCalls = [];

/// How many streams of `userChanges()` have a listener.
int userChangesListeners = 0;

final StreamController<User?> _platform = StreamController.broadcast();

/// The platform signs the user out without a call, and tells of it.
void platformSignsOut() {
  FirebaseAuth.instance._current = null;
  _platform.add(null);
}

/// The stream of the platform sends [error].
void platformFails(Object error) => _platform.addError(error);

/// Puts the anonymous user [uid] on the device as Android hands such a user
/// over when the app starts: with an empty text for the address.
void restoreAnonymousUserOfAndroid(String uid) =>
    FirebaseAuth.instance._current = User._(uid, email: '', isAnonymous: true);

void _called(String method, [List<Object?> arguments = const []]) {
  firebaseCalls.add('$method(${arguments.join(', ')})');
  onNext.remove(method)?.call();
  final failure = failNext.remove(method);
  if (failure != null) throw failure;
}

class FirebaseAuthException implements Exception {
  FirebaseAuthException({required this.code, this.message, this.credential});

  final String code;
  final String? message;
  final AuthCredential? credential;

  @override
  String toString() => '[firebase_auth/$code] $message';
}

class FirebaseOptions {
  const FirebaseOptions({required this.projectId});

  final String projectId;
}

class FirebaseApp {
  const FirebaseApp(this.options);

  final FirebaseOptions options;
}

class AuthCredential {
  const AuthCredential({
    required this.providerId,
    required this.signInMethod,
    this.token,
    this.accessToken,
  });

  final String providerId;
  final String signInMethod;
  final int? token;
  final String? accessToken;

  @override
  String toString() => '$providerId credential $token';
}

class EmailAuthCredential extends AuthCredential {
  const EmailAuthCredential._(this.email, this.password)
      : super(providerId: 'password', signInMethod: 'password');

  final String email;
  final String password;

  @override
  String toString() => 'password of $email: $password';
}

class OAuthCredential extends AuthCredential {
  const OAuthCredential._({
    required super.providerId,
    this.idToken,
    this.rawNonce,
    this.appleFullPersonName,
  }) : super(signInMethod: providerId);

  final String? idToken;
  final String? rawNonce;
  final AppleFullPersonName? appleFullPersonName;

  @override
  String toString() => [
        '$providerId of $idToken',
        if (rawNonce != null) 'nonce $rawNonce',
        if (appleFullPersonName case final name?)
          'name ${name.givenName} ${name.familyName}',
      ].join(', ');
}

abstract class EmailAuthProvider {
  static AuthCredential credential({
    required String email,
    required String password,
  }) =>
      EmailAuthCredential._(email, password);
}

abstract class GoogleAuthProvider {
  static OAuthCredential credential({String? idToken, String? accessToken}) =>
      OAuthCredential._(providerId: 'google.com', idToken: idToken);
}

class AppleFullPersonName {
  AppleFullPersonName({
    this.givenName,
    this.familyName,
    this.middleName,
    this.nickname,
    this.namePrefix,
    this.nameSuffix,
  });

  final String? givenName;
  final String? familyName;
  final String? middleName;
  final String? nickname;
  final String? namePrefix;
  final String? nameSuffix;
}

abstract class AppleAuthProvider {
  static OAuthCredential credentialWithIDToken(
    String idToken,
    String rawNonce,
    AppleFullPersonName appleFullPersonName,
  ) =>
      OAuthCredential._(
        providerId: 'apple.com',
        idToken: idToken,
        rawNonce: rawNonce,
        appleFullPersonName: appleFullPersonName,
      );
}

class ActionCodeSettings {}

class UserInfo {
  UserInfo._(this.providerId);

  final String providerId;
}

class UserCredential {
  UserCredential._(this.user);

  final User? user;
}

class User {
  User._(
    this.uid, {
    this.email,
    bool? isAnonymous,
    this.providers = const [],
  }) : isAnonymous = isAnonymous ?? (email == null && providers.isEmpty);

  final String uid;
  final String? email;
  final bool isAnonymous;
  final List<String> providers;

  List<UserInfo> get providerData => [
        if (email != null && !isAnonymous) UserInfo._('password'),
        for (final provider in providers) UserInfo._(provider),
      ];

  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    await null;
    _called('linkWithCredential', [credential]);
    return FirebaseAuth.instance._signIn(switch (credential) {
      EmailAuthCredential(:final email) =>
        User._(uid, email: email, providers: providers),
      _ => User._(
          uid,
          email: email,
          providers: [...providers, credential.providerId],
        ),
    });
  }

  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    await null;
    _called('reauthenticateWithCredential', [credential]);
    return UserCredential._(this);
  }

  /// The plugin keeps the user as its current one.
  Future<void> delete() async {
    await null;
    _called('delete');
  }
}

class FirebaseAuth {
  FirebaseAuth._();

  static final FirebaseAuth instance = FirebaseAuth._();

  FirebaseApp app = const FirebaseApp(
    FirebaseOptions(projectId: 'stand-in-project'),
  );

  User? _current;
  int _anonymous = 0;

  User? get currentUser => _current;

  UserCredential _signIn(User user) {
    _current = user;
    return UserCredential._(user);
  }

  Stream<User?> userChanges() {
    late final StreamController<User?> controller;
    StreamSubscription<User?>? events;
    controller = StreamController<User?>(
      onListen: () {
        userChangesListeners++;
        controller.add(currentUser);
        events = _platform.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () {
        userChangesListeners--;
        return events?.cancel();
      },
    );
    return controller.stream;
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await null;
    _called('signInWithEmailAndPassword', [email, password]);
    return _signIn(User._('uid of $email', email: email));
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await null;
    _called('createUserWithEmailAndPassword', [email, password]);
    return _signIn(User._('uid of $email', email: email));
  }

  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    await null;
    _called('signInWithCredential', [credential]);
    final idToken = credential is OAuthCredential ? credential.idToken : null;
    return _signIn(
      User._(
        'uid of ${idToken ?? credential.token}',
        providers: [credential.providerId],
      ),
    );
  }

  Future<UserCredential> signInAnonymously() async {
    await null;
    _called('signInAnonymously');
    return _signIn(User._('guest ${++_anonymous}'));
  }

  Future<void> revokeTokenWithAuthorizationCode(String authorizationCode) {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      throw UnimplementedError(
        'revokeTokenWithAuthorizationCode() is only available on apple '
        'platforms.',
      );
    }
    return Future(() {
      _called('revokeTokenWithAuthorizationCode', [authorizationCode]);
      // The future of the Firebase SDK never completes without a user.
      if (_current == null) return Completer<void>().future;
    });
  }

  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    await null;
    _called('sendPasswordResetEmail', [email]);
  }

  Future<void> setLanguageCode(String? languageCode) async {
    await null;
    _called('setLanguageCode', [languageCode]);
  }

  Future<void> signOut() async {
    await null;
    _called('signOut');
    _current = null;
  }
}
''';

/// The Dart files in `lib/` and `tool/` of a rendered app, written to a
/// temporary directory with stand-ins for the libraries of Flutter and of
/// firebase_auth that the code of the module uses, so that it can be
/// analyzed and run with the Dart SDK alone: the tests of the package run
/// without the Flutter SDK, which firebase_auth needs.
///
/// The other files of the app need more of Flutter, so the analyzer checks
/// the files of the owners it is given, and a script that runs the app
/// imports none of the others. The real package runs in the tests of the
/// generated apps. [delete] removes the directory.
final class DartApp {
  DartApp._(this._root, this._files);

  /// Writes the Dart files in `lib/` and `tool/` of [app].
  factory DartApp.write(RenderedApp app) {
    final root = Directory.systemTemp.createTempSync('smf_firebase_auth_');
    final files = [
      for (final file in app.files.values)
        if ((file.path.startsWith('lib/') || file.path.startsWith('tool/')) &&
            file.path.endsWith('.dart'))
          file,
    ];
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    for (final file in files) {
      write('app/${file.path}', file.text);
    }
    write('flutter/lib/foundation.dart', _foundation);
    write('flutter/lib/widgets.dart', _widgets);
    write('firebase_auth/lib/firebase_auth.dart', _firebaseAuth);
    write('app/pubspec.yaml', 'name: contract_app\n');
    // The stand-ins are in the language of the app too.
    final languageVersion = _languageVersionOf(app);
    write(
      'app/.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final (name, rootUri) in [
            ('contract_app', '../'),
            ('flutter', '../../flutter/'),
            ('firebase_auth', '../../firebase_auth/'),
          ])
            {
              'name': name,
              'rootUri': rootUri,
              'packageUri': 'lib/',
              'languageVersion': languageVersion,
            },
        ],
      }),
    );
    return DartApp._(root, files);
  }

  final Directory _root;
  final List<RenderedFile> _files;

  /// The directory of the app, with links resolved, as a process that runs
  /// in it sees it.
  String get path => _appPath;

  String get _appPath =>
      Directory('${_root.path}/app').resolveSymbolicLinksSync();

  /// The errors and warnings that the analyzer finds in the files of
  /// [owners], each with the path of its file.
  Future<List<String>> analysisProblems(Set<ContributionOrigin> owners) async {
    final appPath = _appPath;
    final collection = AnalysisContextCollection(includedPaths: [appPath]);
    try {
      final problems = <String>[];
      for (final file in _files) {
        if (!owners.contains(file.owner)) continue;
        // The analyzer takes only the paths of the system, such as
        // C:\app\lib\main.dart on Windows.
        final path = Uri.directory(appPath).resolve(file.path).toFilePath();
        final result = await collection
            .contextFor(path)
            .currentSession
            .getResolvedUnit(path);
        if (result is! ResolvedUnitResult) {
          problems.add('${file.path}: cannot be resolved: $result');
          continue;
        }
        for (final diagnostic in result.diagnostics) {
          if (diagnostic.severity == Severity.info) continue;
          problems.add(
            '${file.path}:${result.lineInfo.getLocation(diagnostic.offset)}: '
            '${diagnostic.message}',
          );
        }
      }
      return problems;
    } finally {
      await collection.dispose();
    }
  }

  /// Runs [script], a Dart library whose `main(List<String>, SendPort)`
  /// imports the app by its package, `contract_app`, in an isolate of its
  /// own, with [arguments], and returns the first message it sends.
  ///
  /// Throws a [StateError] with the error if the isolate fails, or if it
  /// sends nothing in time.
  Future<Object?> run(
    String script, {
    List<String> arguments = const [],
  }) async {
    final file = File('${_root.path}/check.dart')..writeAsStringSync(script);
    final result = Completer<Object?>();
    void fail(String message) {
      if (!result.isCompleted) result.completeError(StateError(message));
    }

    final messages = ReceivePort()
      ..listen((message) {
        if (!result.isCompleted) result.complete(message);
      });
    final errors = ReceivePort()
      ..listen((error) => fail('The script failed: $error'));
    // The isolate sends its message before it ends, so an end that comes
    // first means that it sent none.
    final exits = ReceivePort()
      ..listen((_) => fail('The script ended without a message.'));
    Isolate? isolate;
    try {
      isolate = await Isolate.spawnUri(
        file.uri,
        arguments,
        messages.sendPort,
        onError: errors.sendPort,
        onExit: exits.sendPort,
        packageConfig: Uri.file('$_appPath/.dart_tool/package_config.json'),
      );
      return await result.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw StateError('The script sent nothing in time.'),
      );
    } finally {
      isolate?.kill(priority: Isolate.immediate);
      messages.close();
      errors.close();
      exits.close();
    }
  }

  /// Deletes the directory of the app.
  void delete() => _root.deleteSync(recursive: true);
}

/// The language version of [app]: that of the lower bound of the SDK
/// constraint of its pubspec, such as 3.12 for `^3.12.0`.
String _languageVersionOf(RenderedApp app) {
  final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;
  final sdk = (pubspec['environment'] as YamlMap)['sdk'] as String;
  final version = RegExp(r'(\d+)\.(\d+)').firstMatch(sdk)!;
  return '${version[1]}.${version[2]}';
}
