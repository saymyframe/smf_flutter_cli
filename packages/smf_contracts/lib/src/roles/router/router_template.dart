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

  /// Checks what the module rules `router.routes` and `router.guards`
  /// cannot see from one module: data of role templates, the getters of
  /// `context.nav`, the location classes of all modules, and the guards of
  /// two modules that stand for one condition.
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

    // A route that asks for a condition shows the target of one guard, and
    // the module rule sees the guards of one module.
    for (final guard in facade.guards) {
      final condition = guard.guard.condition;
      if (condition == null) continue;
      final first = facade.guardFor(condition)!;
      if (first.feature.module == guard.feature.module) continue;
      issues.add(
        SmfIssue(
          'The $guard and the $first both stand for the condition '
          '$condition; an app has one guard for a condition.',
          hint: 'Leave one of the modules ${first.feature.module} and '
              '${guard.feature.module} out of the app.',
          origin: ModuleOrigin(guard.feature.module),
        ),
      );
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
  /// outside the flow of every guard: once a flow is over, the app shows
  /// the screen that it starts on in place of the routes of the flow. Nor
  /// does the route ask for a condition, its own or that of a route above
  /// it: every user sees the screen that the app starts on.
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
    if (route.conditions.isNotEmpty) {
      throw SmfUsageException(
        'The app cannot start on $start, because the route asks for '
        '${_named(route.conditions)}: every user sees the screen that the '
        'app starts on.',
      );
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
/// agents of an app with guards: where they are and in which order the
/// router asks them, what tells a gate from a guard that keeps the user
/// only from some routes, how the code of the app adds either and changes
/// what it allows, that the router navigates when it does, where the user
/// comes to once a guard allows again, and that no code navigates into the
/// flow of a gate, whose routes show only while the guard does not allow
/// (see [RouteGuard]), whichever module provides the role.
///
/// The note leaves out what the comments of the generated code say, such as
/// what `redirectOf()` and `guardChanges` are for.
const String _guardsAgentNote = '''
- `${RouterRole.routeGuards}` in `${RouterRole.appRouterFile}` lists the guards of the routes, each a `RouteGuard`, in the order the router asks them. A guard without `routes` is a gate over the whole app. The gates come first, and the first one whose `allows` is `false` decides: the router asks no guard after it. A guard with `routes` keeps the user only from the routes that it names there, each as `<feature>.<route>`, and comes after the gates.
- To keep the user from the rest of the app, add a gate to that list, never a redirect to the files of the router. Put it at the place among the gates where its screen comes on a first launch: a guard of the first launch goes before one that asks who the user is. Make its `redirectTo` a top-level route outside the main navigation. To keep the user from some routes only, add their names to the `routes` of the guard that stands for what they need, or add such a guard after the gates. Its `routes` are outside the main navigation and outside every `flow`, and the screen that the app starts on is none of them.
- A feature changes the value of `allows` of its guard, and the router navigates when it does. While the value is `false`, the router shows the `redirectTo` in place of each location that the guard keeps the user from. The `redirectTo` takes the whole stack, for a guard with `routes` too, so the user cannot go back from it to the screen that they were on. Once the value is `true`, the router shows the location that was asked for in the meantime, such as a link, or else brings the user back to where they were. A guard with `resumes: false` does not bring the user back. When its `allows` turns `false`, the router forgets where the user was and what was asked for before, even while the `redirectTo` of another guard is shown. Once the guards allow, the user comes to a location that was asked for since then, or else to the screen that the app starts on. So after a sign-out the next user does not come to the screen of the last one.
- The `flow` of a guard is its `redirectTo` and the routes below it. These routes show only while a guard with that `flow` does not allow. At any other time the router shows the screen that the app starts on in their place, or the `redirectTo` of another guard whose `allows` is `false`. So no code navigates into the `flow` of a gate.
''';
