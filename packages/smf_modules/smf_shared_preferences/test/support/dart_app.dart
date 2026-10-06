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
/// the preferences role uses, with the signatures of Flutter 3.44: the app
/// runs in debug mode, and prints nothing.
const _foundation = '''
const bool kDebugMode = true;

void debugPrint(String? message, {int? wrapWidth}) {}
''';

/// A stand-in for the part of shared_preferences that the module uses, with
/// the signatures of shared_preferences 2.5 and what its
/// `SharedPreferencesWithCache` does with the values: `create()` reads what
/// the platform has into a cache, the reads answer from the cache and cast
/// the value to their type, so that a value of another type throws, and the
/// writes keep the value in the cache, the list that they are given
/// included, and give it to the platform.
///
/// The platform is `platformPreferences`, a map in memory, as the one that
/// the package has for tests. The cache takes its values as they are, so a
/// test can put a list there in the form that a platform returns it in.
/// The platform refuses to save under the keys of `refusedKeys`, as a
/// platform refuses some values: the write has put its value into the cache
/// by then, as that of the package has.
const _sharedPreferences = '''
/// What the platform has saved, as the tests read it.
final Map<String, Object> platformPreferences = {};

/// The keys that the platform refuses to save under.
final Set<String> refusedKeys = {};

/// How many times the preferences were created.
int created = 0;

class SharedPreferencesOptions {
  const SharedPreferencesOptions();
}

class SharedPreferencesWithCacheOptions {
  const SharedPreferencesWithCacheOptions({this.allowList});

  final Set<String>? allowList;
}

class SharedPreferencesWithCache {
  SharedPreferencesWithCache._();

  static Future<SharedPreferencesWithCache> create({
    SharedPreferencesOptions sharedPreferencesOptions =
        const SharedPreferencesOptions(),
    required SharedPreferencesWithCacheOptions cacheOptions,
    Map<String, Object?>? cache,
  }) async {
    final preferences = SharedPreferencesWithCache._();
    await preferences.reloadCache();
    created++;
    return preferences;
  }

  final Map<String, Object?> _cache = {};

  Future<void> reloadCache() async {
    await Future<void>.delayed(Duration.zero);
    _cache
      ..clear()
      ..addAll(Map<String, Object>.from(platformPreferences));
  }

  Object? get(String key) => _cache[key];

  bool? getBool(String key) => get(key) as bool?;

  int? getInt(String key) => get(key) as int?;

  double? getDouble(String key) => get(key) as double?;

  String? getString(String key) => get(key) as String?;

  List<String>? getStringList(String key) =>
      (_cache[key] as List<Object?>?)?.cast<String>().toList();

  Future<void> setBool(String key, bool value) => _set(key, value);

  Future<void> setInt(String key, int value) => _set(key, value);

  Future<void> setDouble(String key, double value) => _set(key, value);

  Future<void> setString(String key, String value) => _set(key, value);

  Future<void> setStringList(String key, List<String> value) =>
      _set(key, value);

  Future<void> remove(String key) async {
    _cache.remove(key);
    await Future<void>.delayed(Duration.zero);
    platformPreferences.remove(key);
  }

  Future<void> _set(String key, Object value) async {
    _cache[key] = value;
    await Future<void>.delayed(Duration.zero);
    if (refusedKeys.contains(key)) {
      throw StateError('The platform refused to save under ' + key + '.');
    }
    platformPreferences[key] = value;
  }
}
''';

/// The Dart files in `lib/` of a rendered app, written to a temporary
/// directory with stand-ins for the libraries of Flutter and of
/// shared_preferences that the code of the preferences uses, so that it can
/// be analyzed and run with the Dart SDK alone: the tests of the package
/// run without the Flutter SDK, which shared_preferences needs.
///
/// The other files of the app may need more of Flutter, so the analyzer
/// checks the files of the owners it is given, and a script that runs the
/// app imports none of the others. The real package runs in the tests of
/// the generated apps. [delete] removes the directory.
final class DartApp {
  DartApp._(this._root, this._files);

  /// Writes the Dart files in `lib/` of [app].
  factory DartApp.write(RenderedApp app) {
    final root = Directory.systemTemp.createTempSync('smf_preferences_');
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
    write(
      'shared_preferences/lib/shared_preferences.dart',
      _sharedPreferences,
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
            ('flutter', '../../flutter/'),
            ('shared_preferences', '../../shared_preferences/'),
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
