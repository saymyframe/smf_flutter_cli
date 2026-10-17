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
/// the module and the files of the auth role use, with the signatures of
/// Flutter 3.44. The app runs in debug mode, and a script sets the platform
/// that it runs on, which Flutter has as a getter.
const _foundation = '''
const bool kDebugMode = true;

void debugPrint(String? message, {int? wrapWidth}) {}

class Immutable {
  const Immutable();
}

const Immutable immutable = Immutable();

typedef VoidCallback = void Function();

abstract class Listenable {
  const Listenable();

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);
}

abstract class ValueListenable<T> extends Listenable {
  const ValueListenable();

  T get value;
}

mixin class ChangeNotifier implements Listenable {
  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  bool get hasListeners => _listeners.isNotEmpty;

  void notifyListeners() {
    for (final listener in [..._listeners]) {
      listener();
    }
  }

  void dispose() => _listeners.clear();
}

class ErrorDescription {
  ErrorDescription(this.message);

  final String message;
}

class FlutterErrorDetails {
  const FlutterErrorDetails({
    required this.exception,
    this.stack,
    this.library = 'Flutter framework',
    this.context,
  });

  final Object exception;
  final StackTrace? stack;
  final String? library;
  final ErrorDescription? context;
}

class FlutterError {
  static void reportError(FlutterErrorDetails details) {}
}

enum TargetPlatform { android, fuchsia, iOS, linux, macOS, windows }

TargetPlatform defaultTargetPlatform = TargetPlatform.android;
''';

/// A stand-in for the part of Flutter's widgets library that the file of
/// the module and the files of the auth role use: what that library exports
/// of the foundation library, the binding with the observers of the
/// lifecycle of the app, and the widgets that the icon of the way to sign
/// in builds on.
const _widgets = '''
export 'foundation.dart'
    show
        ChangeNotifier,
        ErrorDescription,
        FlutterError,
        FlutterErrorDetails,
        TargetPlatform,
        VoidCallback,
        debugPrint,
        immutable;

enum AppLifecycleState { detached, resumed, inactive, hidden, paused }

class Key {
  const Key();
}

abstract class Widget {
  const Widget({this.key});

  final Key? key;
}

abstract class BuildContext {}

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});

  Widget build(BuildContext context);
}

abstract mixin class WidgetsBindingObserver {
  void didChangeAppLifecycleState(AppLifecycleState state) {}
}

class WidgetsBinding {
  static final WidgetsBinding instance = WidgetsBinding();

  final List<WidgetsBindingObserver> observers = [];

  void addObserver(WidgetsBindingObserver observer) => observers.add(observer);

  bool removeObserver(WidgetsBindingObserver observer) =>
      observers.remove(observer);
}
''';

/// A stand-in for the part of Flutter's material library that the icon of
/// the way to sign in uses: the widgets library, and an icon of the
/// Material icons. Its code point is that of Flutter 3.44.
const _material = '''
import 'widgets.dart';

export 'widgets.dart';

class IconData {
  const IconData(this.codePoint);

  final int codePoint;
}

abstract final class Icons {
  static const IconData apple = IconData(0xf04be);
}

class Icon extends StatelessWidget {
  const Icon(this.icon, {super.key});

  final IconData? icon;

  @override
  Widget build(BuildContext context) => this;
}
''';

