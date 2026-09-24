import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

/// Minimal stand-in for the get_it API that generated registrations use, so
/// they can be type-checked without the get_it package.
const getItStubs = '''
class GetIt {
  static final instance = GetIt();

  T call<T extends Object>() => throw UnimplementedError();

  void registerFactory<T extends Object>(T Function() factoryFunc) {}

  void registerLazySingleton<T extends Object>(T Function() factoryFunc) {}
}

final getIt = GetIt.instance;
''';

/// Fails unless [source] parses as a Dart compilation unit without errors.
void expectParses(String source) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  expect(
    result.errors.map((e) => e.message),
    isEmpty,
    reason: 'Generated code is not valid Dart:\n$source',
  );
}

/// Resolves [source] as a standalone library against the Dart SDK and returns
/// the messages of its compile-time errors.
Future<List<String>> compileErrors(String source) async {
  final dir = await Directory.systemTemp.createTemp('smf_get_it_check');
  final collection = AnalysisContextCollection(includedPaths: [dir.path]);
  try {
    final file = join(dir.path, 'generated.dart');
    await File(file).writeAsString(source);

    final result =
        await collection.contextFor(file).currentSession.getResolvedUnit(file);
    if (result is! ResolvedUnitResult) {
      fail('Could not resolve generated code: $result');
    }

    return result.diagnostics
        .where((d) => d.severity == Severity.error)
        .map((d) => d.message)
        .toList();
  } finally {
    await collection.dispose();
    await dir.delete(recursive: true);
  }
}
