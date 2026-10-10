import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_go_router/src/agents.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/features.dart';
import 'support/type_check.dart';

/// `_checkValues` as the analyzer prints its declaration.
final String _expectedCheckValues = parseString(
  content: r'''
String? _checkValues(Map<String, Object?> values) {
  final invalid = [
    for (final MapEntry(:key, :value) in values.entries)
      if (value == null) key,
  ];
  if (invalid.isEmpty) return null;
  throw GoException('The location has no valid ${invalid.join(', ')}.');
}
''',
).unit.declarations.single.toSource();

/// `_checkMainNavigation` as the analyzer prints its declaration.
final String _expectedCheckMainNavigation = parseString(
  content: r'''
class _GoAppRouter {
  void _checkMainNavigation(AppLocation location, String method) {
    final matches = config.routerDelegate.currentConfiguration.matches;
    if (matches.isEmpty ||
        matches.last is ShellRouteMatch ||
        !matches.any((match) => match is ShellRouteMatch)) {
      return;
    }
    final target = config.configuration.findMatch(Uri.parse(location.path));
    if (target.matches.firstOrNull is! ShellRouteMatch) return;
    throw StateError(
      'Cannot $method ${location.path}: it is in the main navigation, and a '
      'page is shown over the main navigation. Use go() to show it there.',
    );
  }
}
''',
)
    .unit
    .declarations
    .whereType<ClassDeclaration>()
    .single
    .body
    .members
    .single
    .toSource();

/// `_showScreen` as the analyzer prints its declaration.
final String _expectedShowScreen = parseString(
  content: '''
class _GoAppRouter {
  void _showScreen() {
    final configuration = config.routerDelegate.currentConfiguration;
    final top = configuration.lastOrNull;
    final location = switch (top) {
      ImperativeRouteMatch(:final matches) => matches.uri.toString(),
      _ => configuration.uri.toString(),
    };
    final screen = (top?.pageKey, location);
    if (screen == _screen) return;
    _screen = screen;
    for (final listener in _screenListeners) {
      _callAlone(listener, top?.route.name, location);
    }
  }
}
''',
)
    .unit
    .declarations
    .whereType<ClassDeclaration>()
    .single
    .body
    .members
    .single
    .toSource();

/// `_callAlone`, with which the router calls each listener of the screen,
/// as the analyzer prints its declaration.
final String _expectedCallAlone = parseString(
  content: r'''
void _callAlone(
  void Function(String? route, String location) listener,
  String? route,
  String location,
) {
  try {
    listener(route, location);
  } on Object catch (error) {
    if (kDebugMode) {
      debugPrint('A listener of the screen failed: $error');
    }
  }
}
''',
).unit.declarations.single.toSource();

/// `_pagesChanged` of an app, as the analyzer prints its declaration: with
/// a main navigation ([shell]), it first gives go_router a new main
/// navigation if the main navigation has left its pages, and does not
/// follow the pages of go_router while it does so; and with [guards], it
/// drops the request that waits for a flow once no page of the flow is
/// left, and tells the listeners of the screen nothing while the router
/// does what the guards answered.
String _expectedPagesChanged({required bool shell, required bool guards}) =>
    parseString(
      content: '''
class _GoAppRouter {
  void _pagesChanged() {
    ${shell ? 'if (_renewing) return; _renewMainNavigation();' : ''}
    _keepPushes();
    ${guards ? 'if (_waiting case final waiting? when !_shows(waiting.flow)) '
              '_drop(); if (_muted) return;' : ''}
    _showScreen();
  }
}
''',
    )
        .unit
        .declarations
        .whereType<ClassDeclaration>()
        .single
        .body
        .members
        .single
        .toSource();

/// The members of the router that give go_router a new route for the main
/// navigation once the main navigation has left its pages, as the analyzer
/// prints their declarations, by name.
final Map<String, String> _expectedRenewalMembers = {
  for (final member in parseString(
    content: '''
class _GoAppRouter {
  late StatefulShellRoute _mainNavigationRoute = _mainNavigation();

  bool _mainNavigationShown = false;

  bool _renewing = false;

  void _renewMainNavigation() {
    final shown = config.routerDelegate.currentConfiguration;
    if (shown.matches.any(
      (page) => identical(page.route, _mainNavigationRoute),
    )) {
      _mainNavigationShown = true;
      return;
    }
    if (!_mainNavigationShown) return;
    _mainNavigationShown = false;
    final left = _mainNavigationRoute;
    final routes = _routes.value;
    _mainNavigationRoute = _mainNavigation();
    _renewing = true;
    try {
      _routes.value = RoutingConfig(
        routes: [
          for (final route in routes.routes)
            identical(route, left) ? _mainNavigationRoute : route,
        ],
        onEnter: routes.onEnter,
        redirect: routes.redirect,
        redirectLimit: routes.redirectLimit,
      );
      if (config.routerDelegate.currentConfiguration != shown) {
        config.restore(shown);
      }
    } finally {
      _renewing = false;
    }
  }
}
''',
  ).unit.declarations.whereType<ClassDeclaration>().single.body.members)
    _nameOf(member)!: member.toSource(),
};

/// The members of the router that let each push complete with the value
/// that its page returns when it closes, whatever completer go_router gives
/// the page, as the analyzer prints their declarations, by name.
final Map<String, String> _expectedPushMembers = {
  for (final member in parseString(
    content: '''
class _GoAppRouter {
  Map<LocalKey, ImperativeRouteMatch> _pushed = {};

  final Expando<Completer<Object?>> _pushes = Expando();

  void _keepPushes() {
    final pushed = {
      for (final page in _pushedPages(
        config.routerDelegate.currentConfiguration.matches,
      ))
        page.pageKey: page,
    };
    for (final page in pushed.values) {
      final before = _pushed[page.pageKey];
      if (before == null ||
          before.completer == page.completer ||
          before.matches.uri != page.matches.uri) {
        continue;
      }
      final push = _pushes[before.completer] ?? before.completer;
      _pushes[page.completer] = push;
      unawaited(
        page.completer.future.then((value) {
          if (!push.isCompleted) push.complete(value);
        }),
      );
    }
    _pushed = pushed;
  }

  static Iterable<ImperativeRouteMatch> _pushedPages(
    List<RouteMatchBase> matches,
  ) sync* {
    for (final match in matches) {
      if (match is ImperativeRouteMatch) yield match;
      if (match is ShellRouteMatch) yield* _pushedPages(match.matches);
    }
  }
}
''',
  ).unit.declarations.whereType<ClassDeclaration>().single.body.members)
    _nameOf(member)!: member.toSource(),
};

/// The members of the router that ask the guards of the app and do what
/// they answer, as the analyzer prints their declarations, by name; the
/// constructor is under the name of its class.
final Map<String, String> _expectedGuardMembers = {
  for (final member in parseString(
    content: r'''
class _GoAppRouter {
  _GoAppRouter() {
    guardChanges.addListener(_guardsChanged);
  }

  final GuardedNavigation<String> _guards = GuardedNavigation(
    start: '/',
    locationOf: (location) => location.path,
  );

  ({Set<String> flow, void Function() again, void Function()? drop})? _waiting;

  void Function()? _opening;

  bool _muted = false;

  void _quietly(void Function() navigate) {
    final muted = _muted;
    _muted = true;
    try {
      navigate();
    } finally {
      _muted = muted || _opening != null;
      if (!_muted) _showScreen();
    }
  }

  String? _redirect(String? route, String location) {
    switch (_guards.asked(route, location, onTopOf: const [])) {
      case null || ShowNothing():
        return null;
      case ShowInstead(location: final shown):
        return shown;
      case ShowOver(location: final target, :final flow):
        _muted = true;
        void open() {
          if (_opening != open) return;
          _opening = null;
          _muted = false;
          _open(target, flow, again: () => config.go(location));
        }
        _opening = open;
        scheduleMicrotask(open);
        return _guards.start;
    }
  }

  bool _redirected(
    AppLocation location, {
    required void Function() again,
    void Function()? drop,
  }) {
    final pages = _pages;
    if (pages.isEmpty) {
      config.go(location.path);
      drop?.call();
      return true;
    }
    final answer = _guards.asked(
      location.routeName,
      location.path,
      onTopOf: [for (final page in pages) page.route],
    );
    switch (answer) {
      case null:
        return false;
      case ShowInstead(location: final shown):
        config.go(shown);
        drop?.call();
      case ShowNothing():
        drop?.call();
      case ShowOver(location: final target, :final flow):
        if (config.routerDelegate.currentConfiguration.isError) {
          config.go(location.path);
          drop?.call();
        } else {
          _open(target, flow, again: again, drop: drop);
        }
    }
    return true;
  }

  void _open(
    String target,
    Set<String> flow, {
    required void Function() again,
    void Function()? drop,
  }) {
    _drop();
    unawaited(config.push<Object?>(target));
    _waiting = (flow: flow, again: again, drop: drop);
  }

  void _drop() {
    final waiting = _waiting;
    _waiting = null;
    waiting?.drop?.call();
  }

  void _close(int count, {required bool dropsRequest}) {
    final waiting = _waiting;
    _waiting = null;
    _quietly(() {
      final shown = config.routerDelegate.currentConfiguration;
      final closing = _pushedPages(
        shown.matches,
      ).toList().reversed.take(count).toList();
      config.restore(shown.remove(closing.last));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final page in closing) {
          if (!page.completer.isCompleted) page.completer.complete();
        }
      });
      if (waiting == null) return;
      if (dropsRequest) {
        waiting.drop?.call();
      } else if (_shows(waiting.flow)) {
        _waiting = waiting;
      } else {
        waiting.again();
      }
    });
  }

  bool _shows(Set<String> flow) =>
      _pages.any((page) => flow.contains(page.route));

  List<({String? route, String location, bool pushed})> get _pages {
    final configuration = config.routerDelegate.currentConfiguration;
    if (configuration.isEmpty && !configuration.isError) return const [];
    final below = config.configuration.findMatch(configuration.uri);
    return [
      for (final page in _pushedPages(configuration.matches).toList().reversed)
        (route: page.route.name, location: '${page.matches.uri}', pushed: true),
      (
        route: below.lastOrNull?.route.name,
        location: '${configuration.uri}',
        pushed: false,
      ),
    ];
  }

  void _guardsChanged() {
    final pages = _pages;
    if (pages.isEmpty) return;
    switch (_guards.changed(pages)) {
      case null:
        break;
      case ShowInstead(:final location):
        config.go(location);
      case ClosePages(pages: final count, :final dropsRequest):
        _close(count, dropsRequest: dropsRequest);
    }
  }
}
''',
  ).unit.declarations.whereType<ClassDeclaration>().single.body.members)
    _nameOf(member)!: member.toSource(),
};

