import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/router_role_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contracts/src/roles/brick_templates.dart';
import 'package:smf_contracts/src/roles/symbol_uses.dart';

part 'router/router_dsl.dart';
part 'router/router_facade.dart';
part 'router/router_guards.dart';
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
/// - names each route by its [FacadeRoute.fullName], which the listeners of
///   [screenListeners] get as the name of the screen and navigator
///   observers as the name of its page;
/// - builds the start route of [startIn] at `/`, or the fallback screen of
///   the app entry if there is none;
/// - when a layout is present and the app has destinations, puts them into
///   the `AppShell` of the layout role, in the order of
///   [RouterFacade.destinations], each with the routes below it in its
///   branch, which keeps its stack while another is selected; it matches
///   them before the other top-level routes, which stay outside the main
///   navigation, and the app starts on the branch of its start route;
/// - refuses to push a location in the main navigation from a page shown
///   over the main navigation, or to replace such a page with one, with a
///   `StateError` that leaves the stack as it is;
/// - closes the route on top when the user presses the back button of the
///   system, with `NavigatorState.maybePop` of the navigators that the user
///   sees, the innermost first: a dialog before the page below it, and a
///   page of the selected branch of the main navigation before the main
///   navigation, unless a route of the root navigator, such as a dialog,
///   covers the main navigation; with no route to close, it leaves the
///   button to the system, which closes the app;
/// - calls every factory of [observers] for each navigator it creates;
/// - calls the listeners of [screenListeners] each time the screen the user
///   sees changes, each on its own, so that a listener that throws keeps no
///   other from hearing the screen;
/// - imports screens with a prefix of its own and does not name its router
///   class `AppRouter`;
/// - creates `config` once.
///
/// A module may keep the user from the routes of the app until a condition
/// holds, with the guards of its [RoutesData.guards] (see [RouteGuard]). In
/// an app whose modules declare guards, the role's template also generates
/// [routeGuards], [redirectOf] and [guardChanges] in `app_router.dart`, and
/// the provider asks the guards about every location it shows, as
/// [redirectOf] says, and again when one of them changes, as [guardChanges]
/// says. An app without guards gets none of this.
///
/// When the role is present, the provider of the [AppEntryRole] builds the
/// root `MaterialApp` of the app as a `MaterialApp.router` and passes it
/// `appRouter.config`.
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

  /// The name of the list of the guards of an app with guards, which the
  /// role's template generates in [appRouterFile], as
  /// `final List<RouteGuard> routeGuards`: the guards of
  /// [RouterFacade.guards], in the order the app asks them.
  ///
  /// Each is a `RouteGuard` of the app, a class of the same file:
  /// - `name`, the full name of the guard (see [FacadeGuard.fullName]);
  /// - `allows`, the `ValueListenable<bool>` that the function of the guard
  ///   returns, which the list calls once, when it is first used;
  /// - `redirectTo`, the location of the target of the guard;
  /// - `flow`, the full names of the routes of its flow (see
  ///   [FacadeGuard.flow]).
  static const routeGuards = 'routeGuards';

  /// The name of the function that says what the guards show in place of a
  /// route, which the role's template generates in [appRouterFile] in an
  /// app with guards, as `AppLocation? redirectOf(String? routeName)`.
  ///
  /// It takes the full name of the route of a location (see
  /// [FacadeRoute.fullName]), or `null` for a location that is no route of
  /// a module, such as `/` or one that no route matches. It returns the
  /// location to show instead, or `null` to show the location itself: the
  /// target of the first guard of [routeGuards] that does not allow, unless
  /// the route is in the flow of that guard. No guard after it is asked,
  /// so the answer for the routes of its flow is always to show them.
  ///
  /// In an app with guards, a provider asks it about every location before
  /// it shows the location: the location the app starts on, each location
  /// that `go()`, `push()` or `replace()` of the navigation is asked to
  /// show, and each location that the platform gives it, if it takes any.
  /// When the answer is a location, the provider:
  /// - shows that location in place of the other, as `go()` to it does, so
  ///   that it takes the whole stack. Such a `push()` completes with `null`
  ///   at once;
  /// - never builds the screen of the other location, and the listeners of
  ///   [screenListeners] never hear of it;
  /// - remembers the other location, to show it once the guards allow it
  ///   (see [guardChanges]).
  static const redirectOf = 'redirectOf';

  /// The name of the listenable that notifies its listeners when a guard
  /// starts or stops allowing, which the role's template generates in
  /// [appRouterFile] in an app with guards, as
  /// `final Listenable guardChanges`.
  ///
  /// In an app with guards, a provider listens to it, and asks [redirectOf]
  /// again each time it notifies:
  /// - about the pages of its stack, the one on top first. When the answer
  ///   for a page is a location, the provider remembers the location of
  ///   that page and shows the answer, as `go()` to it does, so that no
  ///   page that a guard keeps the user from stays in the stack;
  /// - otherwise about the location it remembers. Once the answer is to
  ///   show it, the provider shows it, as `go()` to it does.
  ///
  /// The provider remembers one location: the first that the guards kept
  /// the user from, whether it was asked to show the location or the
  /// location was that of a page of its stack, and no other until it has
  /// shown that one. It forgets the location when it shows it, and at no
  /// other time: while it remembers one, a guard does not allow, and the
  /// user can go nowhere but to the flow of that guard.
  ///
  /// A notification that changes none of these answers leaves everything
  /// as it is: the stack stays, the listeners of [screenListeners] hear
  /// nothing, and each `push()` still completes with the value of its page.
  /// Whether the `push()` of a page that a guard takes out of the stack
  /// completes is up to the provider, as it is when `go()` replaces the
  /// stack.
  static const guardChanges = 'guardChanges';

  /// Factories of navigator observers, such as `() => MyNavigatorObserver()`.
  ///
  /// A provider calls each factory once for every navigator it creates,
  /// such as the navigator of each branch of the main navigation, because
  /// an observer can watch only one navigator; each observer sees the pages
  /// of its own navigator. Switching between the branches of the main
  /// navigation is not a navigation event, so no observer sees it, though a
  /// branch shows its first page when it is first selected. When a page
  /// shown over the main navigation closes, the observers of the root
  /// navigator see the main navigation come back, not the page of its
  /// selected branch. To follow the screen the user sees, use
  /// [screenListeners].
  static const observers = SocketRef<FactoryListSocket>.role(
    routerRole,
    'observers',
    FactoryListSocket(),
  );

  /// Listeners of the screen the user sees, such as
  /// `(route, location) => debugPrint('$location: $route')`: functions of
  /// the type `void Function(String? route, String location)`.
  ///
  /// The screen the user sees is the page of the router on top of the app;
  /// a page shown past the router, such as with `Navigator.push`, and a
  /// dialog are not pages of the router. A provider calls every listener
  /// once for each change of it, a switch to another branch of the main
  /// navigation, such as another tab, included:
  /// - when the app shows its first screen;
  /// - when another page comes on top, such as a page that a navigation
  ///   shows, a page that shows again as the pages above it close, or the
  ///   page of the branch of the main navigation that the user selects;
  /// - when the page on top shows another location, such as the same route
  ///   with other values of its parameters.
  ///
  /// It does not call them for the pages that a navigation puts below the
  /// one on top, such as the parents of a route that `go()` shows, and
  /// never twice in a row for the same page at the same location, such as
  /// for a navigation that leaves the page on top as it is. So the
  /// listeners hear of the back button of the system, which closes the
  /// route on top of the innermost navigator, only when it closes a page of
  /// the router: when it closes a dialog, the page below it stays the
  /// screen the user sees.
  ///
  /// A listener gets the full name of the route of the screen among the
  /// routes of the modules, such as `home.details` (see
  /// [FacadeRoute.fullName]), and the location of the screen: its path,
  /// with the query and the fragment it has, such as `/home/details/5`. For
  /// a screen that is not a route of a module, the route is `null`, and the
  /// location is still that of the screen: `/` for the fallback screen of
  /// the app entry, and for the error screen of the router, the location it
  /// could not show.
  ///
  /// A provider may call the listeners while the app builds, such as for
  /// its first screen, so a listener only takes note of the screen: it does
  /// not navigate or rebuild widgets, and it returns without throwing.
  ///
  /// A provider calls each listener on its own, as the modules of the
  /// listeners know nothing of each other: what one throws anyway keeps no
  /// other listener from hearing the screen, and reaches neither the router
  /// nor the handlers of the errors of the app. In debug mode the provider
  /// prints it, so that a listener that fails shows in the console.
  static const screenListeners = SocketRef<FactoryListSocket>.role(
    routerRole,
    'screen_listeners',
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
  List<SocketRef> get sockets => const [observers, screenListeners];

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
          id: 'router.guards',
          description: 'The guards of a module have valid names and '
              'functions of the app, and each shows a top-level route of '
              'the module that needs no values, is outside the main '
              'navigation, and has no start candidate in its flow.',
          check: _checkGuards,
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
        StructuralRule(
          id: 'router.guard_functions',
          description: 'The function of every guard is a top-level function '
              'in its file that takes no arguments and returns a '
              'ValueListenable<bool>.',
          check: _checkGuardFunctions,
        ),
        StructuralRule(
          id: 'router.guards_asked',
          description: 'In an app with guards, the files of the provider of '
              'the role call redirectOf() and read guardChanges.',
          check: _checkGuardsAsked,
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
