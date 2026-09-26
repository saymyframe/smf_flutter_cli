import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:smf_pipeline/testing.dart';

/// Stand-ins for the parts of Flutter's widgets library that the rendered
/// apps use, with the signatures of Flutter 3.44.
const _widgets = '''
import 'dart:async';

abstract class Key {
  const Key();
}

abstract interface class BuildContext {}

abstract class Widget {
  const Widget({this.key});

  final Key? key;
}

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});

  Widget build(BuildContext context);
}

class SizedBox extends StatelessWidget {
  const SizedBox({super.key});

  @override
  Widget build(BuildContext context) => this;
}

typedef TransitionBuilder = Widget Function(BuildContext context, Widget? child);

class RouterConfig<T> {}

class NavigatorObserver {}

class WidgetsFlutterBinding {
  static WidgetsFlutterBinding ensureInitialized() => WidgetsFlutterBinding();
}

void runApp(Widget app) {}
''';

/// Stand-ins for the parts of Flutter's material library that the rendered
/// apps use, with the signatures of Flutter 3.44.
const _material = '''
export 'widgets.dart';

import 'widgets.dart';

class MaterialApp extends StatelessWidget {
  const MaterialApp({super.key, this.title = '', Widget? home, TransitionBuilder? builder});

  const MaterialApp.router({
    super.key,
    this.title = '',
    RouterConfig<Object>? routerConfig,
    TransitionBuilder? builder,
  });

  final String title;

  @override
  Widget build(BuildContext context) => this;
}

class Scaffold extends StatelessWidget {
  const Scaffold({super.key, Widget? body});

  @override
  Widget build(BuildContext context) => this;
}

class Center extends StatelessWidget {
  const Center({super.key, Widget? child});

  @override
  Widget build(BuildContext context) => this;
}

class Text extends StatelessWidget {
  const Text(String data, {super.key});

  @override
  Widget build(BuildContext context) => this;
}
''';

/// Stand-ins for the parts of go_router that the rendered apps use, with
/// the signatures of go_router 17.5.
const _goRouter = '''
import 'dart:async';

import 'package:flutter/widgets.dart';

abstract class GoRouterState {
  Map<String, String> get pathParameters;

  Uri get uri;
}

typedef GoRouterRedirect = FutureOr<String?> Function(
  BuildContext context,
  GoRouterState state,
);

typedef GoRouterWidgetBuilder = Widget Function(
  BuildContext context,
  GoRouterState state,
);

abstract class RouteBase {}

class GoRoute extends RouteBase {
  GoRoute({
    required String path,
    String? name,
    GoRouterWidgetBuilder? builder,
    GoRouterRedirect? redirect,
    List<RouteBase> routes = const <RouteBase>[],
  });
}

class RouteMatchList {}

class GoRouter implements RouterConfig<RouteMatchList> {
  factory GoRouter({
    required List<RouteBase> routes,
    String? initialLocation,
    List<NavigatorObserver>? observers,
  }) =>
      throw UnimplementedError();

  void go(String location, {Object? extra}) {}

  Future<T?> push<T extends Object?>(String location, {Object? extra}) async =>
      null;

  Future<T?> pushReplacement<T extends Object?>(
    String location, {
    Object? extra,
  }) async =>
      null;
}

class GoException implements Exception {
  GoException(this.message);

  final String message;
}
''';

/// Resolves the Dart files in `lib/` of [app] against stand-ins of the
/// Flutter and go_router libraries they use, and returns the errors and
/// warnings the analyzer finds, each with the path of its file.
///
/// It checks the types of the generated code with the Dart SDK alone, as
/// the tests of the package run without the Flutter SDK.
Future<List<String>> analysisProblems(RenderedApp app) async {
  final root = Directory.systemTemp.createTempSync('smf_go_router_');
  try {
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    write('flutter/lib/widgets.dart', _widgets);
    write('flutter/lib/material.dart', _material);
    write('go_router/lib/go_router.dart', _goRouter);
    final dartFiles = [
      for (final file in app.files.values)
        if (file.path.startsWith('lib/') && file.path.endsWith('.dart')) file,
    ];
    for (final file in dartFiles) {
      write('app/${file.path}', file.text);
    }
    write('app/pubspec.yaml', 'name: contract_app\n');
    write(
      'app/.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final (name, rootUri) in [
            ('contract_app', '../'),
            ('flutter', '../../flutter/'),
            ('go_router', '../../go_router/'),
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

    final appPath = Directory('${root.path}/app').resolveSymbolicLinksSync();
    final collection = AnalysisContextCollection(includedPaths: [appPath]);
    try {
      final problems = <String>[];
      for (final file in dartFiles) {
        final path = '$appPath/${file.path}';
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
  } finally {
    root.deleteSync(recursive: true);
  }
}
