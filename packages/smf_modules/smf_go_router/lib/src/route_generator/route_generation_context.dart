import 'package:smf_contracts/smf_contracts.dart';

/// Renders the go_router code of a route.
typedef RouteCodeGenerator = String Function(BaseRoute route);

/// Lists the import directives the go_router code of a route needs.
typedef RouteImportsGenerator = List<String> Function(BaseRoute route);

/// What route strategies need beyond the route itself: the declared shells
/// and a way to render other routes, such as the children of a nested route.
class RouteGenerationContext {
  /// Creates a route generation context.
  const RouteGenerationContext({
    required this.shellDeclarations,
    required this.generateRoute,
    required this.generateImports,
  });

  /// All registered shell declarations (linked via `shellLink`)
  final List<ShellDeclaration> shellDeclarations;

  /// Used by NestedRouteStrategy to generate children recursively
  final RouteCodeGenerator generateRoute;

  /// Used by NestedRouteStrategy to collect the imports of its children
  final RouteImportsGenerator generateImports;

  /// Lookup helper for shell
  ///
  /// Throws an [ArgumentError] if no shell with [shellId] is declared.
  ShellDeclaration? resolveShell(String shellId) {
    return shellDeclarations.firstWhere(
      (s) => s.id == shellId,
      orElse: () => throw ArgumentError('Unknown shell id: $shellId'),
    );
  }
}
