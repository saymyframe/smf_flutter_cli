import 'package:smf_contracts/smf_contracts.dart';

typedef RouteCodeGenerator = String Function(BaseRoute route);
typedef RouteImportsGenerator = List<String> Function(BaseRoute route);

class RouteGenerationContext {
  const RouteGenerationContext({
    required this.shellDeclarations,
    required this.generateRoute,
    required this.generateImports,
  });

  /// All registered shell declarations (linked via `shellLink`)
  final List<ShellDeclaration> shellDeclarations;

  /// Used by NestedRouteStrategy to generate children recursively
  final RouteCodeGenerator generateRoute;

  final RouteImportsGenerator generateImports;

  /// Lookup helper for shell
  ShellDeclaration? resolveShell(String shellId) {
    return shellDeclarations.firstWhere(
      (s) => s.id == shellId,
      orElse: () => throw ArgumentError('Unknown shell id: $shellId'),
    );
  }
}
