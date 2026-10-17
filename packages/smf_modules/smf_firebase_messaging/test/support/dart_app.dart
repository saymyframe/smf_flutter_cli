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
/// the module uses, with the signatures of Flutter 3.44. The app runs in
/// debug mode, and what it prints goes to `printed`. A test sets the
/// platform that the app runs on, which Flutter has as a getter.
const _foundation = r'''
const bool kDebugMode = true;

/// What the app printed, line by line.
final List<String> printed = [];

void debugPrint(String? message, {int? wrapWidth}) => printed.add('$message');

enum TargetPlatform { android, fuchsia, iOS, linux, macOS, windows }

TargetPlatform defaultTargetPlatform = TargetPlatform.android;
''';

/// A stand-in for the part of firebase_messaging that the module uses, with
/// the signatures of firebase_messaging 16.7 and what its plugin does where
/// the service relies on it or works around it:
/// - `getToken()` on iOS fails with the code `apns-token-not-set` while the
///   device has no token of the Apple Push Notification service, before it
///   asks the platform;
/// - `setForegroundNotificationPresentationOptions()` reaches the platform
///   only on iOS and macOS;
/// - the streams of the messages, the taps and the tokens are broadcast
///   streams of the plugin, the same for every instance.
///
/// A test scripts and reads it through the top-level names: `token` and
/// `apnsToken`, what the device has; `initialMessage`, the message whose
/// tap launched the app; `failNext`, the error that the next call of a
/// method fails with; `firebaseCalls`, each call that reached the platform;
/// and `platformDelivers()`, `platformOpens()` and `platformRefreshes()`,
/// what the platform tells of.
const _firebaseMessaging = r'''
import 'dart:async';

import 'package:flutter/foundation.dart';

/// The registration token of the device, or `null`.
String? token = 'token of the device';

/// The token of the Apple Push Notification service on iOS, or `null`.
String? apnsToken = 'APNs token';

/// The message whose tap launched the app, or `null`.
RemoteMessage? initialMessage;

/// The error that the next call of a method fails with, by the method.
final Map<String, Object> failNext = {};

/// The calls that reached the platform, each with its arguments.
final List<String> firebaseCalls = [];

final StreamController<String> _tokens = StreamController.broadcast();
final StreamController<RemoteMessage> _messages = StreamController.broadcast();
final StreamController<RemoteMessage> _openings = StreamController.broadcast();

/// The platform tells of a message that arrives in the foreground.
void platformDelivers(RemoteMessage message) => _messages.add(message);

/// The platform tells of a tap on a message that it showed.
void platformOpens(RemoteMessage message) => _openings.add(message);

/// The platform tells of a new token.
void platformRefreshes(String newToken) {
  token = newToken;
  _tokens.add(newToken);
}

void _called(String method, [List<Object?> arguments = const []]) {
  firebaseCalls.add('$method(${arguments.join(', ')})');
  final failure = failNext.remove(method);
  if (failure != null) throw failure;
}

/// What the plugin throws, a FirebaseException of firebase_core.
class FirebaseException implements Exception {
  FirebaseException({required this.code, this.message});

  final String code;
  final String? message;

  @override
  String toString() => '[firebase_messaging/$code] $message';
}

class RemoteNotification {
  const RemoteNotification({this.title, this.body});

  final String? title;
  final String? body;
}

class RemoteMessage {
  const RemoteMessage({
    this.messageId,
    this.data = const <String, dynamic>{},
    this.notification,
  });

  final String? messageId;
  final Map<String, dynamic> data;
  final RemoteNotification? notification;
}

class NotificationSettings {}

class FirebaseMessaging {
  FirebaseMessaging._();

  static final FirebaseMessaging instance = FirebaseMessaging._();

  static Stream<RemoteMessage> get onMessage => _messages.stream;

  static Stream<RemoteMessage> get onMessageOpenedApp => _openings.stream;

  Stream<String> get onTokenRefresh => _tokens.stream;

  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    await null;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _called('getAPNSToken');
      if (apnsToken == null) {
        throw FirebaseException(
          code: 'apns-token-not-set',
          message: 'APNS token has not been received on the device yet.',
        );
      }
    }
    _called('getToken');
    return token;
  }

  Future<RemoteMessage?> getInitialMessage() async {
    await null;
    _called('getInitialMessage');
    return initialMessage;
  }

  Future<void> setForegroundNotificationPresentationOptions({
    required bool alert,
    required bool badge,
    required bool sound,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }
    _called(
      'setForegroundNotificationPresentationOptions',
      ['alert $alert', 'badge $badge', 'sound $sound'],
    );
  }

  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  }) async {
    _called('requestPermission');
    return NotificationSettings();
  }
}
''';

/// The Dart files in `lib/` of a rendered app, written to a temporary
/// directory with stand-ins for the libraries of Flutter and of
/// firebase_messaging that the code of the module uses, so that it can be
/// analyzed and run with the Dart SDK alone: the tests of the package run
/// without the Flutter SDK, which firebase_messaging needs.
///
/// The other files of the app need more of Flutter, so the analyzer checks
/// the files of the owners it is given, and a script that runs the app
/// imports none of the others. The real package runs in the tests of the
/// generated apps. [delete] removes the directory.
final class DartApp {
  DartApp._(this._root, this._files);

  /// Writes the Dart files in `lib/` of [app].
  factory DartApp.write(RenderedApp app) {
    final root = Directory.systemTemp.createTempSync(
      'smf_firebase_messaging_',
    );
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
    write('firebase_messaging/lib/firebase_messaging.dart', _firebaseMessaging);
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
            ('firebase_messaging', '../../firebase_messaging/'),
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
