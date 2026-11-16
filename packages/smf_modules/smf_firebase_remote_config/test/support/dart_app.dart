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

/// A stand-in for the part of firebase_core that the tests use, with the
/// signatures of firebase_core 4: what the plugins of Firebase throw.
const _firebaseCore = r'''
class FirebaseException implements Exception {
  FirebaseException({required this.plugin, this.message, String? code})
      : code = code ?? 'unknown';

  final String plugin;
  final String code;
  final String? message;

  @override
  String toString() => '[$plugin/$code] $message';
}
''';

/// A stand-in for the part of firebase_remote_config that the module uses,
/// with the signatures of firebase_remote_config 6.7 and what its plugin
/// does where the service relies on it:
/// - `getAll()` has the active values with the source `valueRemote` and the
///   defaults that the app set with the source `valueDefault`, as the
///   platform gives them to the plugin;
/// - a fetch keeps what the project has until an activation makes it active,
///   and an activation answers whether it changed the active values;
/// - `onConfigUpdated` is a broadcast stream of the plugin, the same for
///   every service, which tells of each real-time update once the platform
///   fetched what the project published.
///
/// A test scripts and reads it through the top-level names: `project`, what
/// the Firebase project has, which a fetch gets; `failNext`, the error that
/// the next call of a method fails with; `firebaseCalls`, each call that
/// reached the platform; and `platformUpdates()`, a real-time update.
const _firebaseRemoteConfig = r'''
import 'dart:async';

/// What the Firebase project has, by parameter, which a fetch gets.
Map<String, String> project = {};

/// The error that the next call of a method fails with, by the method.
final Map<String, Object> failNext = {};

/// The calls that reached the platform, each with its arguments.
final List<String> firebaseCalls = [];

Map<String, String>? _fetched;
Map<String, String> _active = {};
Map<String, dynamic> _defaults = {};

final StreamController<RemoteConfigUpdate> _updates =
    StreamController.broadcast(
  onListen: () => firebaseCalls.add('listen to updates'),
  onCancel: () => firebaseCalls.add('cancel updates'),
);

/// The platform fetched what the project published while the app runs, and
/// tells of the parameters that changed, as Firebase does in real time.
void platformUpdates(Set<String> parameters) {
  _fetched = {...project};
  _updates.add(RemoteConfigUpdate(parameters));
}

void _called(String method, [List<Object?> arguments = const []]) {
  firebaseCalls.add('$method(${arguments.join(', ')})');
  final failure = failNext.remove(method);
  if (failure != null) throw failure;
}

enum ValueSource { valueStatic, valueDefault, valueRemote }

class RemoteConfigValue {
  RemoteConfigValue(this._text, this.source);

  final String? _text;
  final ValueSource source;

  String asString() => _text ?? '';
}

class RemoteConfigSettings {
  RemoteConfigSettings({
    required this.fetchTimeout,
    required this.minimumFetchInterval,
  });

  Duration fetchTimeout;
  Duration minimumFetchInterval;
}

class RemoteConfigUpdate {
  RemoteConfigUpdate(this.updatedKeys);

  final Set<String> updatedKeys;
}

class FirebaseRemoteConfig {
  FirebaseRemoteConfig._();

  static final FirebaseRemoteConfig instance = FirebaseRemoteConfig._();

  Future<void> ensureInitialized() async {
    await null;
    _called('ensureInitialized');
  }

  Future<void> setConfigSettings(
    RemoteConfigSettings remoteConfigSettings,
  ) async {
    await null;
    _called('setConfigSettings', [
      'fetch timeout ${remoteConfigSettings.fetchTimeout}',
      'minimum fetch interval ${remoteConfigSettings.minimumFetchInterval}',
    ]);
  }

  Future<void> setDefaults(Map<String, dynamic> defaultParameters) async {
    await null;
    _called('setDefaults', [
      for (final MapEntry(:key, :value) in defaultParameters.entries)
        '$key: $value (${value.runtimeType})',
    ]);
    _defaults = {...defaultParameters};
  }

  Future<void> fetch() async {
    await null;
    _called('fetch');
    _fetched = {...project};
  }

  Future<bool> activate() async {
    await null;
    _called('activate');
    final fetched = _fetched;
    _fetched = null;
    if (fetched == null) return false;
    final changed = fetched.length != _active.length ||
        fetched.entries.any((entry) => _active[entry.key] != entry.value);
    _active = fetched;
    return changed;
  }

  Map<String, RemoteConfigValue> getAll() => {
        for (final MapEntry(:key, :value) in _defaults.entries)
          key: RemoteConfigValue('$value', ValueSource.valueDefault),
        for (final MapEntry(:key, :value) in _active.entries)
          key: RemoteConfigValue(value, ValueSource.valueRemote),
      };

  Stream<RemoteConfigUpdate> get onConfigUpdated => _updates.stream;
}
''';

/// The Dart files in `lib/` of a rendered app, written to a temporary
/// directory with stand-ins for the libraries of firebase_core and of
/// firebase_remote_config that the code of the module and its tests use, so
/// that it can be analyzed and run with the Dart SDK alone: the tests of the
/// package run without the Flutter SDK, which firebase_remote_config needs.
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
      'smf_firebase_remote_config_',
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
    write('firebase_core/lib/firebase_core.dart', _firebaseCore);
    write(
      'firebase_remote_config/lib/firebase_remote_config.dart',
      _firebaseRemoteConfig,
    );
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
            ('firebase_core', '../../firebase_core/'),
            ('firebase_remote_config', '../../firebase_remote_config/'),
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
