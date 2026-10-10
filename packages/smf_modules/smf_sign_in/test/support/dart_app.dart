import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:yaml/yaml.dart';

/// A stand-in for the part of Flutter's foundation library that the files
/// of the auth role and the state of the sign-in screens use, with the
/// signatures of Flutter 3.44: the app runs in debug mode, what it prints
/// goes to `debugPrinted`, and the errors that it reports go to
/// `reportedErrors`.
const _foundation = r'''
const bool kDebugMode = true;

/// What the app printed with [debugPrint], in order.
final List<String> debugPrinted = [];

void debugPrint(String? message, {int? wrapWidth}) =>
    debugPrinted.add('$message');

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

/// The errors that the app reported with [FlutterError.reportError].
final List<FlutterErrorDetails> reportedErrors = [];

class FlutterError {
  static void reportError(FlutterErrorDetails details) =>
      reportedErrors.add(details);
}
''';

/// A stand-in for the part of Flutter's widgets library that the files of
/// the auth role use: what that library exports of the foundation library,
/// and the binding with the observers of the lifecycle of the app.
const _widgets = '''
export 'foundation.dart'
    show
        ChangeNotifier,
        ErrorDescription,
        FlutterError,
        FlutterErrorDetails,
        VoidCallback,
        debugPrint,
        immutable;

enum AppLifecycleState { detached, resumed, inactive, hidden, paused }

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

/// The packages of the state managers as the files of a variant import
/// them, each a stand-in that exports the package it builds on, which is
/// plain Dart: what a cubit or a provider of the screens uses is all there,
/// and what a widget uses is not.
const _stateManagers = {
  'flutter_bloc': "export 'package:bloc/bloc.dart';\n",
  'flutter_riverpod': "export 'package:riverpod/riverpod.dart';\n",
};

/// The Dart files in `lib/` of a rendered app, written to a temporary
/// directory with stand-ins for the libraries of Flutter and of the state
/// managers that the state of the sign-in screens uses, so that it can be
/// analyzed and run with the Dart SDK alone: the tests of the package run
/// without the Flutter SDK.
///
/// The packages that the stand-ins of the state managers export are those
/// that the tests of this package resolve, `bloc` and `riverpod`, with the
/// packages that they depend on.
///
/// The widgets of the app need more of Flutter, so the analyzer checks the
/// files it is given, and a script that runs the app imports none of the
/// others: the screens run in the tests of the generated apps. [delete]
/// removes the directory.
final class DartApp {
  DartApp._(this._root);

  /// Writes the Dart files in `lib/` of [app].
  static Future<DartApp> write(RenderedApp app) async {
    final root = Directory.systemTemp.createTempSync('smf_sign_in_');
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    for (final file in app.files.values) {
      if (file.path.startsWith('lib/') && file.path.endsWith('.dart')) {
        write('app/${file.path}', file.text);
      }
    }
    write('flutter/lib/foundation.dart', _foundation);
    write('flutter/lib/widgets.dart', _widgets);
    for (final MapEntry(key: package, value: library)
        in _stateManagers.entries) {
      write('$package/lib/$package.dart', library);
    }
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
            for (final package in _stateManagers.keys)
              (package, '../../$package/'),
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
    return DartApp._(root);
  }

  final Directory _root;

  String get _appPath =>
      Directory('${_root.path}/app').resolveSymbolicLinksSync();

  /// The packages that the tests of this package resolve, as the entries of
  /// a package config, each with the root of its package as an absolute
  /// URI: `bloc` and `riverpod` are among them.
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

  /// The errors and warnings that the analyzer finds in the files of the
  /// app at [paths], each with the path of its file.
  Future<List<String>> analysisProblems(Iterable<String> paths) async {
    final appPath = _appPath;
    final collection = AnalysisContextCollection(includedPaths: [appPath]);
    try {
      final problems = <String>[];
      for (final file in paths) {
        // The analyzer takes only the paths of the system, such as
        // C:\app\lib\main.dart on Windows.
        final path = Uri.directory(appPath).resolve(file).toFilePath();
        final result = await collection
            .contextFor(path)
            .currentSession
            .getResolvedUnit(path);
        if (result is! ResolvedUnitResult) {
          problems.add('$file: cannot be resolved: $result');
          continue;
        }
        for (final diagnostic in result.diagnostics) {
          if (diagnostic.severity == Severity.info) continue;
          problems.add(
            '$file:${result.lineInfo.getLocation(diagnostic.offset)}: '
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
