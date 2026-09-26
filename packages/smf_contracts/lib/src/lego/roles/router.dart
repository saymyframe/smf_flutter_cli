import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/router_role_bundle.dart';
import 'package:smf_contracts/lego.dart';

part 'router/router_dsl.dart';
part 'router/router_facade.dart';
part 'router/router_rules.dart';
part 'router/router_template.dart';

/// The router role; see [RouterRole].
const routerRole = RouterRole._();

/// The role of the router: the pages of the app, how to reach them, and the
/// main navigation when a layout is present.
///
/// Features describe their pages as [RoutesData]; each module's routes live
/// under its namespace, `/<module id>`. From these routes the role's
/// template generates, whichever provider is selected:
/// - `lib/core/router/app_router.dart`: the `AppRouter` interface, which a
///   provider implements, and the instance `appRouter`, created by the
///   provider's `createAppRouter()` (see [createAppRouter]);
/// - `lib/core/router/navigation.dart`: the typed navigation facade.
///   `context.nav.home.details(id: 5)` returns a `NavLink` whose `go()` makes
///   the stack the route's chain of parents (see [FacadeRoute.chain]),
///   `push<T>()` shows the route on top and completes with its result, and
///   `replace()` replaces the top of the stack. Every route has a location
///   class, such as `HomeDetailsLocation`, which providers match on.
///
/// A provider renders the routes from [facadeOf], so it agrees with the
/// facade on every path and name. It:
/// - names each route by its [FacadeRoute.fullName], which navigator
///   observers such as analytics report as the screen name;
/// - builds the start route of [startIn] at `/`, or the fallback screen of
///   the app entry if there is none;
/// - puts the destinations of the main navigation into the `AppShell` of
///   the layout role when a layout is present, with their children in the
///   destination's branch;
/// - calls every factory of [observers] for each navigator it creates;
/// - imports screens with a prefix of its own and does not name its router
///   class `AppRouter`;
/// - creates `config` once.
///
/// The scaffold of the app switches to `MaterialApp.router` when the role is
/// present and passes it `appRouter.config`.
final class RouterRole extends Role<RoutesData> {
  const RouterRole._();

  /// The path of the file with `AppRouter` and `appRouter`.
  static const appRouterFile = 'lib/core/router/app_router.dart';

  /// The path of the file with the navigation facade.
  static const navigationFile = 'lib/core/router/navigation.dart';

  /// The path of the provider's file with [createAppRouter].
  static const appRouterFactoryFile = 'lib/core/router/app_router_factory.dart';

  /// `AppRouter createAppRouter()`, which creates the provider's
  /// implementation of `AppRouter` on the first use of `appRouter`.
  static const createAppRouter = RequiredFunction(
    'createAppRouter',
    path: appRouterFactoryFile,
    returnType: 'AppRouter',
  );

  /// Factories of navigator observers, such as
  /// `() => FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)`.
  ///
  /// A provider calls each factory once for every navigator it creates,
  /// because an observer can watch only one navigator. Switching between
  /// the branches of the main navigation is not a navigation event, so no
  /// observer sees it.
  static const observers = SocketRef<FactoryListSocket>.role(
    routerRole,
    'observers',
    FactoryListSocket(),
  );

  /// Annotations of the class of a screen, such as auto_route's
  /// `@RoutePage()`.
  ///
  /// The template of the screen's feature puts the member's tag on its own
  /// line right before the class, with only other annotations and comments
  /// between them, as in
  /// `{{{smf_router__screen_annotations__home__home_screen}}}`. The module
  /// rule `router.screen_sockets` checks it for every screen of every
  /// route.
  static const screenAnnotations = SocketFamily<ScreenKey, CodeSocket>.role(
    routerRole,
    'screen_annotations',
    CodeSocket(),
    keyOf: _screenSegments,
    segments: 2,
  );

  /// Annotations of a parameter of the constructor of a screen, such as
  /// auto_route's `@PathParam('id')`.
  ///
  /// The template of the screen's feature puts the member's tag in the
  /// parameters of the screen's unnamed constructor, right before the
  /// parameter, as in
  /// `{{{smf_router__param_annotations__home__details_screen__id}}} required
  /// this.id,`. A tag must not follow a `{`, which mustache would read as
  /// part of it: put the parameters on lines of their own.
  static const paramAnnotations = SocketFamily<ParamKey, CodeSocket>.role(
    routerRole,
    'param_annotations',
    CodeSocket(),
    keyOf: _paramSegments,
    segments: 3,
  );

  /// `--start`, the full path of the route the app starts on, such as
  /// `/home`.
  static const startOption = RoleOption(
    name: 'start',
    valueHelp: 'path',
    help: 'The full path of the screen the app starts on, such as /home.',
  );

  @override
  String get id => 'router';

  @override
  String get description => 'Router';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get uses => {layoutRole};

  @override
  List<SocketRef> get sockets => const [observers];

  @override
  List<SocketFamily<Object?, SocketKind>> get socketFamilies =>
      const [screenAnnotations, paramAnnotations];

  @override
  RoleInterface get interface => const RoleInterface(
        files: [appRouterFile, navigationFile],
        symbols: [createAppRouter],
      );

  @override
  List<RoleOption> get options => const [startOption];

  @override
  RoleTemplate<RoutesData> get template => const _RouterTemplate();

  @override
  List<ModuleRule<RoutesData>> get moduleRules => const [
        ModuleRule(
          id: 'router.routes',
          description: 'The routes of a module have valid paths, names, '
              'screens, parameters and destinations, and a router can reach '
              'each of them.',
          check: _checkRoutes,
        ),
        ModuleRule(
          id: 'router.screen_sockets',
          description: 'The template of every screen has the tags of its '
              'annotation sockets, before the class and before each '
              'parameter of the route.',
          check: _checkScreenSockets,
        ),
      ];

  @override
  List<StructuralRule<RoutesData>> get structuralRules => const [
        StructuralRule(
          id: 'router.nav_access',
          description: 'Code of a module navigates only to its own routes '
              'and to those of the modules it depends on, through the facade '
              'or through their location classes.',
          check: _checkNavAccess,
        ),
        StructuralRule(
          id: 'router.screen_constructors',
          description: 'The unnamed constructor of every screen is const '
              'and takes each parameter of its route as a named parameter of '
              'the same name, and nothing else that is required.',
          check: _checkScreenConstructors,
        ),
      ];

  /// The routes of the app in [input], the input of a hook of this role or
  /// of a role that requires or uses it, such as the layout.
  RouterFacade facadeOf(RoleHookInput<Object> input) =>
      RouterFacade.of(dataIn(input));

  /// The route the app starts on, as the template chose it, or `null` if
  /// no route can start the app or [input] comes before the choice.
  FacadeRoute? startIn(RoleHookInput<RoutesData> input) {
    final choice = input.choice;
    if (choice is! RouterChoice) return null;
    final path = choice.startPath;
    return path == null ? null : facadeOf(input).routeAt(path);
  }
}

List<String> _screenSegments(ScreenKey key) =>
    [key.feature.value, SmfNames.snakeCaseOf(key.screen)];

List<String> _paramSegments(ParamKey key) => [
      key.feature.value,
      SmfNames.snakeCaseOf(key.screen),
      SmfNames.snakeCaseOf(key.param),
    ];
