import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

/// Minimal stand-ins for the go_router and Flutter APIs that generated route
/// code refers to, so snippets can be type-checked without the Flutter SDK.
const goRouterStubs = '''
class BuildContext {}

class GoRouterState {
  Map<String, String> get pathParameters => const {};
  Uri get uri => Uri();
}

typedef GoRouterRedirect = String? Function(
  BuildContext context,
  GoRouterState state,
);

abstract class RouteBase {}

class GoRoute extends RouteBase {
  GoRoute({
    required String path,
    String? name,
    Object Function(BuildContext context, GoRouterState state)? builder,
    GoRouterRedirect? redirect,
  });
}

class ShellRoute extends RouteBase {
  ShellRoute({
    required Object Function(
      BuildContext context,
      GoRouterState state,
      Object child,
    ) builder,
    required List<RouteBase> routes,
    GoRouterRedirect? redirect,
  });
}
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
  final dir = await Directory.systemTemp.createTemp('smf_go_router_check');
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
