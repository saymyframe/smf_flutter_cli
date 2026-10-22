import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';

/// The Dart files in `lib/` of a rendered app, written to a temporary
/// directory as the package `contract_app`, so that the code of the values
/// can be analyzed and run with the Dart SDK alone.
///
/// `AppEnv` and the files of the modules of the tests import nothing but
/// files of the app. The other files of the app need Flutter, so the
/// analyzer checks the files of the owners it is given, and a script that
/// runs the app imports none of the others. [delete] removes the directory.
final class DartApp {
  DartApp._(this._root, this._files);

  /// Writes the Dart files in `lib/` of [app].
  factory DartApp.write(RenderedApp app) {
    final root = Directory.systemTemp.createTempSync('smf_dart_define_');
    final files = [
      for (final file in app.files.values)
        if (file.path.startsWith('lib/') && file.path.endsWith('.dart')) file,
    ];
    final dartApp = DartApp._(root, files);
    for (final file in files) {
      dartApp._write('app/${file.path}', file.text);
    }
    dartApp
      .._write('app/pubspec.yaml', 'name: contract_app\n')
      .._write(
        _packageConfig,
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'contract_app',
              'rootUri': '../',
              'packageUri': 'lib/',
              'languageVersion': '3.12',
            },
          ],
        }),
      );
    return dartApp;
  }

  /// The path of the package config of the app in the directory.
  static const _packageConfig = 'app/.dart_tool/package_config.json';

  final Directory _root;
  final List<RenderedFile> _files;

  String get _appPath =>
      Directory('${_root.path}/app').resolveSymbolicLinksSync();

  void _write(String path, String text) => File('${_root.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  /// The diagnostics that the analyzer finds in the files of [owners], each
  /// with the path of its file, infos included.
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
          problems.add(
            '${file.path}:${result.lineInfo.getLocation(diagnostic.offset)}: '
            '${diagnostic.severity == Severity.info ? 'info: ' : ''}'
            '${diagnostic.message}',
          );
        }
      }
      return problems;
    } finally {
      await collection.dispose();
    }
  }

  /// Runs [script], a Dart program that imports the app by its package,
  /// `contract_app`, with the Dart VM, which gives `String.fromEnvironment`
  /// each of [defines] as `-D<key>=<value>`, as the `flutter` tool gives a
  /// value of a line `KEY=value` of `.env` to the app that it builds; returns
  /// what the program printed.
  ///
  /// Throws a [StateError] with what it printed if the program fails.
  Future<String> run(String script, Map<String, String> defines) async {
    final file = File('${_root.path}/check.dart')..writeAsStringSync(script);
    final result = await Process.run(
      Platform.resolvedExecutable,
      [
        '--packages=$_appPath/.dart_tool/package_config.json',
        for (final MapEntry(:key, :value) in defines.entries) '-D$key=$value',
        file.path,
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'The program failed with ${result.exitCode}: ${result.stdout}'
        '${result.stderr}',
      );
    }
    return '${result.stdout}';
  }

  /// Deletes the directory of the app.
  void delete() => _root.deleteSync(recursive: true);
}
