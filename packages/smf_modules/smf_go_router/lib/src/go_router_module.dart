import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/bundles/go_router_bundle.dart';
import 'package:smf_go_router/src/agents.dart';
import 'package:smf_go_router/src/go_routes.dart';

/// The module that routes the app with go_router, and so provides the
/// router role.
///
/// It adds `go_router` to the dependencies of the app and generates
/// `createAppRouter()` in `lib/core/router/app_router_factory.dart`, which
/// creates the router of the app once, on first use: a `GoRouter` with the
/// routes that the modules of the app declare, each under the namespace of
/// its module, named by its full name, such as `home.details`, and with its
/// screen imported with a prefix of its own. The path `/` redirects to the
/// route the app starts on, or shows the fallback screen of the app entry
/// when no route can start the app, so an app without features shows that
/// screen through the router. The app opens on the start route.
///
/// When a module provides the layout role and the app has destinations,
/// they form the main navigation: a `StatefulShellRoute.indexedStack` with
/// a branch for each destination, in the order of the features, which
/// shows the `AppShell` of the layout. The shell gets `appDestinations`,
/// the list that the layout role generates with the label and the icon of
/// each destination, in the order of the branches, so the module renders
/// neither. Each branch keeps its stack, with the routes below its
/// destination, while another is selected, and the app opens on the branch
/// of its start route. The other top-level routes stay outside the main
/// navigation, which the router matches first.
///
/// go_router keeps the pages of the branches, and the navigators that show
/// them, under keys of the route of the main navigation, for as long as a
/// page of that route is in the widget tree: until the transition to the
/// page that took its place is over. A main navigation that comes back
/// sooner, such as in the same turn, would have the pages of its branches
/// again, and Flutter would find those keys twice in the tree while the
/// page that left is still there
/// (https://github.com/flutter/flutter/issues/148768). So the router keeps
/// its routes in a `RoutingConfig` that go_router follows, and each time
/// the main navigation leaves the pages of the router, it puts a new route
/// for the main navigation there, which `_mainNavigation()` creates: the
/// main navigation comes back with each branch on its destination, at any
/// time. The other routes stay the same objects, and the new configuration
/// has what the one before it had. When its routes change, go_router
/// matches its location again, without the redirects of the routes, which
/// would give a location that a redirect refused the page of its route. So
/// the router puts back the pages that go_router had, and the error screen
/// stays. Once go_router gives the main navigation that comes back a state
/// of its own, the router can leave this out.
///
/// Screens get the values of their parameters from the location, parsed
/// with `tryParse`, a `bool` being `true` or `false` exactly: an optional
/// value that the location does not have, or not of its type, is `null`,
/// and a location without a valid required value shows the error screen of
/// the router.
///
/// The navigation facade goes through the same router whatever the context
/// it navigates from: `go()` goes to the path of a location, which makes
/// the chain of its parents the stack, in the branch of the location in the
/// main navigation, `push()` pushes it, and `replace()` replaces the top of
/// the stack with it, as `pushReplacement` of go_router does. In the main
/// navigation, `push()` shows a location on top of the stack of the
/// selected branch, as go_router does, whichever branch it belongs to.
/// go_router shows the main navigation once, so `push()` and `replace()`
/// of a location in it from a page shown over the main navigation throw a
/// `StateError` that says to use `go()`, and leave the stack as it is;
/// from a page with no main navigation below it, `push()` brings the main
/// navigation back on top with the location.
/// Every navigator, the root one and that of each branch, creates
/// navigator observers of its own from the factories of the router role
/// once.
///
/// The future of `push()` completes with the value that the page returns
/// when it closes, even after go_router shows its pages anew from their
/// encoded form, as on `refresh()`, such as when its `refreshListenable`
/// notifies. go_router gives each pushed page a new completer there, which
/// the page completes instead of that of the push
/// (https://github.com/flutter/flutter/issues/128122), so the router passes
/// on the value of the new completer to that of the push, which it finds by
/// the key and the location of the page. Once go_router keeps the
/// completers of its pages, the router can leave this out.
///
/// The router is a `_GoRouter`, a class of its file that extends `GoRouter`
/// with a dispatcher of the back button of the system of its own,
/// `_BackButton`, since go_router takes none. go_router shows its error
/// screen in place of the whole stack, for a location that no route matches
/// or that the redirect of a route refuses, and has no page of a route
/// then. Asked to close the route on top, its delegate looks for the last
/// of those pages and throws a `StateError`
/// (https://github.com/flutter/flutter/issues/187616). So while go_router
/// has no page, the dispatcher asks the root navigator itself, as the
/// router role says of the button on any screen: a route that is shown
/// over the error screen, such as a dialog, closes, and with no route to
/// close the button is left to the system. A `BackButtonListener` below
/// the router hears of the button first there too, and an error screen
/// that a push showed over a page is a page of go_router, which closes it.
/// A class can extend `GoRouter` only through the constructor that takes
/// the routes as a `RoutingConfig` that go_router follows. So in an app
/// without a main navigation, the constructor of `_GoRouter` takes the
/// routes themselves and puts them into one that never changes. Once the
/// delegate of go_router answers without a page, the router can leave
/// this out.
///
/// In an app whose modules declare guards, the router asks them as the
/// router role says, through the `GuardedNavigation` of the role, which
/// keeps the location that the user comes back to: the router remembers
/// nothing of the gates itself. It knows a location by its URI. `go()`,
/// `push()` and `replace()` ask once, before they hand a location to
/// go_router, with the routes of the pages that the user can get back to.
/// The top-level `redirect` of go_router runs inside each call of
/// go_router, so the router counts the calls that it makes with a location
/// that it asked about, or that the role answered, and the `redirect` asks
/// only about what go_router parses on its own: the location that the app
/// starts on, those of the platform, and that of a branch of the main
/// navigation that the user selects. Such a location takes the place of
/// the stack, so the role is told of no pages for it.
///
/// For a gate, or a flow that is over, the role answers a location, the
/// target of the gate or `/`, and the router goes to it: `push()` then
/// completes with `null`. A `go()` of go_router to `/` leaves the branches
/// of the main navigation that are not selected as they are, so they keep
/// their pages when a flow that is over sends the user to `/`. The target
/// of a gate is outside the main navigation, so going to it takes the main
/// navigation out of the pages of the router, which then gives go_router a
/// new one: no branch keeps a page, also when the gate allows again in the
/// same turn, or before the transition to its target is over.
///
/// For a route that asks for a condition that does not hold, the role
/// answers to open the target of the guard of the condition over the page
/// on top. The router pushes it, and keeps the request waiting, with the
/// routes of the flow that the role gives it: how to make the request
/// again, and, for a `push()`, the completer of the future that it
/// returned. It keeps one request. While a page of the flow is among its
/// pages, the request waits, and it is dropped once none is: the user went
/// back, or another location took the place of the stack. From its
/// `redirect`, which can only send go_router to another location, the
/// router sends it to `/` and pushes the target in a microtask, once the
/// parse is over. go_router tells nobody of pages that it has already, as
/// when the user is on `/`, so the router does not wait for it to do so.
/// The listeners of the screen hear nothing of `/` then. Before go_router
/// has a page, it has no stack to push on and no page to replace: `go()`,
/// `push()` and `replace()` give it the location as `go()` does, the
/// `redirect` asks about it, and such a `push()` completes with `null`.
///
/// The router listens to `guardChanges` itself. When a guard starts or
/// stops allowing, it tells the role of the pages that pushes showed, the
/// one on top first, each of which it can close on its own, and of the
/// location below them, and does what the role answers. Before it showed
/// its first location, it has no page to tell of and does nothing:
/// go_router asks about that location when it parses it. A page that
/// `replace()` showed over other pages counts as one that a push showed, as
/// it is one to go_router. When the role answers to close pages, those of
/// a flow that is over or of routes whose condition stopped holding, the
/// router takes them out of the pages of go_router with one `restore()`,
/// and completes their pushes with `null`, which go_router does not do for
/// a page that leaves that way. `pop()` would close what the navigator
/// shows on top, such as a dialog over the page, and it cannot close a
/// page that a push of the same turn showed, which the navigator has not
/// built yet. Then the router makes the request that waited again, if no
/// page of its flow is left, and tells the listeners of the screen only of
/// the page that the user ends on. The main navigation stays among the
/// pages through all of this, so the router gives go_router no new one.
/// The router does not hand `guardChanges` to go_router as its
/// `refreshListenable`: a refresh asks only about the location below the
/// pushed pages, and gives each of those pages a new completer.
///
/// The router tells the listeners of the screen of the router role about
/// the page on top of the app: the delegate of go_router hears of every
/// change of its stacks, a switch of branches included, and the router
/// calls the listeners when another page comes on top or the page on top
/// shows another location, with the name of the route of the page, `null`
/// for the fallback screen and the error screen, and its location. It calls
/// each listener on its own: what one throws keeps no other listener from
/// hearing the screen, and reaches neither the router nor the handlers of
/// the errors of the app; in debug mode it is printed.
///
/// In the guide for coding agents, the module adds to the section of the
/// router how its file writes a route, and, in an app with a main
/// navigation, where the destinations are among the routes and that the
/// router creates the route of the main navigation anew.
final class GoRouterModule extends SmfModule {
  /// Creates the module.
  const GoRouterModule();

