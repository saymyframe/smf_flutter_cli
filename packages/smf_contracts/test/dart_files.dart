import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';

import 'support.dart';

/// A stand-in for the part of Flutter's foundation library that the
/// templates of the roles use, with the signatures of Flutter 3.44: the app
/// runs in debug mode, and what it prints goes to `debugPrinted`.
const _foundation = r'''
/// What the app printed with [debugPrint], in order.
final List<String> debugPrinted = [];

const bool kDebugMode = true;

void debugPrint(String? message, {int? wrapWidth}) =>
    debugPrinted.add('$message');
''';

/// A stand-in for the part of Flutter's material library that the templates
/// of the roles use outside their widgets, with the signatures of Flutter
/// 3.44: the modes of a theme, a notifier that calls its listeners, and an
/// inherited widget that holds one, which a context gives to the code that
/// asks for it. Nothing here builds a widget, so what a notifier rebuilds
/// is for the tests of a running app.
const _material = '''
enum ThemeMode { system, light, dark }

typedef VoidCallback = void Function();

abstract class Listenable {
  const Listenable();

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);
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
}

abstract class Key {}

abstract class Widget {
  const Widget({this.key});

  final Key? key;
}

abstract class InheritedWidget extends Widget {
  const InheritedWidget({super.key, required this.child});

  final Widget child;
}

abstract class InheritedNotifier<T extends Listenable> extends InheritedWidget {
  const InheritedNotifier({super.key, this.notifier, required super.child});

  final T? notifier;
}

abstract class BuildContext {
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>({
    Object? aspect,
  });
}
''';

/// Dart files of an app, written to a temporary directory as the package of
/// the test app, with stand-ins for Flutter's foundation and material
/// libraries, so that the code that the template of a role generates can be
/// type-checked and run with the Dart SDK alone, as the tests of the
/// package run without the Flutter SDK. [delete] removes the directory.
final class DartFiles {
  DartFiles._(this._root, this._paths);

  /// Writes [files], the text of each Dart file by its path from the root
  /// of the app, such as `lib/core/preferences/app_preferences.dart`.
  factory DartFiles.write(Map<String, String> files) {
    final root = Directory.systemTemp.createTempSync('smf_contracts_');
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    for (final MapEntry(key: path, value: text) in files.entries) {
      write('app/$path', text);
    }
    write('flutter/lib/foundation.dart', _foundation);
    write('flutter/lib/material.dart', _material);
    write('app/pubspec.yaml', 'name: ${testContext.appName}\n');
    write(
      'app/.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final (name, rootUri) in [
            (testContext.appName, '../'),
            ('flutter', '../../flutter/'),
          ])
            {
              'name': name,
              'rootUri': rootUri,
              'packageUri': 'lib/',
              'languageVersion': '3.12',
            },
        ],
      }),
    );
    return DartFiles._(root, [...files.keys]);
  }

  final Directory _root;
  final List<String> _paths;

  String get _appPath =>
      Directory('${_root.path}/app').resolveSymbolicLinksSync();

  /// The errors and warnings that the analyzer finds in the files, each
  /// with the path of its file.
  Future<List<String>> analysisProblems() async {
    final appPath = _appPath;
    final collection = AnalysisContextCollection(includedPaths: [appPath]);
    try {
      final problems = <String>[];
      for (final file in _paths) {
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
  /// imports the files by the package of the test app, in an isolate of its
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

  /// Deletes the directory of the files.
  void delete() => _root.deleteSync(recursive: true);
}