/// `_BackButton`, the dispatcher of the back button of the system of the
/// router, which asks go_router to close the route on top only while
/// go_router has a page of a route, and the root navigator otherwise, as on
/// the error screen of go_router, where its delegate throws
/// (https://github.com/flutter/flutter/issues/187616), as the analyzer
/// prints its declaration.
final String _expectedBackButton = parseString(
  content: '''
final class _BackButton extends RootBackButtonDispatcher {
  _BackButton(this._router);

  final GoRouter _router;

  final Map<ValueGetter<Future<bool>>, ValueGetter<Future<bool>>> _asked = {};

  @override
  void addCallback(ValueGetter<Future<bool>> callback) => super.addCallback(
    _asked[callback] = () {
      final delegate = _router.routerDelegate;
      if (delegate.currentConfiguration.matches.isNotEmpty) return callback();
      return delegate.navigatorKey.currentState?.maybePop() ??
          Future.value(false);
    },
  );

  @override
  void removeCallback(ValueGetter<Future<bool>> callback) =>
      super.removeCallback(_asked.remove(callback) ?? callback);
}
''',
).unit.declarations.single.toSource();

/// The constructor of `_GoRouter` in an app without a main navigation and
/// without guards, which takes the routes as `GoRouter()` does.
const String _constructorOfRoutes = '''
  _GoRouter({
    required List<RouteBase> routes,
    super.initialLocation,
    super.observers,
  }) : super.routingConfig(
         routingConfig: ValueNotifier(RoutingConfig(routes: routes)),
       );
''';

/// The constructor of `_GoRouter` in an app without a main navigation whose
/// modules declare guards, which takes the redirect that asks them too.
const String _constructorOfGuardedRoutes = '''
  _GoRouter({
    required List<RouteBase> routes,
    required GoRouterRedirect redirect,
    super.initialLocation,
    super.observers,
  }) : super.routingConfig(
         routingConfig: ValueNotifier(
           RoutingConfig(routes: routes, redirect: redirect),
         ),
       );
''';

/// The constructor of `_GoRouter` in an app with a main navigation, which
/// takes the routes that go_router follows as `GoRouter.routingConfig()`
/// does.
const String _constructorOfRoutingConfig = '''
  _GoRouter.routingConfig({
    required super.routingConfig,
    super.initialLocation,
    super.observers,
  }) : super.routingConfig();
''';

/// `_GoRouter`, the `GoRouter` of the app with [constructor], whose
/// dispatcher of the back button of the system is a `_BackButton`, as the
/// analyzer prints its declaration.
String _expectedGoRouter(String constructor) => parseString(
      content: '''
final class _GoRouter extends GoRouter {
$constructor
  @override
  BackButtonDispatcher get backButtonDispatcher => _backButton;

  late final _BackButton _backButton = _BackButton(this);
}
''',
    ).unit.declarations.single.toSource();

/// Whether the router of [unit] asks guards: it takes the listenable of
/// their changes from the file of the router role.
bool _asksGuards(CompilationUnit unit) =>
    _shownOfTheRole(unit).contains(RouterRole.guardChanges);

/// The path of the file of `createAppRouter()`.
const String _factory = RouterRole.appRouterFactoryFile;

/// The owners of the code of the router: the template of the role and this
/// module.
final Set<ContributionOrigin> _router = {
  const RoleTemplateOrigin(routerRole),
  const ModuleOrigin(GoRouterModule.id),
};

/// The pubspec of [app] as plain maps and lists.
Map<String, Object?> _pubspecOf(RenderedApp app) {
  Object? plain(Object? node) => switch (node) {
        final YamlMap map => {
            for (final MapEntry(:key, :value) in map.entries)
              '$key': plain(value),
          },
        final YamlList list => [for (final item in list) plain(item)],
        _ => node,
      };
  return plain(loadYaml(app.files['pubspec.yaml']!.text))!
      as Map<String, Object?>;
}

/// The notes of this module in the guide for coding agents of [app], in
/// the order of the guide.
List<AgentNote> _notesOfModule(RenderedApp app) => [
      for (final (origin, heading, note)
          in app.entriesOf(AppEntryRole.agentSections))
        if (origin == const ModuleOrigin(GoRouterModule.id) &&
            heading == routerRole.description)
          note,
    ];

/// The parsed file of `createAppRouter()` of [app].
CompilationUnit _factoryOf(RenderedApp app) =>
    parseString(content: app.files[_factory]!.text).unit;

/// The call that creates the `GoRouter` in [unit], a `_GoRouter`:
/// `_GoRouter(...)`, or `_GoRouter.routingConfig(...)` in an app with a
/// main navigation.
MethodInvocation _goRouterOf(CompilationUnit unit) {
  final finder = _CallFinder('_GoRouter');
  final named = _CallFinder('routingConfig', target: '_GoRouter');
  unit
    ..accept(finder)
    ..accept(named);
  return [...finder.calls, ...named.calls].single;
}

/// The declaration of the field [name] of the router class of [unit], or
/// `null`.
FieldDeclaration? _fieldOf(CompilationUnit unit, String name) =>
    _routerClassOf(unit)
        .body
        .members
        .whereType<FieldDeclaration>()
        .where((field) => _nameOf(field) == name)
        .singleOrNull;

/// The call in [unit] that has the routes of the app and the redirect of
/// the guards: the one that creates the `GoRouter`, or, in an app with a
/// main navigation, the `RoutingConfig(...)` of the field `_routes`, which
/// go_router follows.
MethodInvocation _routingOf(CompilationUnit unit) {
  final routes = _fieldOf(unit, '_routes');
  if (routes == null) return _goRouterOf(unit);
  final finder = _CallFinder('RoutingConfig');
  routes.accept(finder);
  return finder.calls.single;
}

/// The named argument [label] of [call], or `null`.
Expression? _argument(MethodInvocation call, String label) => [
      for (final argument in call.argumentList.arguments)
        if (argument case NamedArgument(:final name, :final argumentExpression)
            when name.lexeme == label)
          argumentExpression,
    ].firstOrNull;

/// A `GoRoute(...)` of the generated code.
final class _GoRoute {
  _GoRoute(this.call);

  final MethodInvocation call;

  String get path => (_argument(call, 'path')! as StringLiteral).stringValue!;

  String? get name => (_argument(call, 'name') as StringLiteral?)?.stringValue;

  /// The source of the redirect, or `null`.
  String? get redirect => _argument(call, 'redirect')?.toSource();

  /// The source of the builder, or `null`.
  String? get builder => _argument(call, 'builder')?.toSource();

  /// The arguments that the builder passes to the screen, by name, as
  /// source.
  Map<String, String> get screenArguments {
    final body = (_argument(call, 'builder')! as FunctionExpression).body
        as ExpressionFunctionBody;
    final arguments = switch (body.expression) {
      MethodInvocation(:final argumentList) => argumentList,
      InstanceCreationExpression(:final argumentList) => argumentList,
      final other => throw StateError('The builder returns $other'),
    };
    return {
      for (final argument in arguments.arguments)
        if (argument case NamedArgument(:final name, :final argumentExpression))
          name.lexeme: argumentExpression.toSource(),
    };
  }

  List<_GoRoute> get children => switch (_argument(call, 'routes')) {
        final ListLiteral list => [
            for (final element in list.elements)
              _GoRoute(element as MethodInvocation),
          ],
        _ => const [],
      };
}