  /// The id of the module.
  static const id = ModuleId('go_router');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Routes and navigation with go_router',
        kind: ModuleKinds.infrastructure,
        providers: [_GoRouterProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(goRouterBundle),
        const PubspecContribution.hosted('go_router', '^17.5.0'),
        AppEntryRole.agentSections.entry(
          routerRole.description,
          AgentNote(agentNote),
        ),
      ];
}

/// Renders the routes of the app into the brick of the module.
final class _GoRouterProvider extends RoleProvider<RoutesData> {
  const _GoRouterProvider();

  @override
  Role<RoutesData> get role => routerRole;

  @override
  RoleOutput render(RoleHookInput<RoutesData> input) {
    final facade = routerRole.facadeOf(input);
    final routes = GoRoutes.of(
      facade,
      start: routerRole.startIn(input),
      mainNavigation: input.has(layoutRole),
    );
    return RoleOutput(
      fragments: [
        if (routes.hasMainNavigation)
          AppEntryRole.agentSections.entry(
            routerRole.description,
            AgentNote(mainNavigationAgentNote),
          )
        else if (input.has(layoutRole))
          AppEntryRole.agentSections.entry(
            routerRole.description,
            AgentNote(firstDestinationAgentNote),
          ),
      ],
      vars: {
        'initial_location': routes.initialLocation,
        'main_navigation': routes.hasMainNavigation,
        'routes': routes.routes,
        'main_navigation_route': routes.mainNavigation,
        'value_checks': routes.valueChecks,
        // Whether the modules of the app declare guards, which the router
        // then asks.
        'guards': facade.guards.isNotEmpty,
      },
    );
  }
}
