part of '../router.dart';

/// The template of the [RouterRole]: the `AppRouter` interface, the
/// `appRouter` instance and the navigation facade.
final class _RouterTemplate extends RoleTemplate<RoutesData> {
  const _RouterTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(routerRoleBundle),
        AppEntryRole.agentSections.entry(
          routerRole.description,
          AgentNote.ofRole(_agentNote),
        ),
      ];

  /// Checks what the module rule `router.routes` cannot see from one module:
  /// data of role templates, the getters of `context.nav` and the location
  /// classes of all modules.
  @override
  List<SmfIssue> validate(RoleHookInput<RoutesData> input) {
    final issues = <SmfIssue>[
      for (final data in input.data)
        if (data.origin is! ModuleOrigin)
          SmfIssue(
            'Only modules can contribute routes, not ${data.origin}, because '
            'routes live under the namespace of their module.',
            origin: data.origin,
          ),
    ];

    final facade = routerRole.facadeOf(input);
    for (final feature in facade.features) {
      final accessor = feature.accessor;
      if (!SmfNames.isDartIdentifier(accessor) ||
          _reservedMemberNames.contains(accessor)) {
        issues.add(
          SmfIssue(
            'The routes of the module ${feature.module} would be '
            'context.nav.$accessor, which is not a name a getter can have.',
            hint: 'Rename the module.',
            origin: ModuleOrigin(feature.module),
          ),
        );
      }
    }

    // Location classes join the module id and the route name, so routes of
    // different modules can need the same class.
    final byClass = <String, FacadeRoute>{};
    for (final route in facade.routes) {
      if (byClass.putIfAbsent(route.locationClass, () => route) case final other
          when other != route) {
        issues.add(
          SmfIssue(
            'The $route and the $other both need the location class '
            '${route.locationClass}.',
            hint: 'Rename one of the routes.',
            origin: ModuleOrigin(route.feature.module),
          ),
        );
      }
    }
    return issues;
  }

  @override
  Future<Object?> choose(RoleChoiceContext<RoutesData> context) async {
    final facade = RouterFacade.of(context.data);
    final start = context.option(RouterRole.startOption.name);
    if (start != null) return _startOn(facade, start);

    final candidates = [
      for (final route in facade.routes)
        if (route.route.startCandidate) route,
    ];
    if (candidates.isEmpty) {
      if (facade.routes.isNotEmpty) {
        context.environment.logger.warn(
          'No route is marked as a start candidate, so the app starts on '
          'its fallback screen. Choose a start route with '
          '--${RouterRole.startOption.name}.',
        );
      }
      return const RouterChoice();
    }
    if (candidates.length == 1) {
      return RouterChoice(startPath: candidates.single.fullPath);
    }
    if (!context.environment.interactive) {
      throw SmfUsageException(
        'Several screens can start the app: '
        '${candidates.map((route) => route.fullPath).join(', ')}. Choose '
        'one with --${RouterRole.startOption.name}.',
      );
    }
    final picked = await context.environment.prompter.select(
      'Which screen does the app start on?',
      candidates,
      display: (route) => '${route.fullPath} (${route.feature.module})',
    );
    return RouterChoice(startPath: picked.fullPath);
  }

  /// The choice of the route at [start], the path the user asked the app to
  /// start on, which must be a route without required parameters, and
  /// outside the flow of every guard: once a guard allows, the app shows the
  /// location that the guard kept the user from, and an app that starts in
  /// the flow has none.
  RouterChoice _startOn(RouterFacade facade, String start) {
    final route = facade.routeAt(start);
    if (route == null) {
      final routes = [for (final route in facade.routes) route.fullPath];
      throw SmfUsageException(
        routes.isEmpty
            ? 'The app has no routes, so it cannot start on $start.'
            : 'The app has no route $start to start on. Routes: '
                '${routes.join(', ')}.',
      );
    }
    if (route.hasRequiredParams) {
      throw SmfUsageException(
        'The app cannot start on $start, because the route needs '
        '${route.params.where((p) => p.isRequired).join(', ')}.',
      );
    }
    for (final guard in facade.guards) {
      if (guard.flow.contains(route)) {
        throw SmfUsageException(
          'The app cannot start on $start, because the route is in the flow '
          'of the $guard: the app shows it until the guard allows, and then '
          'the screen that it starts on.',
        );
      }
    }
    return RouterChoice(startPath: route.fullPath);
  }

  /// `--start` with the start route of [choice], if it has one.
  @override
  Map<String, String> optionsOf(Object? choice) => switch (choice) {
        RouterChoice(:final startPath?) => {
            RouterRole.startOption.name: startPath,
          },
        _ => const {},
      };

  /// The navigation facade of the app, and the code of its guards with the
  /// note of the role about them in the guide for coding agents, which an
  /// app without guards has none of.
  @override
  RoleOutput render(RoleHookInput<RoutesData> input) {
    final facade = routerRole.facadeOf(input);
    return RoleOutput(
      vars: {'facade': facade.toDart(), 'guards': _guardsCode(facade)},
      fragments: [
        if (facade.guards.isNotEmpty)
          AppEntryRole.agentSections.entry(
            routerRole.description,
            AgentNote.ofRole(_guardsAgentNote),
          ),
      ],
    );
  }
}

/// The note of the router role in the guide for coding agents: how the code
/// of an app navigates and where a route is, whichever module provides the
/// role.
const String _agentNote = '''
- Navigate with `context.nav.<feature>.<route>(...)`, never with the package of the router. It returns a `NavLink`, whose `go()`, `push<T>()` and `replace()` show the location. In `context.nav` both names are in lowerCamelCase; elsewhere `<feature>` is the id of the feature.
- A route is in three places, which agree on its name, `<feature>.<route>`, and on its path, which starts with `/<feature>`:
  1. its screen, a widget in `lib/features/<feature>/` whose `const` constructor takes each value of the route as a named parameter;
  2. `${RouterRole.navigationFile}`: its location class, which extends the sealed `AppLocation` with its `routeName`, its `path` and, below another route, its `parent`, and a method that returns its `NavLink` in the class of the routes of its feature. `AppNav` returns that class from a getter with the name of the feature, and both classes pass on the `BuildContext` that `NavLink` takes;
  3. the route itself, where the provider of the router declares its routes.
- A value of a route is a `String`, an `int`, a `double` or a `bool`, from a `:<name>` segment of its path or from the query.
- `appRouter` of `${RouterRole.appRouterFile}` is the one router of the app: create no other.
''';

/// The note of the router role about the guards, in the guide for coding
/// agents of an app with guards: where they are, how the code of the app
/// adds one and changes what it allows, that the router navigates when it
/// does, and how the code keeps the user from coming back to where they
/// were, as after a sign-out (see [RouteGuard]), whichever module provides
/// the role.
///
/// The note leaves out what the comments of the generated code say, such as
/// what `redirectOf()` and `guardChanges` are for.
const String _guardsAgentNote = '''
- `${RouterRole.routeGuards}` in `${RouterRole.appRouterFile}` lists the guards of the routes, each a `RouteGuard`.
- To keep the user from the rest of the app, add a `RouteGuard` to that list, never a redirect to the files of the router. Make its `redirectTo` a top-level route outside the main navigation.
- A feature changes the value of `allows` of its guard, and the router navigates when it does. The router brings the user back to where they were unless the code calls `go()` to the `redirectTo` before the value turns `false`.
''';