/// The items of the list of the top-level routes in [unit]: the calls
/// that create them, and, in an app with a main navigation, the field in
/// which the router keeps the route of the main navigation.
List<Expression> _topLevelOf(CompilationUnit unit) => [
      for (final element
          in (_argument(_routingOf(unit), 'routes')! as ListLiteral).elements)
        element as Expression,
    ];

/// The `GoRoute`s in the list of routes of `GoRouter` in [unit].
List<_GoRoute> _routesOf(CompilationUnit unit) => [
      for (final route in _topLevelOf(unit).whereType<MethodInvocation>())
        if (route.target == null && route.methodName.name == 'GoRoute')
          _GoRoute(route),
    ];

/// The `StatefulShellRoute.indexedStack` that the function
/// `_mainNavigation()` of [unit] returns, or `null` if [unit] has no such
/// function. The list of the top-level routes then has no shell route
/// either.
MethodInvocation? _shellOf(CompilationUnit unit) {
  expect(
    [
      for (final route in _topLevelOf(unit).whereType<MethodInvocation>())
        if (route.methodName.name != 'GoRoute') route.toSource(),
    ],
    isEmpty,
    reason: 'The routes have the main navigation only as the field of its '
        'route.',
  );
  final function = unit.declarations
      .whereType<FunctionDeclaration>()
      .where((function) => function.name.lexeme == '_mainNavigation')
      .singleOrNull;
  if (function == null) return null;
  expect(function.returnType!.toSource(), 'StatefulShellRoute');
  expect(function.functionExpression.parameters!.parameters, isEmpty);
  final shell = (function.functionExpression.body as ExpressionFunctionBody)
      .expression as MethodInvocation;
  expect(shell.target!.toSource(), 'StatefulShellRoute');
  expect(shell.methodName.name, 'indexedStack');
  return shell;
}

/// A `StatefulShellBranch(...)` of the generated code.
final class _Branch {
  _Branch(this.call);

  final MethodInvocation call;

  String get initialLocation =>
      (_argument(call, 'initialLocation')! as StringLiteral).stringValue!;

  /// The source of the observers.
  String get observers => _argument(call, 'observers')!.toSource();

  List<_GoRoute> get routes => [
        for (final element
            in (_argument(call, 'routes')! as ListLiteral).elements)
          _GoRoute(element as MethodInvocation),
      ];
}

/// The branches of [shell], a `StatefulShellRoute.indexedStack(...)`.
List<_Branch> _branchesOf(MethodInvocation shell) => [
      for (final element
          in (_argument(shell, 'branches')! as ListLiteral).elements)
        _Branch(element as MethodInvocation),
    ];

/// The source of the list that the function `_observers()` of [unit]
/// returns.
String _observersOf(CompilationUnit unit) {
  final function = unit.declarations
      .whereType<FunctionDeclaration>()
      .singleWhere((function) => function.name.lexeme == '_observers');
  return (function.functionExpression.body as ExpressionFunctionBody)
      .expression
      .toSource();
}

/// The declaration of the top-level variable `_screenListeners` of [unit].
VariableDeclarationList _screenListenersOf(CompilationUnit unit) =>
    unit.declarations
        .whereType<TopLevelVariableDeclaration>()
        .map((declaration) => declaration.variables)
        .singleWhere(
          (variables) =>
              variables.variables.single.name.lexeme == '_screenListeners',
        );

/// The source of the listeners of the screen in the list `_screenListeners`
/// of [unit].
List<String> _listenersOf(CompilationUnit unit) => [
      for (final element in (_screenListenersOf(unit)
              .variables
              .single
              .initializer! as ListLiteral)
          .elements)
        element.toSource(),
    ];

/// The name of [member] of a class if it is a field or a method, the name
/// of the class for its unnamed constructor, or `null`.
String? _nameOf(ClassMember member) => switch (member) {
      FieldDeclaration(:final fields) => fields.variables.single.name.lexeme,
      MethodDeclaration(:final name) => name.lexeme,
      ConstructorDeclaration(:final typeName?, name: null) => typeName.name,
      _ => null,
    };

/// What the file of the router in [unit] imports of the file of the router
/// role: the names of its `show`.
List<String> _shownOfTheRole(CompilationUnit unit) => [
      for (final directive in unit.directives.whereType<ImportDirective>())
        if (directive.uri.stringValue == 'app_router.dart')
          for (final combinator
              in directive.combinators.whereType<ShowCombinator>())
            for (final name in combinator.shownNames) name.name,
    ];

/// Checks that the delegate of the router of [unit], created once, tells
/// the router of every change of its configuration, which then keeps the
/// pushes complete and tells the listeners of the screen.
void _expectPagesChanged(CompilationUnit unit) {
  final router = _routerClassOf(unit);
  final config = router.body.members
      .whereType<FieldDeclaration>()
      .singleWhere((field) => _nameOf(field) == 'config')
      .fields
      .variables
      .single
      .initializer!;
  expect(config, isA<CascadeExpression>());
  config as CascadeExpression;
  expect(config.target, _goRouterOf(unit));
  // The sections after the target, as written: analyzer 14 prints a section
  // such as `..a.b()` without its `..`, and the cascade with it.
  expect(
    config.toSource().substring(config.target.toSource().length),
    '..routerDelegate.addListener(_pagesChanged)',
  );
  expect(
    router.body.members
        .singleWhere((member) => _nameOf(member) == '_pagesChanged')
        .toSource(),
    _expectedPagesChanged(
      shell: _shellOf(unit) != null,
      guards: _asksGuards(unit),
    ),
  );
}

/// Checks that the back button of the system reaches go_router in [unit]
/// only while go_router has a page of a route, so that its delegate does
/// not throw on its error screen
/// (https://github.com/flutter/flutter/issues/187616): the router of the
/// app is a `_GoRouter`, a `GoRouter` with [constructor] whose dispatcher of
/// the button is a `_BackButton`, and nothing else creates a `GoRouter`.
void _expectBackButton(CompilationUnit unit, String constructor) {
  final classes = {
    for (final declaration in unit.declarations.whereType<ClassDeclaration>())
      declaration.namePart.typeName.lexeme: declaration.toSource(),
  };
  expect(classes['_GoRouter'], _expectedGoRouter(constructor));
  expect(classes['_BackButton'], _expectedBackButton);
  final plain = _CallFinder('GoRouter');
  final named = _CallFinder('routingConfig', target: 'GoRouter');
  unit
    ..accept(plain)
    ..accept(named);
  expect([...plain.calls, ...named.calls], isEmpty);
  // The one router of the app, which its root runs, is of that class.
  expect(_goRouterOf(unit).toSource(), startsWith('_GoRouter'));
}

/// Checks that the router of [unit] lets each push complete with the value
/// that its page returns when it closes, whatever completer go_router gives
/// the page: go_router gives each pushed page a new completer when it shows
/// its pages anew, as on refresh()
/// (https://github.com/flutter/flutter/issues/128122).
void _expectPushResults(CompilationUnit unit) {
  final router = _routerClassOf(unit);
  final members = {
    for (final member in router.body.members)
      _nameOf(member): member.toSource(),
  };
  for (final MapEntry(key: name, value: source)
      in _expectedPushMembers.entries) {
    expect(members[name], source, reason: name);
  }
  expect(
    [
      for (final directive in unit.directives.whereType<ImportDirective>())
        directive.uri.stringValue,
    ],
    contains('dart:async'),
  );
  _expectPagesChanged(unit);
}

/// Checks that the router of [unit] tells the listeners of the screen, whose
/// sources are [listeners], about the screen the user sees.
void _expectScreenListeners(CompilationUnit unit, List<String> listeners) {
  final router = _routerClassOf(unit);
  final fields = {
    for (final field in router.body.members.whereType<FieldDeclaration>())
      field.fields.variables.single.name.lexeme: field.fields,
  };

  // The delegate of the router tells the router of every change of its
  // configuration, which tells the listeners of the screen.
  _expectPagesChanged(unit);
  expect(fields['_screen']!.type!.toSource(), '(LocalKey?, String)?');
  expect(
    router.body.members
        .whereType<MethodDeclaration>()
        .singleWhere((method) => method.name.lexeme == '_showScreen')
        .toSource(),
    _expectedShowScreen,
  );
  // Each listener on its own: what one throws keeps no other from hearing
  // the screen, and reaches no handler of the errors of the app.
  expect(
    unit.declarations
        .whereType<FunctionDeclaration>()
        .singleWhere((function) => function.name.lexeme == '_callAlone')
        .toSource(),
    _expectedCallAlone,
  );
  // One list for the whole app, not a list for each navigator.
  final declaration = _screenListenersOf(unit);
  expect(declaration.isFinal, isTrue);
  expect(
    declaration.type!.toSource(),
    'List<void Function(String? route, String location)>',
  );
  expect(_listenersOf(unit), listeners);
}

/// Every route of [routes] and below them, parents first, each with the
/// path of its parent.
List<(_GoRoute, String?)> _allOf(List<_GoRoute> routes, [String? parent]) => [
      for (final route in routes) ...[
        (route, parent),
        ..._allOf(route.children, route.name),
      ],
    ];

/// Finds the calls of [name], without a target or on [target].
final class _CallFinder extends RecursiveAstVisitor<void> {
  _CallFinder(this.name, {this.target});

