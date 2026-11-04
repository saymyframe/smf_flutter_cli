import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';

/// The Dart files in `lib/` of a rendered app that the owners that a test
/// names generated, and those of the app that they import, written as the
/// package of the app with [DartOnlyApp], so that the code of the values can
/// be analyzed, compiled and run with the Dart SDK alone.
///
/// `AppEnv`, the check of the env role and the files of the modules of the
/// tests import nothing but files of the app; the other files of the app
/// need Flutter. [delete] removes the directory.
final class DartApp {
  DartApp._(this._app, this._paths);

  /// Writes the Dart files in `lib/` of [app] that [owners] generated.
  factory DartApp.write(RenderedApp app, Set<ContributionOrigin> owners) {
    final paths = [
      for (final file in app.files.values)
        if (file.path.startsWith('lib/') &&
            file.path.endsWith('.dart') &&
            owners.contains(file.owner))
          file.path,
    ];
    return DartApp._(DartOnlyApp.write(app, paths), paths);
  }

  final DartOnlyApp _app;
  final List<String> _paths;

  /// The diagnostics that the analyzer finds in the files of the owners,
  /// each with the path of its file, infos included.
  Future<List<String>> analysisProblems() async {
    final appPath = _app.path;
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
          problems.add(
            '$file:${result.lineInfo.getLocation(diagnostic.offset)}: '
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

  /// Runs [script] as [DartOnlyApp.run] does, with [defines] as the
  /// `flutter` tool gives a value of a line `KEY=value` of `.env` to the app
  /// that it builds.
  Future<String> run(String script, Map<String, String> defines) =>
      _app.run(script, defines: defines);

  /// Compiles [script] as a release build does, as [DartOnlyApp.compile]
  /// does, with [defines].
  Future<({bool compiled, String output})> compile(
    String script, [
    Map<String, String> defines = const {},
  ]) =>
      _app.compile(script, defines: defines);

  /// Deletes the directory of the app.
  void delete() => _app.delete();
}
