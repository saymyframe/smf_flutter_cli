import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/redirects_generator.dart';
import 'package:smf_go_router/src/route_generator/route_generation_context.dart';
import 'package:smf_go_router/src/route_generator/route_generation_strategy.dart';

/// Renders a [NestedRoute] as a `ShellRoute` built with the widget of its
/// shell, with its children rendered through the context.
///
/// The guards of the nested route go into the `ShellRoute` redirect, which
/// guards every route in the shell. `GoRouterDslGenerator` therefore moves
/// them onto the nested route's own children before rendering, so a module's
/// guards never apply to the tabs other modules add to the same shell.
///
/// Throws an [ArgumentError] when the linked shell is not declared in the
/// context.
class NestedRouteStrategy implements RouteGenerationStrategy<NestedRoute> {
  @override
  String generate(NestedRoute route, RouteGenerationContext context) {
    final childrenCode =
        route.children.map((child) => context.generateRoute(child)).join('\n');
    final redirectsCode = RedirectsGenerator.generateCombinedRedirectCode(
      route.guards,
    );

    final shellId = route.shellLink.id;
    final shell = context.resolveShell(shellId);
    final shellClass = shell!.screen.className;

    return '''
      ShellRoute(
        builder: (_, __, child) => $shellClass(child: child),
        routes: [
          $childrenCode
        ],
        redirect: $redirectsCode,
      ),
      ''';
  }

  @override
  List<String> imports(NestedRoute route, RouteGenerationContext context) {
    return [
      ...route.imports.map((i) => i.resolve()),
      ...route.children
          .map((child) => context.generateImports(child))
          .expand((e) => e),
    ];
  }
}
