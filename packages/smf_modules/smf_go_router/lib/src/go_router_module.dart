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
/// In an app whose modules declare guards, the router asks them as the
/// router role says, through the `GuardedNavigation` of the role, which
/// keeps the location that the user comes back to: the router remembers
/// nothing of the guards itself. It knows a location by its URI. The
/// top-level `redirect` of go_router asks about every location that
/// go_router parses, such as the one the app starts on, those of `go()` and
/// those of the platform, and sends the user to the target of the guard
/// that keeps them from it. `push()` and `replace()` ask before they hand a
/// location to go_router, which would put the target on top of the stack:
/// they go to the target instead, and `push()` completes with `null`. The
/// router listens to `guardChanges` itself. When a guard starts or stops
/// allowing, it tells the role of the pages that pushes showed, the one on
/// top first, and of the location below them, or of no pages before it
/// showed its first location, and goes to the location that the role
/// answers. A page that `replace()` showed over other pages
/// counts as one that a push showed, as it is one to go_router. The router
/// does not hand `guardChanges` to go_router as its `refreshListenable`: a
/// refresh asks only about the location below the pushed pages, and gives
/// each of those pages a new completer.
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
/// navigation, where the destinations are among the routes.
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
        'value_checks': routes.valueChecks,
        // Whether the modules of the app declare guards, which the router
        // then asks.
        'guards': facade.guards.isNotEmpty,
      },
    );
  }
}
