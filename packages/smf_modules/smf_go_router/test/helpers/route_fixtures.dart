import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/route_generation_context.dart';
import 'package:smf_go_router/src/route_generator/route_generation_strategy_registry.dart';

/// A context wired to the strategy registry, the same way the DSL generator
/// builds it, so nested routes generate their children for real.
RouteGenerationContext registryContext({
  List<ShellDeclaration> shellDeclarations = const [],
}) {
  // The callbacks refer to the context they are part of.
  late final RouteGenerationContext context;
  return context = RouteGenerationContext(
    shellDeclarations: shellDeclarations,
    generateRoute: (route) =>
        RouteGenerationStrategyRegistry.generate(route, context),
    generateImports: (route) =>
        RouteGenerationStrategyRegistry.imports(route, context),
  );
}

ShellDeclaration get mainTabsShell => ShellRegistry.resolve('main-tabs')!;

RouteGuard goRouterGuard(String code, {List<Import> imports = const []}) {
  return RouteGuard(
    bindings: {
      RoutingMode.goRouter: GoRouteRedirect(code: code, imports: imports),
    },
  );
}

RouteGuard autoRouterOnlyGuard() {
  return RouteGuard(
    bindings: {
      RoutingMode.autoRouter: AutoRouteGuard(
        className: 'AuthGuard',
        code: 'AuthGuard()',
      ),
    },
  );
}

/// Counts non-overlapping occurrences of [pattern] in [source].
int countOf(String source, String pattern) => pattern.allMatches(source).length;