/// A stand-in for the part of sign_in_with_apple that the module uses,
/// with the signatures of sign_in_with_apple 8.2: a request for a
/// credential of an Apple ID, and what it fails with. `generateNonce` gives
/// a new nonce each time, as the package does.
///
/// A script scripts and reads it through the top-level names:
/// `appleAnswers`, what the platform answers the next requests with in
/// turn, a credential or an error that the request throws, and
/// `appleRequests`, each request that reached the platform, with its
/// scopes and its nonce.
const _signInWithApple = r'''
/// What the platform answers the next requests with, in turn: an
/// [AuthorizationCredentialAppleID], or an error that the request throws.
final List<Object> appleAnswers = [];

/// The requests that reached the platform, each with its scopes and its
/// nonce.
final List<({List<AppleIDAuthorizationScopes> scopes, String? nonce})>
    appleRequests = [];

var _nonces = 0;

String generateNonce({int length = 32}) =>
    'raw-nonce-${++_nonces}'.padRight(length, '0');

enum AppleIDAuthorizationScopes { email, fullName }

enum AuthorizationErrorCode {
  canceled,
  failed,
  invalidResponse,
  notHandled,
  notInteractive,
  unknown,
  credentialExport,
  credentialImport,
  matchedExcludedCredential,
}

class WebAuthenticationOptions {
  WebAuthenticationOptions({required this.clientId, required this.redirectUri});

  final String clientId;
  final Uri redirectUri;
}

class AuthorizationCredentialAppleID {
  const AuthorizationCredentialAppleID({
    required this.userIdentifier,
    required this.givenName,
    required this.familyName,
    required this.authorizationCode,
    required this.email,
    required this.identityToken,
    required this.state,
  });

  final String? userIdentifier;
  final String? givenName;
  final String? familyName;
  final String? email;
  final String authorizationCode;
  final String? identityToken;
  final String? state;
}

abstract class SignInWithAppleException implements Exception {}

class SignInWithAppleAuthorizationException
    implements SignInWithAppleException {
  const SignInWithAppleAuthorizationException({
    required this.code,
    required this.message,
  });

  final AuthorizationErrorCode code;
  final String message;

  @override
  String toString() => 'SignInWithAppleAuthorizationException($code, $message)';
}

class SignInWithAppleNotSupportedException implements SignInWithAppleException {
  const SignInWithAppleNotSupportedException({required this.message});

  final String message;

  @override
  String toString() => 'SignInWithAppleNotSupportedException($message)';
}

class SignInWithApple {
  static Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    WebAuthenticationOptions? webAuthenticationOptions,
    String? nonce,
    String? state,
  }) async {
    await null;
    appleRequests.add((scopes: scopes, nonce: nonce));
    final answer = appleAnswers.removeAt(0);
    if (answer is AuthorizationCredentialAppleID) return answer;
    throw answer;
  }
}
''';

/// The Dart files in `lib/` of a rendered app, written to a temporary
/// directory with stand-ins for the libraries of Flutter and of
/// sign_in_with_apple that the code of the module and of the auth role
/// uses, so that it can be analyzed and run with the Dart SDK alone: the
/// tests of the package run without the Flutter SDK, which
/// sign_in_with_apple needs. The code takes the hash of a nonce with the
/// real crypto package, which the tests of this package resolve.
///
/// The other files of the app need more of Flutter, so the analyzer checks
/// the files of the owners it is given, and a script that runs the app
/// imports none of the others. The real package runs in the tests of the
/// generated apps. [delete] removes the directory.
final class DartApp {
  DartApp._(this._root, this._files);

  /// Writes the Dart files in `lib/` of [app].
  static Future<DartApp> write(RenderedApp app) async {
    final root = Directory.systemTemp.createTempSync('smf_apple_sign_in_');
    final files = [
      for (final file in app.files.values)
        if (file.path.startsWith('lib/') && file.path.endsWith('.dart')) file,
    ];
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    for (final file in files) {
      write('app/${file.path}', file.text);
    }
    write('flutter/lib/foundation.dart', _foundation);
    write('flutter/lib/widgets.dart', _widgets);
    write('flutter/lib/material.dart', _material);
    write(
      'sign_in_with_apple/lib/sign_in_with_apple.dart',
      _signInWithApple,
    );
    write('app/pubspec.yaml', 'name: contract_app\n');
    // The stand-ins are in the language of the app too.
    final languageVersion = _languageVersionOf(app);
    write(
      'app/.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          ...await _resolvedPackages(),
          for (final (name, rootUri) in [
            ('contract_app', '../'),
            ('flutter', '../../flutter/'),
            ('sign_in_with_apple', '../../sign_in_with_apple/'),
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

  String get _appPath =>
      Directory('${_root.path}/app').resolveSymbolicLinksSync();

  /// The packages that the tests of this package resolve, as the entries of
  /// a package config, each with the root of its package as an absolute
  /// URI: `crypto` is among them.
  static Future<List<Map<String, Object?>>> _resolvedPackages() async {
    final config = (await Isolate.packageConfig)!;
    final packages = (jsonDecode(File.fromUri(config).readAsStringSync())
        as Map<String, Object?>)['packages']! as List<Object?>;
    return [
      for (final package in packages.cast<Map<String, Object?>>())
        {
          ...package,
          'rootUri': '${config.resolve(package['rootUri']! as String)}',
        },
    ];
  }

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
  /// own, and returns the first message it sends.
  ///
  /// Throws a [StateError] with the error if the isolate fails, or if it
  /// sends nothing in time.
  Future<Object?> run(String script) async {
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
        const [],
        messages.sendPort,
        onError: errors.sendPort,
        onExit: exits.sendPort,
        packageConfig: Uri.file('$_appPath/.dart_tool/package_config.json'),
      );
      return await result.future.timeout(
        const Duration(seconds: 60),
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
