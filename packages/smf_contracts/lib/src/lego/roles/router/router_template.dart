part of '../router.dart';

/// The template of the [RouterRole]: the `AppRouter` interface, the
/// `appRouter` instance and the navigation facade.
final class _RouterTemplate extends RoleTemplate<RoutesData> {
  const _RouterTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) =>
      [BrickContribution(routerRoleBundle)];

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
    if (start != null) {
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
      return RouterChoice(startPath: route.fullPath);
    }

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

  @override
  RoleOutput render(RoleHookInput<RoutesData> input) =>
      RoleOutput(vars: {'facade': routerRole.facadeOf(input).toDart()});
}