  final String name;
  final String? target;
  final List<MethodInvocation> calls = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target?.toSource() == target && node.methodName.name == name) {
      calls.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// The declaration of the class that `createAppRouter()` creates in [unit].
ClassDeclaration _routerClassOf(CompilationUnit unit) {
  final factory = unit.declarations
      .whereType<FunctionDeclaration>()
      .singleWhere((function) => function.name.lexeme == 'createAppRouter');
  final body = factory.functionExpression.body as ExpressionFunctionBody;
  final created = (body.expression as MethodInvocation).methodName.name;
  return unit.declarations.whereType<ClassDeclaration>().singleWhere(
        (declaration) => declaration.namePart.typeName.lexeme == created,
      );
}

/// The source of the body of the method [name] of [declaration].
String _bodyOf(ClassDeclaration declaration, String name) =>
    declaration.body.members
        .whereType<MethodDeclaration>()
        .singleWhere((method) => method.name.lexeme == name)
        .body
        .toSource();

/// The files of the provider of the app entry in the app of [result] that
/// import the file of the router role with `appRouter`: where the app runs
/// the router, whichever module provides the app entry.
Set<String> _runningTheRouter(ContractResult result) {
  final entry = {
    for (final module in result.resolution!.providersOf(appEntryRole))
      module.id,
  };
  const app = 'package:contract_app/';
  bool importsTheRouter(String path, String text) =>
      DartFileIndexer.index(path, text).imports.any(
            (import) =>
                (import.uri.startsWith(app)
                    ? 'lib/${import.uri.substring(app.length)}'
                    : Uri.parse(path).resolve(import.uri).path) ==
                RouterRole.appRouterFile,
          );
  return {
    for (final MapEntry(key: path, value: file) in result.app!.files.entries)
      if (file.owner case ModuleOrigin(:final module)
          when entry.contains(module) &&
              path.endsWith('.dart') &&
              importsTheRouter(path, file.text))
        path,
  };
}

void main() {
  const module = GoRouterModule();

  group('GoRouterModule', () {
    test('is infrastructure that provides the router', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('go_router'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {routerRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(testModules), isEmpty);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(testModules)).checkAll();
    });

    test(
        'builds the apps with the router, its features and observers, and '
        'without them', () {
      // The app of go_router and of the router role by go_router is the app
      // of flutter_core with the router, or with the layout too, which
      // requires the router.
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router',
        'flutter_core',
        'go_router with layout',
        'catalog',
        'settings',
        'profile',
        'intro',
        'observing with router',
        'observing',
      ]);
    });

    test('finds no errors in any app, rendered code included', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });

    test('renders apps whose code type-checks', () async {
      for (final result in results) {
        expect(
          await analysisProblems(result.app!),
          isEmpty,
          reason: '${result.contractCase}',
        );
      }
    });
  });

  group('an app without features', () {
    late ContractResult result;
    late ContractResult resultWithout;
    late RenderedApp withRouter;
    late RenderedApp without;

    setUpAll(() async {
      result = await renderedApp(const [GoRouterModule.id]);
      withRouter = result.app!;
      resultWithout = await renderedApp(const [FlutterCoreModule.id]);
      without = resultWithout.app!;
    });

    test(
        'gets go_router, the brick of the router and its note for coding '
        'agents, and nothing else', () {
      final contributions = [
        for (final collected
            in result.collection!.ofModule(module.descriptor.id))
          collected.contribution,
      ];

      expect(contributions, hasLength(3));
      final brick = contributions.first as BrickContribution;
      expect(brick.bundle.name, 'go_router');
      final dependency = contributions[1] as PubspecDependency;
      expect(dependency.package, 'go_router');
      expect(dependency.constraint, '^17.5.0');
      expect(dependency.dev, isFalse);
      final note = contributions.last as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, routerRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
      expect(_pubspecOf(withRouter)['dependencies'], {
        'flutter': {'sdk': 'flutter'},
        'go_router': '^17.5.0',
      });
    });

    test('shows the fallback screen through the router', () {
      final unit = _factoryOf(withRouter);
      final router = _goRouterOf(unit);

      expect(
        (_argument(router, 'initialLocation')! as StringLiteral).stringValue,
        '/',
      );
      final routes = _routesOf(unit);
      expect(routes.map((route) => route.path), ['/']);
      expect(
        routes.single.builder,
        '(context, state) => const FallbackStartScreen()',
      );
      expect(routes.single.redirect, isNull);
      expect(
        withRouter.files[_factory]!.addedImports.map(
          (added) => (added.import.uri, added.import.prefix),
        ),
        [
          (
            'package:contract_app/core/app/fallback_start_screen.dart',
            null,
          ),
        ],
      );
      // No route has values to check, and no module gives an observer or a
      // listener of the screen.
      expect(withRouter.files[_factory]!.text, isNot(contains('_checkValues')));
      expect(_argument(router, 'observers')!.toSource(), '_observers()');
      expect(
        _observersOf(unit),
        '[for (final create in <NavigatorObserver Function()>[]) create()]',
      );
      _expectScreenListeners(unit, const []);
    });

    test('is run by the root of the app, which the app entry builds', () {
      // The provider of the app entry builds the root as a MaterialApp.router
      // with the router of the role when the role is present, which its own
      // tests check.
      expect(_runningTheRouter(result), isNotEmpty);
      expect(_runningTheRouter(resultWithout), isEmpty);
    });

    test(
        'is the app without a router but for the router and its section in '
        'the guide for coding agents', () {
      const routerFiles = {
        RouterRole.appRouterFile,
        RouterRole.navigationFile,
        RouterRole.appRouterFactoryFile,
      };
      expect(
        withRouter.files.keys.toSet(),
        {...without.files.keys, ...routerFiles},
      );
      expect(
        withRouter.files[_factory]!.owner,
        const ModuleOrigin(GoRouterModule.id),
      );
      // The files of the app entry that run the router change with it.
      final running = _runningTheRouter(result);
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        if (path == 'pubspec.yaml' ||
            path == AppEntryRole.agentsFile ||
            running.contains(path)) {
          continue;
        }
        expect(withRouter.files[path]!.bytes, file.bytes, reason: path);
      }
      final pubspec = _pubspecOf(withRouter);
      final dependencies = {
        ...pubspec['dependencies']! as Map<String, Object?>,
      }..remove('go_router');
      expect({...pubspec, 'dependencies': dependencies}, _pubspecOf(without));
      // The guide has the notes of the app without a router, and those of
      // the router under the heading of the role.
      final notes = withRouter.entriesOf(AppEntryRole.agentSections);
      expect(
        notes.where((note) => !_router.contains(note.$1)),
        without.entriesOf(AppEntryRole.agentSections),
      );
      expect(
        [
          for (final (origin, heading, note) in notes)
            if (_router.contains(origin)) (origin, heading, note.isOfRole),
        ],
        [
          (
            const ModuleOrigin(GoRouterModule.id),
            routerRole.description,
            false,
          ),
          (const RoleTemplateOrigin(routerRole), routerRole.description, true),
        ],
      );
      expect(_notesOfModule(withRouter), [AgentNote(agentNote)]);
    });
  });

  group('an app with features', () {
    late ContractResult result;
    late RenderedApp app;
    late CompilationUnit unit;
    late Map<String, _GoRoute> routes;

    setUpAll(() async {
      result = await renderedApp(const [
        CatalogFeature.id,
        SettingsFeature.id,
        ObservingModule.id,
      ]);
      app = result.app!;
      unit = _factoryOf(app);
      routes = {
        for (final (route, _) in _allOf(_routesOf(unit)))
          if (route.name case final name?) name: route,
      };
    });

    test('opens on the start route, which / redirects to', () {
      expect(
        (_argument(_goRouterOf(unit), 'initialLocation')! as StringLiteral)
            .stringValue,
        '/catalog',
      );
      final root = _routesOf(unit).first;
      expect(root.path, '/');
      expect(root.name, isNull);
      expect(root.redirect, "(context, state) => '/catalog'");
      expect(root.builder, isNull);
    });

    test(
        'has a route for every route of the facade, named by its full name, '
        'with its children below it', () {
      final facade = routerRole.facadeOf(routerRole.hookInput(result.hook!));
      final parents = {
        for (final (route, parent) in _allOf(_routesOf(unit)))
          if (route.name case final name?) name: parent,
      };

      expect(
        parents.keys,
        [for (final route in facade.routes) route.fullName],
      );
      for (final route in facade.routes) {
        final goRoute = routes[route.fullName]!;
        expect(parents[route.fullName], route.parent?.fullName);
        expect(
          goRoute.path,
          route.parent == null ? route.fullPath : route.route.path,
          reason: route.fullName,
        );
      }
      expect(routes.keys, containsAll(['catalog.review', 'settings.settings']));
    });

    test('imports each file of screens once, with a prefix of its own', () {
      final screens = {
        for (final added in app.files[_factory]!.addedImports)
          if (added.import.uri.contains('/features/'))
            added.import.uri: added.import.prefix,
      };

      expect(screens, {
        'package:contract_app/features/catalog/catalog_screen.dart': 'screen0',
        'package:contract_app/features/catalog/item_screen.dart': 'screen1',
        'package:contract_app/features/catalog/review_screen.dart': 'screen2',
        'package:contract_app/features/catalog/more_screens.dart': 'screen3',
        'package:contract_app/features/settings/settings_screen.dart':
            'screen4',
        'package:contract_app/features/settings/about_screen.dart': 'screen5',
      });
      expect(
        {
          for (final added in app.files[_factory]!.addedImports)
            added.import.uri: '${added.contributor}',
        },
        {
          for (final screen in screens.keys) screen: 'go_router',
          // The factory of the observer comes with its import.
          'package:contract_app/core/observing/test_observer.dart': 'observing',
        },
      );
      expect(routes['catalog.tag']!.builder, contains('screen3.TagScreen('));
      expect(
        routes['settings.settings']!.builder,
        '(context, state) => const screen4.SettingsScreen()',
      );
    });

    test(
        'passes optional int, double and bool query parameters as nullable '
        'values', () {
      // A value that the location does not have, or that is not of its
      // type, is null.
      expect(routes['catalog.catalog']!.screenArguments, {
        'page': "int.tryParse(state.uri.queryParameters['page'] ?? '')",
        'minPrice':
            "double.tryParse(state.uri.queryParameters['minPrice'] ?? '')",
        'onSale': "bool.tryParse(state.uri.queryParameters['onSale'] ?? '')",
        'search': "state.uri.queryParameters['search']",
      });
      expect(routes['catalog.catalog']!.redirect, isNull);
    });

    test('checks the required values of a location before the screen', () {
      expect(
        routes['catalog.compare']!.redirect,
        [
          '(context, state) => _checkValues({',
          "'left' : int.tryParse(state.uri.queryParameters['left'] ?? ''), ",
          "'right' : int.tryParse(state.uri.queryParameters['right'] ?? '')})",
        ].join(),
      );
      expect(routes['catalog.compare']!.screenArguments, {
        'left': "int.tryParse(state.uri.queryParameters['left'] ?? '')!",
        'right': "int.tryParse(state.uri.queryParameters['right'] ?? '')!",
      });
      expect(routes['catalog.price']!.screenArguments, {
        'amount': "double.tryParse(state.pathParameters['amount'] ?? '')!",
        'exact': "bool.tryParse(state.pathParameters['exact'] ?? '')!",
      });
      expect(routes['catalog.price']!.redirect, contains("'amount' :"));
      expect(routes['catalog.price']!.redirect, contains("'exact' :"));
      // A path always has its String parameters.
      expect(routes['catalog.tag']!.redirect, isNull);
      expect(routes['catalog.tag']!.screenArguments, {
        'tag': "state.pathParameters['tag']!",
      });

      // A query may leave out a String too.
      expect(
        routes['catalog.search']!.redirect,
        "(context, state) => _checkValues({'q' : "
        "state.uri.queryParameters['q']})",
      );
      expect(routes['catalog.search']!.screenArguments, {
        'q': "state.uri.queryParameters['q']!",
      });

      final checks = unit.declarations
          .whereType<FunctionDeclaration>()
          .singleWhere((function) => function.name.lexeme == '_checkValues');
      expect(checks.toSource(), _expectedCheckValues);
    });

    test('reads a path parameter of the parent from the path', () {
      // The redirect of the parent checks it, since go_router runs the
      // redirect of every route that matches the location.
      expect(routes['catalog.item']!.redirect, contains("'id' :"));
      expect(routes['catalog.review']!.redirect, isNull);
      expect(routes['catalog.review']!.screenArguments, {
        'id': "int.tryParse(state.pathParameters['id'] ?? '')!",
        'reviewId': "state.pathParameters['reviewId']!",
      });
      expect(routes['catalog.item']!.screenArguments, {
        'id': "int.tryParse(state.pathParameters['id'] ?? '')!",
        'variant': "state.uri.queryParameters['variant']",
      });
    });

    test('creates the observers of the router role for its navigator', () {
      final observers = _argument(_goRouterOf(unit), 'observers')!;

      // Every call creates instances of its own.
      expect(observers.toSource(), '_observers()');
      expect(
        _observersOf(unit),
        '[for (final create in <NavigatorObserver Function()>[() => '
        'TestObserver()]) create()]',
      );
    });

    test(
        'tells the listeners of the router role about the page on top when '
        'it changes', () {
      _expectScreenListeners(unit, const [ObservingModule.listener]);
      // The listener comes with the import of its module, which the file
      // has once, as the observer of the module needs it too.
      const file = 'package:contract_app/core/observing/test_observer.dart';
      expect(
        [
          for (final added in app.files[_factory]!.addedImports)
            if (added.contributor == const ModuleOrigin(ObservingModule.id))
              added.import.uri,
        ],
        [file, file],
      );
      expect(
        [
          for (final directive in unit.directives.whereType<ImportDirective>())
            if (directive.uri.stringValue == file) directive.toSource(),
        ],
        ["import '$file';"],
      );
    });

    test(
        'lets each push complete with the value of its page, whatever '
        'completer go_router gives the page', () {
      // go_router completes push() with the completer that it gives the
      // page it pushed, and gives the page a new one when it shows its
      // pages anew, as on refresh(): the router passes on its value.
      _expectPushResults(unit);
    });

    test('has no main navigation without a layout', () {
      expect(_shellOf(unit), isNull);
      // Nor what replaces one: go_router gets the routes themselves.
      expect(_goRouterOf(unit).target, isNull);
      expect(_fieldOf(unit, '_routes'), isNull);
      for (final name in _expectedRenewalMembers.keys) {
        expect(app.files[_factory]!.text, isNot(contains(name)), reason: name);
      }
      // Only `_GoRouter` puts them into a `RoutingConfig`, which a class
      // that extends `GoRouter` hands to it.
      expect(
        _routerClassOf(unit).toSource(),
        isNot(contains('RoutingConfig')),
      );
      expect(
        app.files[_factory]!.addedImports.map((added) => added.import.uri),
        isNot(contains(contains('/core/layout/'))),
      );
      // Nor a note of the module about its destinations.
      expect(_notesOfModule(app), [AgentNote(agentNote)]);
    });

    test(
        'has what the note of the module for coding agents names: the '
        'router, its routes and the listeners of the screen', () {
      final index = DartFileIndexer.index(_factory, app.files[_factory]!.text);
      bool calls(String name, List<String> arguments) => index
          .invocationsOf(name)
          .any((call) => arguments.every(call.namedArguments.contains));

      // The one GoRouter, the config of the router of the app, which the
      // file creates as a `_GoRouter`, a class of its own that extends it.
      expect(index.invocationsOf('GoRouter'), isEmpty);
      expect(index.invocationsOf('_GoRouter'), hasLength(1));
      expect(calls('_GoRouter', ['initialLocation', 'routes']), isTrue);
      expect(
        _fieldOf(unit, 'config')!.fields.type!.toSource(),
        'GoRouter',
      );
      expect(
        index.declaration('_GoAppRouter')!.members.map((member) => member.name),
        contains('config'),
      );
      // A route, with its children in its routes.
      expect(calls('GoRoute', ['path', 'name', 'builder']), isTrue);
      expect(calls('GoRoute', ['path', 'name', 'builder', 'routes']), isTrue);
      expect(index.imports.map((import) => import.prefix), contains('screen0'));
      // The values of a route.
      expect(
        [
          for (final access in index.memberAccesses)
            '${access.target}.${access.name}',
        ],
        containsAll(['state.pathParameters', 'state.uri.queryParameters']),
      );
      expect(index.invocationsOf('tryParse'), isNotEmpty);
      // A required value that is missing or does not parse: the redirect of
      // the route throws a GoException.
      expect(calls('GoRoute', ['path', 'name', 'builder', 'redirect']), isTrue);
      expect(
        {
          for (final call in index.invocationsOf('GoException'))
            call.enclosingDeclaration,
        },
        {'_checkValues'},
      );
      expect(
        index.declaration('_screenListeners')?.kind,
        DeclarationKind.variable,
      );
      for (final name in const [
        'GoRouter',
        'GoRoute',
        'routes',
        'path',
        'name',
        'state.pathParameters',
        'state.uri.queryParameters',
        'tryParse',
        'GoException',
        'redirect',
        'initialLocation',
        '_screenListeners',
      ]) {
        expect(agentNote, contains('`$name`'), reason: name);
      }
      expect(agentNote, contains('`${RouterRole.appRouterFactoryFile}`'));
      // Only the file of the router imports go_router, as the note of the
      // role asks of the code of the app.
      expect(
        [
          for (final file in app.files.values)
            if (file.isText && file.text.contains('package:go_router/'))
              file.path,
        ],
        [_factory],
      );
    });

    test('navigates through the router it created once, whatever the context',
        () {
      final router = _routerClassOf(unit);

      expect(router.namePart.typeName.lexeme, isNot('AppRouter'));
      final config =
          router.body.members.whereType<FieldDeclaration>().singleWhere(
                (field) =>
                    field.fields.variables.single.name.lexeme == 'config',
              );
      expect(config.fields.isLate, isTrue);
      expect(config.fields.isFinal, isTrue);
      expect(_bodyOf(router, 'navigatorOf'), '=> this;');
      expect(_bodyOf(router, 'go'), '=> config.go(location.path);');
      // Without a main navigation, nothing to check first.
      expect(
        _bodyOf(router, 'push'),
        '{return config.push<T>(location.path);}',
      );
      expect(
        _bodyOf(router, 'replace'),
        '{config.pushReplacement<Object?>(location.path);}',
      );
      expect(app.files[_factory]!.text, isNot(contains('GoRouter.of(')));
      expect(
        app.files[_factory]!.text,
        isNot(contains('_checkMainNavigation')),
      );
    });

    test(
        'asks go_router to close the route on top only while go_router has a '
        'page, so that the back button of the system throws nothing on its '
        'error screen', () {
      _expectBackButton(unit, _constructorOfRoutes);
    });

    test('asks no guards in an app without guards', () {
      final router = _routerClassOf(unit);

      expect(_argument(_goRouterOf(unit), 'redirect'), isNull);
      expect(
        router.body.members.map(_nameOf),
        isNot(containsAll(_expectedGuardMembers.keys)),
      );
      for (final name in _expectedGuardMembers.keys) {
        expect(router.body.members.map(_nameOf), isNot(contains(name)));
      }
      expect(_shownOfTheRole(unit), ['AppNavigator', 'AppRouter']);
      for (final name in [
        RouterRole.guardedNavigation,
        RouterRole.redirectOf,
        RouterRole.guardChanges,
      ]) {
        expect(app.files[_factory]!.text, isNot(contains(name)));
      }
    });
  });

  group('an app with guards', () {
    late ContractResult result;
    late RenderedApp app;
    late CompilationUnit unit;

    setUpAll(() async {
      result = await renderedApp(const [CatalogFeature.id, IntroFeature.id]);
      app = result.app!;
      unit = _factoryOf(app);
    });

    test('has the guards of its features, which the router role generates', () {
      final facade = routerRole.facadeOf(routerRole.hookInput(result.hook!));

      expect(
        [for (final guard in facade.guards) guard.fullName],
        ['intro.firstRun'],
      );
      // With the class through which it asks them, the answers that it
      // tells apart, and the listenable of their changes.
      expect(
        _shownOfTheRole(unit),
        [
          'AppNavigator',
          'AppRouter',
          'ClosePages',
          RouterRole.guardedNavigation,
          'ShowInstead',
          'ShowNothing',
          'ShowOver',
          RouterRole.guardChanges,
        ],
      );
    });

    test(
        'asks the guards in the redirect of go_router about the locations '
        'that go_router parses, as the one it starts on and those of the '
        'platform, with no pages', () {
      final router = _goRouterOf(unit);

      expect(
        _argument(router, 'redirect')!.toSource(),
        '(context, state) => '
        r"_redirect(state.topRoute?.name, '${state.uri}')",
      );
      // Such a location takes the place of the stack, so the guards are
      // told of no pages. The redirect runs within the calls of the router
      // too, for a location that the guards let the user see or that they
      // answered: they answer nothing for it a second time.
      expect(
        _expectedGuardMembers['_redirect'],
        contains('_guards.asked(route, location, onTopOf: const [])'),
      );
      // The location that the app opens with is the start route, which the
      // redirect is asked about like any other.
      expect(
        (_argument(router, 'initialLocation')! as StringLiteral).stringValue,
        '/catalog',
      );
    });

    test(
        'asks the guards before go(), push() and replace() hand a location '
        'to go_router, and keeps a push that waits for a flow from '
        'completing', () {
      final router = _routerClassOf(unit);

      expect(
        _bodyOf(router, 'go'),
        '{if (_redirected(location, again: () => go(location))) return; '
        'config.go(location.path);}',
      );
      expect(
        _bodyOf(router, 'push'),
        '{final waiting = Completer<T?>(); if (_redirected(location, again: '
        '() => waiting.complete(push<T>(location)), drop: waiting.complete)) '
        '{return waiting.future;} return config.push<T>(location.path);}',
      );
      expect(
        _bodyOf(router, 'replace'),
        '{if (_redirected(location, again: () => replace(location))) '
        'return; config.pushReplacement<Object?>(location.path);}',
      );
    });

    test(
        'listens to the guards itself, tells the role of its pages once it '
        'has shown its first location, and does what the role answers: it '
        'goes to a location, opens a flow over the page on top and keeps '
        'the request waiting, or closes pages and makes the request again', () {
      final router = _routerClassOf(unit);
      final members = {
        for (final member in router.body.members)
          _nameOf(member): member.toSource(),
      };

      expect(_expectedGuardMembers.keys, [
        '_GoAppRouter',
        '_guards',
        '_waiting',
        '_opening',
        '_muted',
        '_quietly',
        '_redirect',
        '_redirected',
        '_open',
        '_drop',
        '_close',
        '_shows',
        '_pages',
        '_guardsChanged',
      ]);
      for (final MapEntry(key: name, value: source)
          in _expectedGuardMembers.entries) {
        expect(members[name], source, reason: name);
      }
      // A refresh of go_router asks only about the location below the
      // pushed pages, and gives each pushed page a new completer, so the
      // router does not hand the guards to go_router to listen to.
      expect(_argument(_goRouterOf(unit), 'refreshListenable'), isNull);
      // It closes pages with one restore() of the pages of go_router
      // without them, never with pop(), which closes what the navigator
      // shows on top, such as a dialog over the page.
      final index = DartFileIndexer.index(_factory, app.files[_factory]!.text);
      expect(
        [
          for (final call in index.invocationsOf('restore'))
            '${call.target}.restore in ${call.enclosingMember}',
        ],
        ['config.restore in _close'],
      );
      expect(index.invocationsOf('pop'), isEmpty);
      // It completes the pushes of the pages that it closed once the frame
      // is over: until its next build the navigator has their routes, and
      // go_router completes the push of one that is popped in that time.
      expect(
        [
          for (final call in index.invocationsOf('addPostFrameCallback'))
            '${call.target}.addPostFrameCallback in ${call.enclosingMember}',
        ],
        ['WidgetsBinding.instance.addPostFrameCallback in _close'],
      );
    });

    test('still lets each push complete with the value of its page', () {
      _expectPushResults(unit);
    });

    test(
        'still keeps the back button of the system from go_router while it '
        'has no page, with a router that takes the redirect of the guards', () {
      _expectBackButton(unit, _constructorOfGuardedRoutes);
    });

    test('renders code that type-checks, with a main navigation too', () async {
      expect(await analysisProblems(app), isEmpty);

      final withLayout = await renderedApp(const [
        CatalogFeature.id,
        SettingsFeature.id,
        IntroFeature.id,
        TabsLayout.id,
      ]);
      final unit = _factoryOf(withLayout.app!);
      final router = _routerClassOf(unit);
      final members = {
        for (final member in router.body.members)
          _nameOf(member): member.toSource(),
      };
      // The redirect that asks the guards is with the routes that go_router
      // follows, and stays when the router replaces the main navigation.
      expect(_argument(_goRouterOf(unit), 'redirect'), isNull);
      _expectBackButton(unit, _constructorOfRoutingConfig);
      expect(
        _argument(_routingOf(unit), 'redirect')!.toSource(),
        '(context, state) => '
        r"_redirect(state.topRoute?.name, '${state.uri}')",
      );
      // As everything else that the configuration has.
      for (final MapEntry(key: name, value: source)
          in _expectedRenewalMembers.entries) {
        expect(members[name], source, reason: name);
      }
      for (final kept in ['onEnter', 'redirect', 'redirectLimit']) {
        expect(
          _expectedRenewalMembers['_renewMainNavigation'],
          contains('$kept: routes.$kept'),
        );
      }
      _expectPagesChanged(unit);
      // The guards come first: while a gate keeps the user out, the main
      // navigation is not shown.
      expect(
        _bodyOf(router, 'push'),
        '{final waiting = Completer<T?>(); if (_redirected(location, again: '
        '() => waiting.complete(push<T>(location)), drop: waiting.complete)) '
        "{return waiting.future;} _checkMainNavigation(location, 'push'); "
        'return config.push<T>(location.path);}',
      );
      expect(
        _bodyOf(router, 'replace'),
        '{if (_redirected(location, again: () => replace(location))) '
        "return; _checkMainNavigation(location, 'replace'); "
        'config.pushReplacement<Object?>(location.path);}',
      );
      expect(await analysisProblems(withLayout.app!), isEmpty);
    });

    test('keeps the target of a guard outside the main navigation', () async {
      final withLayout = await renderedApp(const [
        CatalogFeature.id,
        IntroFeature.id,
        TabsLayout.id,
      ]);
      final unit = _factoryOf(withLayout.app!);

      expect(
        [
          for (final branch in _branchesOf(_shellOf(unit)!))
            branch.initialLocation,
        ],
        ['/catalog'],
      );
      expect(
        [for (final route in _routesOf(unit)) route.path],
        containsAllInOrder(['/', '/intro']),
      );
    });
  });

  group('an app with a layout', () {
    late ContractResult result;
    late RenderedApp app;
    late CompilationUnit unit;
    late MethodInvocation shell;

    setUpAll(() async {
      result = await renderedApp(const [
        CatalogFeature.id,
        SettingsFeature.id,
        ObservingModule.id,
        TabsLayout.id,
      ]);
      app = result.app!;
      unit = _factoryOf(app);
      shell = _shellOf(unit)!;
    });

    test(
        'puts the destinations into a shell of branches right after /, and '
        'the other routes after it', () {
      final topLevel = _topLevelOf(unit);

      expect((topLevel.first as MethodInvocation).methodName.name, 'GoRoute');
      // The field with the shell, in which the router puts a new one for a
      // new main navigation.
      expect(topLevel[1].toSource(), '_mainNavigationRoute');
      expect(shell.methodName.name, 'indexedStack');
      expect(
        [for (final route in _routesOf(unit)) route.path],
        [
          '/',
          '/catalog/compare',
          '/catalog/prices/:amount/:exact',
          '/catalog/tags/:tag',
          '/catalog/search',
        ],
      );
      // The route that the router matches first is in the shell.
      expect(
        _routesOf(unit).first.redirect,
        "(context, state) => '/catalog'",
      );
    });

    test(
        'keeps its routes in a RoutingConfig that go_router follows, so that '
        'it can replace the main navigation among them', () {
      final router = _goRouterOf(unit);

      expect(router.target!.toSource(), '_GoRouter');
      expect(router.methodName.name, 'routingConfig');
      // Which passes them on to go_router as they are.
      _expectBackButton(unit, _constructorOfRoutingConfig);
      expect(_argument(router, 'routingConfig')!.toSource(), '_routes');
      expect(_argument(router, 'routes'), isNull);
      expect(_argument(router, 'redirect'), isNull);
      final routes = _fieldOf(unit, '_routes')!.fields;
      expect(routes.isLate, isTrue);
      expect(routes.isFinal, isTrue);
      expect(routes.type!.toSource(), 'ValueNotifier<RoutingConfig>');
      final holder = routes.variables.single.initializer! as MethodInvocation;
      expect(holder.methodName.name, 'ValueNotifier');
      expect(holder.argumentList.arguments.single, _routingOf(unit));
      // Without guards, the routes are all that the configuration has.
      expect(
        [
          for (final argument in _routingOf(unit).argumentList.arguments)
            (argument as NamedArgument).name.lexeme,
        ],
        ['routes'],
      );
    });

    test(
        'gives go_router a new route for the main navigation once the main '
        'navigation has left its pages, and the other routes as they are', () {
      final members = {
        for (final member in _routerClassOf(unit).body.members)
          _nameOf(member): member.toSource(),
      };

      expect(_expectedRenewalMembers.keys, [
        '_mainNavigationRoute',
        '_mainNavigationShown',
        '_renewing',
        '_renewMainNavigation',
      ]);
      for (final MapEntry(key: name, value: source)
          in _expectedRenewalMembers.entries) {
        expect(members[name], source, reason: name);
      }
      // First of all when the pages change, so that the next location that
      // go_router is asked for matches the new route.
      _expectPagesChanged(unit);
      // What a branch has of its own comes from the function, in each call.
      final index = DartFileIndexer.index(_factory, app.files[_factory]!.text);
      expect(
        {
          for (final call in index.invocationsOf('StatefulShellBranch'))
            call.enclosingDeclaration,
        },
        {'_mainNavigation'},
      );
      // Which the field of the route calls once, and the router for each
      // new one.
      expect(index.invocationsOf('_mainNavigation'), hasLength(2));
    });

    test(
        'tells coding agents where the destinations are, with the names '
        'that its file has', () {
      expect(
        _notesOfModule(app),
        [AgentNote(agentNote), AgentNote(mainNavigationAgentNote)],
      );
      // The second is a note of the render hook of the module: in the
      // guide, it follows the first in the section of the router.
      expect(
        app.files[AppEntryRole.agentsFile]!.text,
        contains('${agentNote.trim()}\n\n${mainNavigationAgentNote.trim()}\n'),
      );

      final index = DartFileIndexer.index(_factory, app.files[_factory]!.text);
      final shellCall = index.invocationsOf('indexedStack').single;
      expect(shellCall.target, 'StatefulShellRoute');
      final branches = index.invocationsOf('StatefulShellBranch');
      expect(branches, hasLength(_branchesOf(shell).length));
      for (final branch in branches) {
        expect(branch.namedArguments, contains('observers'));
      }
      expect(index.declaration('_observers')?.kind, DeclarationKind.function);
      // The shell, with the list of the destinations of the layout role,
      // which the file of the role declares with a destination for each
      // branch.
      final appShell = index.invocationsOf(LayoutRole.appShell.name).single;
      expect(appShell.namedArguments, contains('destinations'));
      expect(
        index.references.map((reference) => reference.name),
        contains(LayoutRole.appDestinations),
      );
      final ofLayout = DartFileIndexer.index(
        LayoutRole.destinationFile,
        app.files[LayoutRole.destinationFile]!.text,
      );
      expect(
        ofLayout.declaration(LayoutRole.appDestinations)?.kind,
        DeclarationKind.variable,
      );
      expect(
        ofLayout.invocationsOf(LayoutRole.destination.name),
        hasLength(branches.length),
      );
      // The function that creates the shell, which the list of the routes
      // calls.
      expect(
        index.declaration('_mainNavigation')?.kind,
        DeclarationKind.function,
      );
      expect(shellCall.enclosingDeclaration, '_mainNavigation');
      for (final name in [
        'StatefulShellRoute.indexedStack',
        '_mainNavigation()',
        '_mainNavigationRoute',
        'routes',
        'StatefulShellBranch',
        'observers: _observers()',
        'destinations',
        LayoutRole.appShell.name,
        LayoutRole.destination.name,
        LayoutRole.appDestinations,
        LayoutRole.destinationFile,
      ]) {
        expect(mainNavigationAgentNote, contains('`$name`'), reason: name);
      }
    });

    test(
        'has the main navigation that the note for an app without a '
        'destination tells to write for the first one', () {
      // This app has destinations, so it has no such note.
      expect(
        _notesOfModule(app),
        isNot(contains(AgentNote(firstDestinationAgentNote))),
      );
      final index = DartFileIndexer.index(_factory, app.files[_factory]!.text);
      final shellCall = index.invocationsOf('indexedStack').single;
      expect(shellCall.target, 'StatefulShellRoute');
      expect(
        shellCall.namedArguments,
        containsAll(['notifyRootObserver', 'builder', 'branches']),
      );
      expect(
        index.invocationsOf('StatefulShellBranch').first.namedArguments,
        contains('observers'),
      );
      expect(
        index.invocationsOf(LayoutRole.appShell.name).single.namedArguments,
        LayoutRole.appShell.namedParameters,
      );
      final text = app.files[_factory]!.text;
      expect(text, contains('currentIndex: shell.currentIndex,'));
      expect(text, contains('onSelect: shell.goBranch,'));
      expect(text, contains('body: shell,'));
      // push() and replace() check the main navigation, and the check
      // throws the error that the layout role names.
      expect(
        [
          for (final call in index.invocationsOf('_checkMainNavigation'))
            call.enclosingMember,
        ],
        ['push', 'replace'],
      );
      expect(text, contains('throw StateError('));
      // The routes that go_router follows, among which the router replaces
      // the main navigation.
      expect(
        index.invocationsOf('routingConfig').single.target,
        '_GoRouter',
      );
      expect(text, contains('ValueNotifier<RoutingConfig>'));
      // Which the constructor of that class passes on to go_router.
      _expectBackButton(unit, _constructorOfRoutingConfig);
      // And the pages that go_router had, which the router puts back.
      expect(
        [
          for (final call in index.invocationsOf('restore'))
            '${call.target}.restore in ${call.enclosingMember}',
        ],
        ['config.restore in _renewMainNavigation'],
      );
      for (final name in [
        'StatefulShellRoute.indexedStack',
        '_GoRouter',
        'GoRouter.routingConfig',
        'ValueNotifier<RoutingConfig>',
        'restore()',
        'notifyRootObserver: false',
        'StatefulShellBranch',
        'observers: _observers()',
        'builder',
        LayoutRole.appShell.name,
        LayoutRole.appDestinations,
        LayoutRole.destinationFile,
        'shell.currentIndex',
        'shell.goBranch',
        'body',
        'push()',
        'replace()',
        'StateError',
      ]) {
        expect(firstDestinationAgentNote, contains('`$name`'), reason: name);
      }
      // The list of the role, which the shell gets as its destinations.
      expect(text, contains('destinations: ${LayoutRole.appDestinations},'));
    });

    test('has a branch for each destination, with the routes below it', () {
      final branches = _branchesOf(shell);

      expect(
        [for (final branch in branches) branch.initialLocation],
        ['/catalog', '/settings'],
      );
      final catalog = branches[0].routes.single;
      expect(catalog.path, '/catalog');
      expect(catalog.name, 'catalog.catalog');
      expect(
        [
          for (final (route, parent) in _allOf([catalog]))
            '$parent > ${route.name} (${route.path})',
        ],
        [
          'null > catalog.catalog (/catalog)',
          'catalog.catalog > catalog.item (items/:id)',
          'catalog.item > catalog.review (reviews/:reviewId)',
        ],
      );
      final settings = branches[1].routes.single;
      expect(settings.path, '/settings');
      expect(
        [for (final child in settings.children) child.name],
        ['settings.about'],
      );
    });

    test(
        'shows the shell of the layout with the destinations that the layout '
        'role generates, and renders neither their labels nor their icons', () {
      expect(
        _argument(shell, 'builder')!.toSource(),
        '(context, state, shell) => AppShell(destinations: appDestinations, '
        'currentIndex: shell.currentIndex, onSelect: shell.goBranch, body: '
        'shell)',
      );
      // The list of the role, and no icons, which the features give the
      // layout role with the labels.
      expect(
        {
          for (final added in app.files[_factory]!.addedImports)
            if (!added.import.uri.contains('/features/'))
              added.import.uri: 'show ${added.import.show.join(', ')} for '
                  '${added.contributor}',
        },
        {
          'package:contract_app/core/layout/app_shell.dart':
              'show AppShell for go_router',
          'package:contract_app/core/layout/destination.dart':
              'show appDestinations for go_router',
          'package:contract_app/core/observing/test_observer.dart':
              'show  for observing',
        },
      );
      // The list has the destinations in the order of the branches.
      expect(
        [
          for (final route
              in layoutRole.destinationsIn(layoutRole.hookInput(result.hook!)))
            route.fullPath,
        ],
        [for (final branch in _branchesOf(shell)) branch.initialLocation],
      );
    });

    test(
        'gives each navigator observers of its own, and the root navigator '
        'none of the branches', () {
      expect(_argument(shell, 'notifyRootObserver')!.toSource(), 'false');
      expect(
        [for (final branch in _branchesOf(shell)) branch.observers],
        ['_observers()', '_observers()'],
      );
      expect(
        _argument(_goRouterOf(unit), 'observers')!.toSource(),
        '_observers()',
      );
      expect(
        _observersOf(unit),
        '[for (final create in <NavigatorObserver Function()>[() => '
        'TestObserver()]) create()]',
      );
    });

    test(
        'tells the listeners of the screen about the page on top of every '
        'navigator, the branches included, with one list', () {
      // The delegate of go_router hears of a switch of branches, which no
      // navigator observer sees, so the listeners hear of it too.
      _expectScreenListeners(unit, const [ObservingModule.listener]);
    });

    test(
        'lets each push complete with the value of its page, in the stacks '
        'of the main navigation too', () {
      // A page pushed in a branch is among the matches of the shell of the
      // main navigation.
      _expectPushResults(unit);
    });

    test(
        'lets push() and replace() show a location of the main navigation '
        'only on top of it', () {
      final router = _routerClassOf(unit);

      expect(
        _bodyOf(router, 'push'),
        "{_checkMainNavigation(location, 'push'); return "
        'config.push<T>(location.path);}',
      );
      expect(
        _bodyOf(router, 'replace'),
        "{_checkMainNavigation(location, 'replace'); "
        'config.pushReplacement<Object?>(location.path);}',
      );
      expect(
        router.body.members
            .whereType<MethodDeclaration>()
            .singleWhere(
              (method) => method.name.lexeme == '_checkMainNavigation',
            )
            .toSource(),
        _expectedCheckMainNavigation,
      );
    });

    test('renders code that type-checks', () async {
      expect(await analysisProblems(app), isEmpty);
    });

    test('orders the branches as the features were asked for', () async {
      final result = await renderedApp(
        const [
          SettingsFeature.id,
          ProfileFeature.id,
          CatalogFeature.id,
          TabsLayout.id,
        ],
        roleOptions: {RouterRole.startOption.name: '/catalog'},
      );
      final shell = _shellOf(_factoryOf(result.app!))!;

      expect(
        [for (final branch in _branchesOf(shell)) branch.initialLocation],
        ['/settings', '/profile', '/catalog'],
      );
      // As the destinations of the list that the shell gets, which the
      // layout role generates from the same routes.
      expect(
        [
          for (final route
              in layoutRole.destinationsIn(layoutRole.hookInput(result.hook!)))
            route.fullPath,
        ],
        ['/settings', '/profile', '/catalog'],
      );
      expect(
        _argument(shell, 'builder')!.toSource(),
        contains('destinations: appDestinations,'),
      );
    });

    test('starts on the branch of the start route, which --start chooses',
        () async {
      // Two routes can start the app, so the choice needs --start, or an
      // answer to the question of the router.
      const modules = [
        CatalogFeature.id,
        SettingsFeature.id,
        ProfileFeature.id,
        TabsLayout.id,
      ];
      final answered = await renderedApp(modules);
      expect(answered.answers, {RouterRole.startOption.name: '/catalog'});
      expect(
        (_argument(_goRouterOf(_factoryOf(answered.app!)), 'initialLocation')!
                as StringLiteral)
            .stringValue,
        '/catalog',
      );

      final result = await renderedApp(
        modules,
        roleOptions: {RouterRole.startOption.name: '/profile'},
      );
      final unit = _factoryOf(result.app!);
      final shell = _shellOf(unit)!;

      expect(
        (_argument(_goRouterOf(unit), 'initialLocation')! as StringLiteral)
            .stringValue,
        '/profile',
      );
      expect(
        _routesOf(unit).first.redirect,
        "(context, state) => '/profile'",
      );
      // The third branch, whose destination is the start route.
      final branches = _branchesOf(shell);
      expect(branches[2].initialLocation, '/profile');
      expect(branches[2].routes.single.name, 'profile.profile');
      expect(await analysisProblems(result.app!), isEmpty);
    });

    test('shows the shell with one destination too', () async {
      final result = await renderedApp(
        const [CatalogFeature.id, TabsLayout.id],
      );
      final shell = _shellOf(_factoryOf(result.app!))!;

      expect(
        [for (final branch in _branchesOf(shell)) branch.initialLocation],
        ['/catalog'],
      );
      expect(
        _argument(shell, 'builder')!.toSource(),
        contains('destinations: appDestinations,'),
      );
      expect(await analysisProblems(result.app!), isEmpty);
    });

    test('has no shell without destinations', () async {
      final result = await renderedApp(const [TabsLayout.id]);
      final unit = _factoryOf(result.app!);

      expect(_shellOf(unit), isNull);
      // The file has no main navigation to add a destination to, and no
      // check of it in push() and replace(), so the module tells in the
      // guide what the first destination needs.
      expect(
        _notesOfModule(result.app!),
        [AgentNote(agentNote), AgentNote(firstDestinationAgentNote)],
      );
      final index = DartFileIndexer.index(
        _factory,
        result.app!.files[_factory]!.text,
      );
      expect(index.invocationsOf('indexedStack'), isEmpty);
      expect(index.invocationsOf('_checkMainNavigation'), isEmpty);
      expect(index.invocationsOf('_renewMainNavigation'), isEmpty);
      expect(_goRouterOf(unit).target, isNull);
      // The router takes the routes themselves, in the constructor that
      // the note tells to give the routes that go_router follows instead.
      _expectBackButton(unit, _constructorOfRoutes);
      expect(
        firstDestinationAgentNote,
        contains('The constructor of `_GoRouter` then takes that notifier'),
      );
      expect(index.declaration('_observers')?.kind, DeclarationKind.function);
      expect(_routesOf(unit).map((route) => route.path), ['/']);
      expect(
        result.app!.files[_factory]!.addedImports.map(
          (added) => added.import.uri,
        ),
        isNot(contains(contains('/core/layout/'))),
      );
    });
  });

  group('the start of an app', () {
    test('is the fallback screen when no route can start the app', () async {
      final result = await renderedApp(const [SettingsFeature.id]);
      final unit = _factoryOf(result.app!);

      final routes = _routesOf(unit);
      expect(routes.map((route) => route.path), ['/', '/settings']);
      expect(
        routes.first.builder,
        '(context, state) => const FallbackStartScreen()',
      );
    });

    test('can be a child route that --start names', () async {
      final result = await renderedApp(
        const [SettingsFeature.id],
        roleOptions: {RouterRole.startOption.name: '/settings/about'},
      );
      final unit = _factoryOf(result.app!);

      expect(
        (_argument(_goRouterOf(unit), 'initialLocation')! as StringLiteral)
            .stringValue,
        '/settings/about',
      );
      expect(
        _routesOf(unit).first.redirect,
        "(context, state) => '/settings/about'",
      );
      // go_router shows the chain of parents of the child.
      final settings = _routesOf(unit)[1];
      expect(settings.path, '/settings');
      expect(settings.children.single.path, 'about');
    });

    test('is the route that --start names', () async {
      final result = await renderedApp(
        const [CatalogFeature.id, SettingsFeature.id],
        roleOptions: {RouterRole.startOption.name: '/settings'},
      );
      final unit = _factoryOf(result.app!);

      expect(
        (_argument(_goRouterOf(unit), 'initialLocation')! as StringLiteral)
            .stringValue,
        '/settings',
      );
      expect(
        _routesOf(unit).first.redirect,
        "(context, state) => '/settings'",
      );
    });
  });
}
