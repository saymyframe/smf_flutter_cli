import 'dart:io';

import 'package:mustachex/mustachex.dart';
import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/app_routes_generator.dart';
import 'package:smf_go_router/src/route_generator/redirects_generator.dart';
import 'package:smf_go_router/src/route_generator/route_generation_context.dart';
import 'package:smf_go_router/src/route_generator/route_generation_strategy_registry.dart';
import 'package:smf_go_router/src/route_generator/tabs_shell_generator.dart';

mixin GoRouterDslGenerator implements DslAwareCodeGenerator {
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

    final imports = <String>{};
    for (final route in routes) {
      imports.addAll(
        RouteGenerationStrategyRegistry.imports(route, generationContext),
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('GoRouter(');
    buffer.writeln('initialLocation: \'${context.initialRoute}\',');
    buffer.writeln('  routes: [');
    for (final route in routes) {
      final code = RouteGenerationStrategyRegistry.generate(
        route,
        generationContext,
      );

      buffer.writeln(code);
    }

    buffer.writeln('  ],');

    final coreRedirects = RedirectsGenerator.generateCombinedRedirectCode(
      context.routeGroups.map((rg) => rg.coreGuards).expand((e) => e).toList(),
    );

    buffer.writeln('redirect: $coreRedirects');
    buffer.writeln(');');

    final appRoutesGenerator = AppRoutesGenerator();
    final appRoutesBuff = appRoutesGenerator.generateAppRoutes(
      routes
          .whereType<NestedRoute>()
          .map((n) => n.children)
          .expand((r) => r)
          .toList(),
    );

    final shellFiles = <GeneratedFile>[];
    final routesByShellLinks = groupRoutesByShellLink(context.routeGroups);
    for (final shell in routesByShellLinks.entries) {
      final code = TabsShellGenerator().generate(
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

  Map<ShellDeclaration, List<Route>> groupRoutesByShellLink(
    List<RouteGroup> groups,
  ) {
    return groups.expand((g) => g.routes).whereType<NestedRoute>().fold(
      <ShellDeclaration, List<Route>>{},
      (acc, route) {
        final declaration = ShellRegistry.resolve(route.shellLink.id);
        if (declaration == null) {
          throw ArgumentError(
            'Unknown shell link ${route.shellLink.id}. Declare it in ShellRegistry.',
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

  List<BaseRoute> mergeNestedRoutesByShellLink(List<BaseRoute> routes) {
    final result = <BaseRoute>[];
    final shellMap = <RouteShellLink, List<Route>>{};

    for (final route in routes) {
      if (route is! NestedRoute) {
        result.add(route); // залишаємо RouteDefinition як є
        continue;
      }

      shellMap.putIfAbsent(route.shellLink, () => []).addAll(route.children);
    }

    for (final entry in shellMap.entries) {
      result.add(NestedRoute(shellLink: entry.key, children: entry.value));
    }

    return result;
  }
}
