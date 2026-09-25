part of '../router.dart';

/// The template of the [RouterRole]: the `AppRouter` interface, the
/// `appRouter` instance and the navigation facade.
final class _RouterTemplate extends RoleTemplate<RoutesData> {
  const _RouterTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) =>
      [BrickContribution(routerRoleBundle)];

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
    if (issues.isNotEmpty) return issues;

    final facade = routerRole.facadeOf(input);
    for (final feature in facade.features) {
      final accessor = feature.accessor;
      if (!SmfNames.isDartIdentifier(accessor) ||
          _objectMembers.contains(accessor)) {
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

    final byPath = <String, FacadeRoute>{};
    final byClass = <String, FacadeRoute>{};
    for (final route in facade.routes) {
      final origin = ModuleOrigin(route.feature.module);
      if (byPath.putIfAbsent(route.fullPath, () => route) case final other
          when other != route) {
        issues.add(
          SmfIssue(
            'The $route and the $other have the same path '
            '${route.fullPath}.',
            origin: origin,
          ),
        );
      }
      if (byClass.putIfAbsent(route.locationClass, () => route) case final other
          when other != route) {
        issues.add(
          SmfIssue(
            'The $route and the $other both need the location class '
            '${route.locationClass}.',
            hint: 'Rename one of the routes.',
            origin: origin,
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
        throw SmfUsageException(
          'The app has no route $start to start on. Routes: '
          '${facade.routes.map((route) => route.fullPath).join(', ')}.',
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
    if (candidates.isEmpty) return const RouterChoice();
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
