import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/testing.dart';

/// The owner of the files of the app entry.
const _appEntry = ModuleOrigin(FlutterCoreModule.id);

/// Stand-ins for the parts of Flutter's widgets library that the checked
/// files use, with the signatures of Flutter 3.44: its own, and what it
/// exports of the foundation library, which leaves out `ValueListenable`.
const _widgets = '''
import 'foundation.dart';

export 'foundation.dart' show Listenable, ValueNotifier, VoidCallback;

abstract class Key {
  const Key();
}

abstract class LocalKey extends Key {
  const LocalKey();
}

class ValueKey<T> extends LocalKey {
  const ValueKey(this.value);

  final T value;
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

abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
}

abstract class State<T extends StatefulWidget> {}

class GlobalKey<T extends State<StatefulWidget>> extends Key {
  const GlobalKey();

  T? get currentState => null;
}

class Navigator extends StatefulWidget {
  const Navigator({super.key});
}

class NavigatorState extends State<Navigator> {
  Future<bool> maybePop<T extends Object?>([T? result]) async => false;
}

abstract class BackButtonDispatcher {
  void addCallback(ValueGetter<Future<bool>> callback) {}

  void removeCallback(ValueGetter<Future<bool>> callback) {}
}

class RootBackButtonDispatcher extends BackButtonDispatcher {}

class RouterConfig<T> {
  const RouterConfig({this.backButtonDispatcher});

  final BackButtonDispatcher? backButtonDispatcher;
}

class NavigatorObserver {}

typedef ValueChanged<T> = void Function(T value);

final class IconData {
  const IconData(this.codePoint, {this.fontFamily});

  final int codePoint;

  final String? fontFamily;
}
''';

/// Stand-ins for the parts of Flutter's foundation library that the checked
/// files use, with the signatures of Flutter 3.44.
const _foundation = '''
const bool kDebugMode = true;

void debugPrint(String? message, {int? wrapWidth}) {}

typedef VoidCallback = void Function();

typedef ValueGetter<T> = T Function();

abstract class Listenable {
  const Listenable();

  factory Listenable.merge(Iterable<Listenable?> listenables) =>
      throw UnimplementedError();

  void addListener(VoidCallback listener);
}

abstract class ValueListenable<T> extends Listenable {
  const ValueListenable();

  T get value;
}

class ValueNotifier<T> extends ValueListenable<T> {
  ValueNotifier(this.value);

  @override
  T value;

  @override
  void addListener(VoidCallback listener) {}
}
''';

/// Flutter's material library, of which the checked files use what it
/// exports of the widgets library, such as the classes of the screens of
/// the app entry, and the icons of the destinations of the features of the
/// tests.
const _material = '''
import 'widgets.dart';

export 'widgets.dart';

abstract final class Icons {
  static const IconData list = IconData(0xe384, fontFamily: 'MaterialIcons');

  static const IconData person = IconData(
    0xe491,
    fontFamily: 'MaterialIcons',
  );

  static const IconData settings = IconData(
    0xe57f,
    fontFamily: 'MaterialIcons',
  );
}
''';

/// Stand-ins for the parts of go_router that the rendered apps use, with
/// the signatures of go_router 17.5.
const _goRouter = '''
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

abstract class GoRouterState {
  Map<String, String> get pathParameters;

  Uri get uri;

  GoRoute? get topRoute;
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
    this.name,
    GoRouterWidgetBuilder? builder,
    GoRouterRedirect? redirect,
    List<RouteBase> routes = const <RouteBase>[],
  });

  final String? name;
}

typedef StatefulShellRouteBuilder = Widget Function(
  BuildContext context,
  GoRouterState state,
  StatefulNavigationShell navigationShell,
);

abstract class StatefulNavigationShell extends StatefulWidget {
  const StatefulNavigationShell({super.key});

  int get currentIndex;

  void goBranch(int index, {bool initialLocation = false});
}

class StatefulShellBranch {
  StatefulShellBranch({
    required List<RouteBase> routes,
    String? initialLocation,
    List<NavigatorObserver>? observers,
  });
}

class StatefulShellRoute extends RouteBase {
  StatefulShellRoute.indexedStack({
    required List<StatefulShellBranch> branches,
    bool notifyRootObserver = true,
    GoRouterRedirect? redirect,
    StatefulShellRouteBuilder? builder,
  });
}

abstract class RouteMatchBase {
  RouteBase get route;
}

class RouteMatch extends RouteMatchBase {
  RouteMatch(this.route, this.pageKey);

  @override
  final GoRoute route;

  final ValueKey<String> pageKey;
}

class ImperativeRouteMatch extends RouteMatch {
  ImperativeRouteMatch(
    super.route,
    super.pageKey,
    this.matches,
    this.completer,
  );

  final RouteMatchList matches;

  final Completer<Object?> completer;
}

class ShellRouteMatch extends RouteMatchBase {
  ShellRouteMatch(this.route);

  @override
  final RouteBase route;

  final List<RouteMatchBase> matches = const [];
}

class RouteMatchList {
  final List<RouteMatchBase> matches = const [];

  final Uri uri = Uri();

  bool get isEmpty => matches.isEmpty;

  bool get isError => false;

  RouteMatch? get lastOrNull => null;
}

class GoRouterDelegate implements Listenable {
  RouteMatchList currentConfiguration = RouteMatchList();

  GlobalKey<NavigatorState> get navigatorKey => const GlobalKey();

  @override
  void addListener(VoidCallback listener) {}
}

class RouteConfiguration {
  RouteMatchList findMatch(Uri uri, {Object? extra}) => RouteMatchList();
}

typedef OnEnter = FutureOr<Object> Function(
  BuildContext context,
  GoRouterState currentState,
  GoRouterState nextState,
  GoRouter goRouter,
);

class RoutingConfig {
  const RoutingConfig({
    required this.routes,
    this.onEnter,
    this.redirect = _defaultRedirect,
    this.redirectLimit = 5,
  });

  static FutureOr<String?> _defaultRedirect(
    BuildContext context,
    GoRouterState state,
  ) =>
      null;

  final List<RouteBase> routes;

  final OnEnter? onEnter;

  final GoRouterRedirect redirect;

  final int redirectLimit;
}

class GoRouter implements RouterConfig<RouteMatchList> {
  factory GoRouter({
    required List<RouteBase> routes,
    GoRouterRedirect? redirect,
    String? initialLocation,
    List<NavigatorObserver>? observers,
  }) =>
      throw UnimplementedError();

  GoRouter.routingConfig({
    required ValueListenable<RoutingConfig> routingConfig,
    String? initialLocation,
    List<NavigatorObserver>? observers,
  }) : backButtonDispatcher = RootBackButtonDispatcher();

  late final RouteConfiguration configuration;

  @override
  final BackButtonDispatcher backButtonDispatcher;

  late final GoRouterDelegate routerDelegate;

  void go(String location, {Object? extra}) {}

  void restore(RouteMatchList matchList) {}

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
/// It checks the files of every owner but the app entry, which the app
/// needs for the names they declare and whose code is its own module's to
/// check, so the stand-ins have only what the router and the features use.
/// It checks the types of the generated code with the Dart SDK alone, as
/// the tests of the package run without the Flutter SDK.
Future<List<String>> analysisProblems(RenderedApp app) async {
  final root = Directory.systemTemp.createTempSync('smf_go_router_');
  try {
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    write('flutter/lib/foundation.dart', _foundation);
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
        if (file.owner == _appEntry) continue;
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
  } finally {
    root.deleteSync(recursive: true);
  }
}
