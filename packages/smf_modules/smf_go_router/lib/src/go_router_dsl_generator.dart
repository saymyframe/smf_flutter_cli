import 'dart:io';

import 'package:mustachex/mustachex.dart';
import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/app_routes_generator.dart';
import 'package:smf_go_router/src/route_generator/redirects_generator.dart';
import 'package:smf_go_router/src/route_generator/route_generation_context.dart';
import 'package:smf_go_router/src/route_generator/route_generation_strategy_registry.dart';
import 'package:smf_go_router/src/route_generator/tabs_shell_generator.dart';

/// Shells whose widget templates ship with the go_router brick.
final _bundledShells = [RouteShellLink.toMainTabsShell()];

/// Renders the routes that modules declare with the routing DSL as GoRouter
/// code in the brick templates.
///
/// Fills `app_router.dart` with the `GoRouter` and its imports,
/// `app_routes.dart` with the `AppRoutes` constants, and the widget template
/// of every shell that routes link to with its tabs. Templates of shells no
/// module links to are deleted.
///
/// Each guard applies where it is declared: the core guards of a route group
/// to the whole router, a route's guards to that route, and a nested route's
/// guards to its own children only (see [mergeNestedRoutesByShellLink]).
mixin GoRouterDslGenerator implements DslAwareCodeGenerator {
  /// Lets the route strategies render and import child routes; set at the
  /// start of each [generateFromDsl] run.
  late RouteGenerationContext generationContext;

  @override
  Future<List<GeneratedFile>> generateFromDsl(DslContext context) async {
    final routes = mergeNestedRoutesByShellLink(
      context.routeGroups.expand((g) => g.routes).toList(),
    );

    generationContext = RouteGenerationContext(
      shellDeclarations: context.shellDeclarations,
      generateRoute: (route) =>
          RouteGenerationStrategyRegistry.generate(route, generationContext),
      generateImports: (route) =>
          RouteGenerationStrategyRegistry.imports(route, generationContext),
    );

    final coreGuards = context.routeGroups.expand((g) => g.coreGuards).toList();

    final imports = <String>{};
    for (final route in routes) {
      imports.addAll(
        RouteGenerationStrategyRegistry.imports(route, generationContext),
      );
    }
    imports.addAll(_guardImports([...coreGuards, ..._routeGuards(routes)]));

    final buffer = StringBuffer()
      ..writeln('GoRouter(')
      ..writeln("initialLocation: '${context.initialRoute}',")
      ..writeln('  routes: [');
    for (final route in routes) {
      final code = RouteGenerationStrategyRegistry.generate(
        route,
        generationContext,
      );

      buffer.writeln(code);
    }

    buffer.writeln('  ],');

    final coreRedirects =
        RedirectsGenerator.generateCombinedRedirectCode(coreGuards);

    buffer
      ..writeln('redirect: $coreRedirects')
      ..writeln(');');

    final appRoutesGenerator = AppRoutesGenerator();
    // Every GoRoute the router renders, top-level and nested alike.
    final appRoutesBuff = appRoutesGenerator.generateAppRoutes([
      for (final route in routes)
        if (route is NestedRoute)
          ...route.children
        else if (route is Route)
          route,
    ]);

    final shellFiles = <GeneratedFile>[];
    final routesByShellLinks = groupRoutesByShellLink(context.routeGroups);
    for (final shell in routesByShellLinks.entries) {
      final code = const TabsShellGenerator().generate(
        declaration: shell.key,
        routes: shell.value,
      );

      final file = File(
        join(context.projectRootPath, 'lib', shell.key.widgetFilePath),
      );

      final processor = MustachexProcessor(
        initialVariables: {MustacheSlots.tabsWidget.slot: code},
      );

      final processed = await processor.process(await file.readAsString());
      shellFiles.add(GeneratedFile(file.path, processed));
      imports.add(
        "import 'package:{{app_name_sc}}/${shell.key.widgetFilePath}';",
      );
    }

    await _removeUnusedShells(context, routesByShellLinks.keys);

    final innerProcessor = MustachexProcessor(
      initialVariables: context.mustacheVariables,
    );

    final processedImports = await innerProcessor.process(imports.join('\n'));

    final processor = MustachexProcessor(
      initialVariables: {
        ...context.mustacheVariables,
        MustacheSlots.imports.slot: processedImports,
        MustacheSlots.router.slot: buffer.toString(),
        MustacheSlots.appRoutes.slot: appRoutesBuff,
      },
    );

    final routerFile = File(
      join(context.projectRootPath, 'lib', 'core', 'router', 'app_router.dart'),
    );
    final router = await processor.process(await routerFile.readAsString());

    final appRoutesFile = File(
      join(context.projectRootPath, 'lib', 'core', 'router', 'app_routes.dart'),
    );
    final appRoutes = await processor.process(
      await appRoutesFile.readAsString(),
    );

    return [
      GeneratedFile(routerFile.path, router),
      GeneratedFile(appRoutesFile.path, appRoutes),
      ...shellFiles,
    ];
  }

  /// The guards declared on [routes] and on the routes nested in them.
  Iterable<RouteGuard> _routeGuards(List<BaseRoute> routes) sync* {
    for (final route in routes) {
      yield* route.guards;
      if (route is NestedRoute) {
        yield* route.children.expand((child) => child.guards);
      }
    }
  }

  /// The imports that the go_router redirects of [guards] need.
  Iterable<String> _guardImports(List<RouteGuard> guards) {
    return guards
        .map((guard) => guard.bindings[RoutingMode.goRouter])
        .whereType<GoRouteRedirect>()
        .expand((redirect) => redirect.imports)
        .map((i) => i.resolve());
  }

  /// The brick ships a template for every shell, but only shells that some
  /// module links routes to get rendered. Leftover templates still contain
  /// raw mustache slots and would break the generated project, so they are
  /// removed.
  Future<void> _removeUnusedShells(
    DslContext context,
    Iterable<ShellDeclaration> usedShells,
  ) async {
    final usedIds = usedShells.map((s) => s.id).toSet();
    for (final link in _bundledShells) {
      if (usedIds.contains(link.id)) continue;

      final declaration = ShellRegistry.resolve(link.id);
      if (declaration == null) continue;

      final file = File(
        join(context.projectRootPath, 'lib', declaration.widgetFilePath),
      );
      if (file.existsSync()) await file.delete();
    }
  }

  /// The children of the nested routes in [groups], grouped by the
  /// [ShellRegistry] declaration of the shell they link to, in declaration
  /// order. These are the tabs each shell widget lists.
  ///
  /// Throws an [ArgumentError] for a link to a shell missing from
  /// [ShellRegistry].
  Map<ShellDeclaration, List<Route>> groupRoutesByShellLink(
    List<RouteGroup> groups,
  ) {
    return groups.expand((g) => g.routes).whereType<NestedRoute>().fold(
      <ShellDeclaration, List<Route>>{},
      (acc, route) {
        final declaration = ShellRegistry.resolve(route.shellLink.id);
        if (declaration == null) {
          throw ArgumentError(
            'Unknown shell link ${route.shellLink.id}. '
            'Declare it in ShellRegistry.',
          );
        }

        acc.update(
          declaration,
          (list) => [...list, ...route.children],
          ifAbsent: () => [...route.children],
        );

        return acc;
      },
    );
  }

  /// Merges the nested routes linked to the same shell into one, so the
  /// router gets a single ShellRoute per shell. Nested routes are matched by
  /// shell id: separate modules create separate links to the same shell.
  /// Plain routes keep their order and come before the merged nested routes.
  ///
  /// The shell is shared, but modules must not affect each other, so the
  /// guards of a nested route are moved onto its own children instead of
  /// guarding the whole shell.
  List<BaseRoute> mergeNestedRoutesByShellLink(List<BaseRoute> routes) {
    final result = <BaseRoute>[];
    final shellMap = <String, List<NestedRoute>>{};

    for (final route in routes) {
      if (route is! NestedRoute) {
        result.add(route);
        continue;
      }

      shellMap.putIfAbsent(route.shellLink.id, () => []).add(route);
    }

    for (final nested in shellMap.values) {
      result.add(
        NestedRoute(
          shellLink: nested.first.shellLink,
          children: [
            for (final route in nested)
              for (final child in route.children)
                _withGuards(child, route.guards),
          ],
          imports: [for (final route in nested) ...route.imports],
        ),
      );
    }

    return result;
  }

  /// [route] guarded by [guards] before its own guards.
  Route _withGuards(Route route, List<RouteGuard> guards) {
    if (guards.isEmpty) return route;

    // Copies every field of Route; keep in sync when Route gets new ones.
    return Route(
      path: route.path,
      screen: route.screen,
      parameters: route.parameters,
      meta: route.meta,
      name: route.name,
      guards: [...guards, ...route.guards],
      imports: route.imports,
    );
  }
}
